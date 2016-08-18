package WLE::4X::Objects::Player;

use strict;
use warnings;


use WLE::Methods::Simple;
use WLE::Objects::Stack;

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;

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

    unless ( defined( $args{'server'} ) ) {
        return undef;
    }

    $self->{'ID'} = undef;

    $self->{'SERVER'} = $args{'server'};

    $self->{'USER_ID'} = '';

    $self->{'LONG_NAME'} = '';

    $self->{'RACE_TAG'} = '';

    $self->{'ALLOWED_ACTIONS'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
    $self->{'IN_HAND'} = WLE::Objects::Stack->new();

    $self->{'FLAG_PASSED'} = 0;
    $self->{'FLAG_IS_OWNER'} = 0;

    if ( defined( $args{'id'} ) ) {
        $self->{'ID'} = $args{'id'};
    }

    if ( defined( $args{'user_id'} ) ) {
        $self->{'USER_ID'} = $args{'user_id'};
    }


    return $self;
}

#############################################################################

sub server {
    my $self        = shift;

    return $self->{'SERVER'};
}

#############################################################################

sub id {
    my $self        = shift;

    return $self->{'ID'};
}

#############################################################################

sub set_id {
    my $self        = shift;
    my $value       = shift;

    $self->{'ID'} = $value;

    return;
}

#############################################################################

sub user_id {
    my $self        = shift;

    return $self->{'USER_ID'};
}

#############################################################################

sub set_user_id {
    my $self        = shift;
    my $id          = shift;

    $self->{'USER_ID'} = $id;

    return;
}

#############################################################################

sub long_name {
    my $self        = shift;

    if ( $self->{'LONG_NAME'} eq '' ) {
        return 'Player #' . $self->user_id();
    }

    return $self->{'LONG_NAME'};
}

#############################################################################

sub set_long_name {
    my $self        = shift;
    my $value       = shift;

    $self->{'LONG_NAME'} = $value;

    return;
}

#############################################################################

sub race_tag {
    my $self        = shift;

    return $self->{'RACE_TAG'};
}

#############################################################################

sub set_race_tag {
    my $self        = shift;
    my $value       = shift;

    $self->{'RACE_TAG'} = $value;

    return;
}

#############################################################################

sub has_passed {
    my $self        = shift;

    return ( $self->{'FLAG_PASSED'} == 1 ) ? 1 : 0;
}

#############################################################################

sub set_flag_passed {
    my $self        = shift;
    my $value       = shift;

    $self->{'FLAG_PASSED'} = $value;

    return;
}

#############################################################################

sub is_owner {
    my $self        = shift;

    return $self->{'FLAG_IS_OWNER'};
}

#############################################################################

sub set_is_owner {
    my $self        = shift;
    my $value       = shift;

    $self->{'FLAG_IS_OWNER'} = $value;

    return;
}

#############################################################################

sub allowed_actions {
    my $self        = shift;

    return $self->{'ALLOWED_ACTIONS'};
}

#############################################################################

sub adjusted_allowed_actions {
    my $self        = shift;

    my $list = WLE::Objects::Stack->new();

    # has discoveries in hand from influencing tile
    if ( $self->has_discovery_in_hand() ) {
        $list->add_items( 'choose_discovery' );
    }

    # has influence token in hand from influence action
    elsif ( $self->in_hand()->contains( 'influence_token' ) ) {
        $list->add_items( 'place_influence_token' );
    }

    # has multiple technologies in hand from discovery tile
    elsif ( $self->has_technology_in_hand() ) {
        $list->add_items( 'select_free_technology' );
    }

    # component is in hand from either upgrade action or discovery tile
    elsif ( $self->has_component_in_hand() ) {
        $list->add_items( 'place_component' );
    }

    # cube in hand from de-influencing tile
    elsif ( $self->has_cube_in_hand() ) {
        $list->add_items( 'replace_cube' );
    }

    else {
        return $self->allowed_actions();
    }

    return $list;
}

#############################################################################

sub in_hand {
    my $self        = shift;

    return $self->{'IN_HAND'};
}

#############################################################################

sub bare_in_hand {
    my $self        = shift;

    my @items = ();

    foreach my $item ( $self->in_hand()->items() ) {
        my @parts = split( /:/, $item );
        push( @items, $parts[ -1 ] );
    }

    return @items;
}

#############################################################################

sub has_discovery_in_hand {
    my $self        = shift;

    foreach my $item ( $self->in_hand()->items() ) {
        my ( $tile_tag, $discovery_tag ) = split( /:/, $item );

        if ( defined( $discovery_tag ) ) {
            if ( defined( $self->server()->discoveries()->{ $discovery_tag } ) ) {
                return 1;
            }
        }
    }

    return 0;
}

#############################################################################

