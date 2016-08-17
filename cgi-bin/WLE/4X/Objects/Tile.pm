package WLE::4X::Objects::Tile;

use strict;
use warnings;

use Data::Dumper;

use WLE::Methods::Simple qw( center_text word_wrap rotate_bits_left );

use WLE::4X::Enums::Basic;
use WLE::4X::Enums::Status;

use WLE::4X::Objects::ResourceSpace;

use parent 'WLE::4X::Objects::Element';

#############################################################################
# constructor args
#
# 'server'		- required
#

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $args{'type'} = 'tile';

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    $self->{'ID'} = 0;
    $self->{'STACK'} = 0;
    $self->{'VP'} = 0;

    $self->{'WARPS'} = 0;

    $self->{'ANCIENT_LINK'} = 0;
    $self->{'WORMHOLE'} = 0;
    $self->{'HIVE'} = 0;
    $self->{'DISCOVERY_COUNT'} = 0;
    $self->{'ORBITAL'} = 0;
    $self->{'MONOLITH'} = 0;
    $self->{'STARTING_SHIPS'} = [];
    $self->{'DISCOVERIES'} = [];

    $self->{'SHIPS'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
    $self->{'OWNER_QUEUE'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
    $self->{'VP_DRAW_QUEUE'} = WLE::Objects::Stack->new();
    $self->{'ATTACK_POPULATION_QUEUE'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );

    $self->{'RESOURCE_SLOTS'} = [];

    $self->{'BOARD_LOCATION'} = '';

    $self->{'ATTACKER_ID'} = -1;
    $self->{'DEFENDER_ID'} = -1;

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub tile_id {
    my $self        = shift;

    return $self->{'ID'};
}

#############################################################################

sub which_stack {
    my $self        = shift;

    return $self->{'STACK'};
}

#############################################################################

sub board_location {
    my $self        = shift;

    return $self->{'BOARD_LOCATION'};
}

#############################################################################

sub set_board_location {
    my $self        = shift;
    my $location    = shift;

    $self->{'BOARD_LOCATION'} = $location;

    return;
}

#############################################################################

sub base_vp {
    my $self        = shift;

    return $self->{'VP'};
}

#############################################################################

sub total_vp {
    my $self        = shift;

    return $self->vp() + ( $self->monolith() * 3 );
}

#############################################################################

sub ancient_links {
    my $self        = shift;

    return $self->{'ANCIENT_LINK'};
}

#############################################################################

sub has_wormhole {
    my $self        = shift;

    return $self->{'WORMHOLE'};
}

#############################################################################

sub is_hive {
    my $self        = shift;

    return $self->{'HIVE'};
}

#############################################################################

sub discovery_count {
    my $self        = shift;

    return $self->{'DISCOVERY_COUNT'};
}

#############################################################################

sub discoveries {
    my $self        = shift;

    return @{ $self->{'DISCOVERIES'} };
}

#############################################################################

sub add_discovery {
    my $self        = shift;
    my $value       = shift;

    $self->remove_discovery( $value );

    push( @{ $self->{'DISCOVERIES'} }, $value );

    return;
}

#############################################################################

sub remove_discovery {
    my $self        = shift;
    my $value       = shift;

    my @holder = ();

    foreach my $tag ( $self->discoveries() ) {
        unless ( $tag eq $value ) {
            push( @holder, $tag );
        }
    }

    $self->{'DISCOVERIES'} = \@holder;

    return;
}

#############################################################################

sub orbital_count {
    my $self        = shift;

    return $self->{'ORBITAL'};
}

#############################################################################

sub monolith_count {
    my $self        = shift;

    return $self->{'MONOLITH'};
}

#############################################################################

sub warps {
    my $self        = shift;

    return $self->{'WARPS'};
}

#############################################################################

sub set_warps {
    my $self        = shift;
    my $values      = shift;

    $self->{'WARPS'} = $values;

    return;
}

#############################################################################

sub starting_ships {
    my $self        = shift;

    return @{ $self->{'STARTING_SHIPS'} };
}

#############################################################################

sub ships {
    my $self        = shift;

    return $self->{'SHIPS'};
}

#############################################################################

sub ship_owners {
    my $self        = shift;

    my %ship_owners = ();

    foreach my $ship ( $self->ships()->items() ) {
        $ship_owners{ $ship->owner_id() } = 1;
    }

    return keys( %ship_owners );
}

#############################################################################

sub has_ancient_cruiser { # used for descendant race
    my $self        = shift;

    foreach my $ship_tag ( $self->ships()->items() ) {
        my $ship = $self->server()->ships()->{ $ship_tag };

        if ( $ship->class() eq 'class_ancient_cruiser' ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub has_explorer {
    my $self                = shift;
    my $player_id           = shift;
    my $flag_unpinned_only  = shift; $flag_unpinned_only = 1            unless defined( $flag_unpinned_only );

    my $flag_explorer_available = 0;

    if ( $self->owner_id() == $player_id ) {
        return 1;
    }
    elsif ( $self->unpinned_ship_count( $player_id ) > 0 ) {
        return 1;
    }

    return 0;
}

#############################################################################

sub unpinned_ship_count {
    my $self            = shift;
    my $player_id       = shift;
    my $flag_add_one    = shift; $flag_add_one = 0          unless defined( $flag_add_one );

    my $enemy_count = 0;
    my $friendly_count = 0;

    foreach my $ship_tag ( $self->ships()->items() ) {
        my $ship = $self->server()->ships()->{ $ship_tag };

        if ( defined( $ship ) ) {
            if ( $ship->class() eq 'class_defense' ) {
                return 0;
            }

            if ( $ship->owner_id() == $player_id ) {
                $friendly_count++;
            }
            else {
                $enemy_count++;
            }
        }
        else {
            print STDERR "\nUndefined ship for tag '" . $ship_tag . "' on tile '" . $self->tag() . "'";
        }

    }

    if ( $flag_add_one ) {
        $friendly_count++;
    }

    if ( $friendly_count == 0 || $enemy_count == 0 ) {
        return $friendly_count;
    }

    if ( $self->server()->race_of_acting_player()->has_technology( 'tech_stealth' ) ) {
        $enemy_count = int( $enemy_count / 2 );
    }

    if ( $enemy_count >= $friendly_count ) {
        return 0;
    }

    return $friendly_count - $enemy_count;
}

#############################################################################

sub user_ship_count {
    my $self        = shift;
    my $user_id     = shift;

    my $count = 0;

    foreach my $ship_tag ( $self->ships()->items() ) {
        if ( $self->server()->ships()->{ $ship_tag }->owner_id() == $user_id ) {
            $count++;
        }
    }

    return $count;
}

#############################################################################

sub enemy_ship_count {
    my $self        = shift;
    my $user_id     = shift;

    my $count = 0;

    foreach my $ship_tag ( $self->ships()->items() ) {
        my $ship = $self->server()->ships()->{ $ship_tag };

        if ( $ship->owner_id() != $user_id ) {

            if ( $self->server()->races()->{ $user_id }->provides( 'spec_descendants' ) ) {
                if ( $ship->class() ne 'class_ancient_cruiser' ) {
                    $count++;
                }
            }
            else {
                $count++;
            }

            # TODO if ships are allied - they shouldn't count
        }
    }

    return $count;
}

#############################################################################

sub vp_draw_queue {
    my $self        = shift;

    return $self->{'VP_DRAW_QUEUE'};
}

#############################################################################

sub set_vp_draw_queue {
    my $self        = shift;
    my @values      = @_;

    $self->vp_draw_queue()->fill( @values );

    return;
}

#############################################################################

sub attack_population_queue {
    my $self        = shift;

    return $self->{'ATTACK_POPULATION_QUEUE'}->items();
}

#############################################################################

sub owner_queue {
    my $self        = shift;

    return $self->{'OWNER_QUEUE'};
}

#############################################################################

sub add_ship {
    my $self        = shift;
    my $ship_tag    = shift;

    $self->ships()->add_items( $ship_tag );

    my $owner_id = $self->server()->ships()->{ $ship_tag }->owner_id();

    if ( $owner_id == $self->owner_id() ) {
        # the owner of the tile is defender against any other player
        $self->owner_queue()->remove_item( $owner_id );
        $self->owner_queue()->insert_item( $owner_id, 0 );
    }
    else {
        $self->owner_queue()->add_items( $owner_id );
    }

    if ( $self->owner_queue()->contains( -1 ) ) {
        # ancient ships are always considered the defender
        $self->owner_queue()->remove_item( -1 );
        $self->owner_queue()->insert_item( -1, 0 );
    }

    return;
}

#############################################################################

sub remove_ship {
    my $self        = shift;
    my $ship_tag    = shift;

    $self->ships()->remove_item( $ship_tag );

    my $owner_id = $self->server()->ships()->{ $ship_tag }->owner_id();

    my $flag_has_more_ships = 0;

    foreach my $other_tag ( $self->ships()->items() ) {
        if ( $self->server()->ships()->{ $other_tag }->owner_id() == $owner_id ) {
            $flag_has_more_ships = 1;
        }
    }

    unless ( $flag_has_more_ships ) {
        $self->owner_queue()->remove_item( $owner_id );
    }

    return;
}

#############################################################################

sub add_starting_ships {
    my $self        = shift;

    foreach my $ship_class ( $self->starting_ships() ) {

#        print STDERR "\nCreating NPC ship of class $ship_class ... ";

        my @templates_of_class = ();
        foreach my $template ( values( %{ $self->server()->templates() } ) ) {

#            print STDERR $template->tag() . ' ... ';
            if ( $template->class() eq $ship_class ) {
#                print STDERR 'match found ' . $template->count() . ' ... ';
                if ( $template->count() > 0 || $template->count() == -1 ) {
#                    print STDERR "pushed ... ";
                    push( @templates_of_class, $template->tag() );
                }
            }
        }

        WLE::Methods::Simple::shuffle_in_place( \@templates_of_class );
        my $template_tag = shift( @templates_of_class );

        $self->server()->_raw_create_ship_on_tile(
            $EV_FROM_INTERFACE,
            $self->tag(),
            $template_tag,
            -1,
        );

    }

    return;
}

#############################################################################

sub resource_slots {
    my $self            = shift;

    return @{ $self->{'RESOURCE_SLOTS'} };
}

#############################################################################

sub has_population_cubes {
    my $self            = shift;

    foreach my $slot ( $self->resource_slots() ) {
        if ( $slot->owner_id() > -1 ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub available_resource_spots {
    my $self            = shift;
    my $res_type        = shift;
    my $flag_advanced   = shift; $flag_advanced = 0             unless defined( $flag_advanced );

    my $count = 0;

    foreach my $slot ( $self->resource_slots() ) {
        unless ( $slot->resource_type() == $res_type ) {
            next;
        }

        unless ( $slot->is_advanced() == $flag_advanced ) {
            next;
        }

        unless ( $slot->owner_id() eq '-1' ) {
            next;
        }

        $count++;
    }

    return $count;
}

#############################################################################

sub add_cube {
    my $self            = shift;
    my $owner_id        = shift;
    my $type_enum       = shift;
    my $flag_advanced   = shift;

    my $type_text = WLE::4X::Enums::Basic::text_from_resource_enum( $type_enum );

    foreach my $slot ( $self->resource_slots() ) {
        unless ( $slot->resource_type() == $type_enum ) {
            next;
        }

        unless ( $slot->is_advanced() == $flag_advanced ) {
            next;
        }

        unless ( $slot->owner_id() eq '-1' ) {
            next;
        }

        $slot->set_owner_id( $owner_id );
        return 1;
    }

    return $self->add_cube( $owner_id, $RES_WILD, 0 );

    return 0;
}

#############################################################################

sub remove_cube {
    my $self            = shift;
    my $type_enum       = shift;
    my $flag_advanced   = shift;

    foreach my $slot ( $self->resource_slots() ) {
        unless ( $slot->resource_type() == $type_enum ) {
            next;
        }

        unless ( $slot->is_advanced() == $flag_advanced ) {
            next;
        }

        if ( $slot->owner_id() eq '-1' ) {
            next;
        }

        $slot->set_owner_id( -1 );
        return 1;
    }

    return 0;
}

#############################################################################

sub remove_all_cubes_of_owner {
    my $self            = shift;
    my $owner_id        = shift;

    my @cubes = ();

    foreach my $slot ( $self->resource_slots() ) {
        if ( $slot->owner_id() == $owner_id ) {
            $slot->set_owner_id( -1 );
            push( @cubes, $slot->resource_type() );
        }
    }

    return @cubes;
}

#############################################################################

sub add_slot {
    my $self        = shift;
    my $slot        = shift;

    push( @{ $self->{'RESOURCE_SLOTS'} }, $slot );

    return;
}

#############################################################################

sub set_ancient_link {
    my $self        = shift;
    my $value       = shift;

    $self->{'ANCIENT_LINK'} = $value;

    return;
}

#############################################################################

sub set_wormhole {
    my $self        = shift;
    my $value       = shift;

    $self->{'WORMHOLE'} = $value;

    return;
}

#############################################################################

sub set_vp {
    my $self        = shift;
    my $value       = shift;

    $self->{'VP'} = $value;

    return;
}

#############################################################################

sub has_warp_on_side {
    my $self        = shift;
    my $direction   = shift;

    unless ( WLE::Methods::Simple::looks_like_number( $direction ) ) {
        return 0;
    }

    while ( $direction < 0 ) {
        $direction += 6;
    }

    while ( $direction > 5 ) {
        $direction -= 6;
    }

    my $bitmask = 2 ** $direction;

    return ( ( $self->{'WARPS'} & $bitmask ) > 0 ) ? 1 : 0;
}

#############################################################################

sub are_new_warp_gates_valid {
    my $self        = shift;
    my $value       = shift;

    foreach ( 1 .. 6 ) {
        if ( $value == $self->{'WARPS'} ) {
            return 1;
        }

        $value = rotate_bits_left( $value, 6 );
    }

    return 0;
}

#############################################################################

sub has_combat {
    my $self        = shift;

    if ( $self->owner_queue()->count() <= 1 ) {
        return 0;
    }

    # TODO check for alliances

    return 1;
}

#############################################################################

sub set_combatant_ids {
    my $self        = shift;

    unless ( $self->has_combat() ) {
        return;
    }

    # TODO check for alliances

    my @owner_ids = $self->owner_queue()->items();

    $self->{'DEFENDER_ID'} = $owner_ids[ -2 ];
    $self->{'ATTACKER_ID'} = $owner_ids[ -1 ];

}

#############################################################################

sub current_combatant_ids {
    my $self        = shift;

    return ( $self->{'DEFENDER_ID'}, $self->{'ATTACKER_ID'} );
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;
    my $flag_m      = shift; $flag_m = 1                unless defined( $flag_m );

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
#        print STDERR "\nfailed to parse element from hash.";
        return 0;
    }

    foreach my $tag ( 'ID', 'WARPS', 'STACK' ) {
        unless ( defined( $r_hash->{ $tag } ) ) {
            return 0;
        }
    }

    foreach my $tag ( 'VP', 'ANCIENT_LINK', 'HIVE', 'DISCOVERY_COUNT', 'ORBITAL', 'MONOLITH', 'DEFENDER_ID', 'ATTACKER_ID' ) {
        if ( defined( $r_hash->{ $tag } ) ) {
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
                $self->{ $tag } = $r_hash->{ $tag };
            }
        }
    }

    foreach my $tag ( 'ID', 'WARPS', 'STACK', 'BOARD_LOCATION' ) {
        if ( defined( $r_hash->{ $tag } ) ) {
            $self->{ $tag } = $r_hash->{ $tag };
        }
    }

    foreach my $tag ( 'STARTING_SHIPS', 'DISCOVERIES' ) {
        if ( defined( $r_hash->{ $tag } ) ) {
            my @temp_array = @{ $r_hash->{ $tag } };
            $self->{ $tag } = \@temp_array;
        }
    }

    foreach my $tag ( 'SHIPS', 'OWNER_QUEUE', 'VP_DRAW_QUEUE' ) {
        $self->{ $tag }->fill( @{ $r_hash->{ $tag } } );
    }


    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        if ( ref( $r_hash->{'RESOURCES'} ) eq 'ARRAY' ) {
            foreach my $slot_hash ( @{ $r_hash->{'RESOURCES'} } ) {
                my $slot = WLE::4X::Objects::ResourceSpace->new();
                $slot->from_hash( $slot_hash );

                $self->add_slot( $slot );
            }
        }
    }

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'ID'} = sprintf( '%03i', $self->tile_id() );

#    unless( defined( $self->{'WARPS'} ) ) {
#        print "\nTile: " . $self->tag() . ' has no defined warps.';
#        exit();
#    }

    foreach my $tag ( 'STACK', 'VP', 'ANCIENT_LINK', 'HIVE', 'DISCOVERY_COUNT', 'ORBITAL', 'MONOLITH', 'ATTACKER_ID', 'DEFENDER_ID', 'WARPS', 'BOARD_LOCATION' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    foreach my $tag ( 'SHIPS', 'OWNER_QUEUE', 'VP_DRAW_QUEUE' ) {
        $r_hash->{ $tag } = [ $self->{ $tag }->items() ];
    }

    foreach my $tag ( 'STARTING_SHIPS', 'DISCOVERIES' ) {
        $r_hash->{ $tag } = [ @{ $self->{ $tag } } ];
    }

    my @resource_slots = ();

    foreach my $slot ( $self->resource_slots() ) {
        my %slot_hash = ();
        $slot->to_hash( \%slot_hash );
        push( @resource_slots, \%slot_hash );
    }

    $r_hash->{'RESOURCES'} = \@resource_slots;

    return 1;
}

#############################################################################
#############################################################################
1