sub has_component_in_hand {
    my $self        = shift;

    foreach my $item ( $self->in_hand()->items() ) {
        if ( defined( $self->server()->ship_components()->{ $item } ) ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub has_technology_in_hand {
    my $self        = shift;

    foreach my $item ( $self->in_hand()->items() ) {
        if ( defined( $self->server()->technology()->{ $item } ) ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub has_tile_in_hand {
    my $self        = shift;
    my $r_loc_x     = shift; # optional
    my $r_loc_y     = shift; # optional

    foreach my $item ( $self->in_hand()->items() ) {
        my ( $loc_x, $loc_y, $tile_tag ) = split( /:/, $item );
        if ( defined( $tile_tag ) ) {
            if ( defined( $self->server()->tiles()->{ $tile_tag } ) ) {

                if ( defined( $r_loc_x ) ) {
                    $$r_loc_x = $loc_x;
                }
                if ( defined( $r_loc_y ) ) {
                    $$r_loc_y = $loc_y;
                }
                return 1;
            }
        }
    }

    return 0;
}

#############################################################################

sub remove_all_technologies_from_hand {
    my $self        = shift;

    foreach my $item ( $self->in_hand()->items() ) {
        if ( defined( $self->server()->technology()->{ $item } ) ) {
            $self->in_hand()->remove_item( $item );
        }
    }

    return;
}

#############################################################################

sub has_cube_in_hand {
    my $self        = shift;

    foreach my $item ( $self->in_hand()->items() ) {
        if ( $item =~ m{ ^ cube: }xs ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub can_explore {
    my $self        = shift;

    my @explorable_locations = $self->server()->board()->explorable_spaces_for_player( $self->id() );
    return ( scalar( @explorable_locations ) > 0 );
}

#############################################################################

sub start_turn {
    my $self        = shift;

    if ( defined( $self->race() ) ) {
        $self->race()->set_action_count( 0 );
        $self->race()->set_colony_flip_count( 0 );
    }

    $self->allowed_actions()->clear();

    my $has_movable_ships = 0;

    foreach my $tile_tag ( $self->server()->board()->tiles_on_board() ) {
        if ( $self->server()->tiles()->{ $tile_tag }->unpinned_ship_count( $self->id() ) ) {
            $has_movable_ships = 1;
            last;
        }
    }

    if ( $self->server()->state() == $ST_RACESELECTION ) {
        $self->allowed_actions()->add_items( 'select_race' );
        return;
    }

    if ( $self->has_passed() ) {
        $self->allowed_actions()->add_items(
            'action_pass',
            'action_react_upgrade',
            'action_react_build',
        );

        if ( $has_movable_ships ) {
            $self->allowed_actions()->add_items( 'action_react_move' );
        }
    }
    else {
        $self->allowed_actions()->add_items(
            'action_pass',
            'action_influence',
            'action_research',
            'action_upgrade',
            'action_build',
        );

        if ( $self->can_explore() ) {
            $self->allowed_actions()->add_items( 'action_explore' );
        }

        if ( $has_movable_ships ) {
            $self->allowed_actions()->add_items( 'action_move' );
        }

    }

    return;
}

#############################################################################

sub end_turn {
    my $self        = shift;

    $self->allowed_actions()->clear();

    return;
}

#############################################################################

sub start_upkeep {
    my $self        = shift;

    my @actions = ();

    if ( $self->race()->colony_ships_available() > 0 ) {
        push( @actions, 'upkeep_colony_ship' );
    }

    my $upkeep_cost = $self->race()->resource_track_of( $RES_INFLUENCE )->track_value();

    if ( $upkeep_cost <= $self->race()->resource_count( $RES_MONEY ) ) {
        push( @actions, 'pay_upkeep' );
    }
    else {
        push( @actions, 'pull_influence' )
    }

    $self->allowed_actions()->fill( @actions );

    return;
}

#############################################################################

sub race {
    my $self        = shift;

    return $self->server()->races()->{ $self->race_tag() };
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $self->set_id( $r_hash->{'ID'} );
    $self->set_user_id( $r_hash->{'USER_ID'} );
    $self->set_long_name( $r_hash->{'LONG_NAME'} );
    $self->set_race_tag( $r_hash->{'RACE_TAG'} );
    $self->set_flag_passed( $r_hash->{'FLAG_PASSED'} );
    $self->set_is_owner( $r_hash->{'FLAG_IS_OWNER'} );

    $self->allowed_actions()->fill( @{ $r_hash->{'ALLOWED_ACTIONS'} } );
    $self->in_hand()->fill( @{ $r_hash->{'IN_HAND'} } );

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'ID'} = $self->id();
    $r_hash->{'USER_ID'} = $self->user_id();
    $r_hash->{'LONG_NAME'} = $self->long_name();
    $r_hash->{'RACE_TAG'} = $self->race_tag();
    $r_hash->{'FLAG_PASSED'} = $self->has_passed();
    $r_hash->{'FLAG_IS_OWNER'} = $self->is_owner();

    $r_hash->{'ALLOWED_ACTIONS'} = [ $self->allowed_actions()->items() ];
    $r_hash->{'IN_HAND'} = [ $self->in_hand()->items() ];

    return 1;
}

#############################################################################
#############################################################################
1
