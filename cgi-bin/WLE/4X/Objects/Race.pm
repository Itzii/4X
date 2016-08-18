package WLE::4X::Objects::Race;

use strict;
use warnings;

use WLE::4X::Enums::Basic;

use WLE::4X::Objects::ResourceTrack;
use WLE::4X::Objects::TechTrack;

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

    $args{'type'} = 'race';

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $self->set_owner_id( -1 );

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    $self->{'BASE_TEMPLATES'} = {};
    if ( defined( $args{'base_templates'} ) ) {
        $self->{'BASE_TEMPLATES'} = $args{'base_templates'};
    }

    $self->{'EXCLUDE_RACE'} = '';
    $self->{'HOME'} = '';

    $self->{'COLONY_COUNT'} = 3;
    $self->{'COLONY_USED'} = 0;
    $self->{'EXCHANGE'} = 2;

    $self->{'ACTIONS'} = {
        'EXPLORE' => 1,
        'INFLUENCE_INF' => 2,
        'INFLUENCE_COLONY' => 2,
        'RESEARCH' => 1,
        'UPGRADE' => 2,
        'BUILD' => 2,
        'MOVE' => 3,
    };

    $self->{'ACTION_COUNT'} = 0;
    $self->{'ACTION_FLIP_COLONY_COUNT'} = 0;

    $self->{'IN_HAND'} = WLE::Objects::Stack->new();
    $self->{'COMPONENT_OVERFLOW'} = WLE::Objects::Stack->new();
    $self->{'GRAVEYARD'} = WLE::Objects::Stack->new();
    $self->{'DISCOVERY_VPS'} = WLE::Objects::Stack->new();

    $self->{'RESOURCES'} = {
        $RES_MONEY => 2,
        $RES_SCIENCE => 3,
        $RES_MINERALS => 3,
    };

    $self->{'TRACKS'} = {};

    my $track = WLE::4X::Objects::ResourceTrack->new( 'store_spent' => 1 );
    $track->set_values( -30, -25, -21, -17, -13, -10, -7, -5, -3, -2, -1, 0, 0, 0 );
    $track->add_to_track( 13 );

    $self->{'TRACKS'}->{ $RES_INFLUENCE } = $track;

    $track = WLE::4X::Objects::ResourceTrack->new();
    $track->set_values( 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2, 0 );
    $track->add_to_track( 11 );

    $self->{'TRACKS'}->{ $RES_SCIENCE } = $track;

    $track = WLE::4X::Objects::ResourceTrack->new();
    $track->set_values( 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2, 0 );
    $track->add_to_track( 11 );

    $self->{'TRACKS'}->{ $RES_MONEY } = $track;

    $track = WLE::4X::Objects::ResourceTrack->new();
    $track->set_values( 28, 24, 21, 18, 15, 12, 10, 8, 6, 4, 3, 2, 0 );
    $track->add_to_track( 11 );

    $self->{'TRACKS'}->{ $RES_MINERALS } = $track;

    $self->{'TECH'} = {};

    $track = WLE::4X::Objects::TechTrack->new();
    $self->{'TECH'}->{ $TECH_MILITARY } = $track;

    $track = WLE::4X::Objects::TechTrack->new();
    $self->{'TECH'}->{ $TECH_GRID } = $track;

    $track = WLE::4X::Objects::TechTrack->new();
    $self->{'TECH'}->{ $TECH_NANO } = $track;


    $self->{'STARTING_SHIPS'} = [ 'class_interceptor' ],

    $self->{'VP_SLOT_COUNTS'} = {
        $VP_AMBASSADOR => 1,
        $VP_BATTLE => 0,
        $VP_ANY => 4,
    };
    $self->{'VP_SLOTS'} = WLE::Objects::Stack->new();

    $self->{'VP_DRAWS'} = 0;

    $self->{'COST_ORBITAL'} = 5;

    $self->{'COST_MONUMENT'} = 10;

    $self->{'SHIP_TEMPLATES'} = [];

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub home_tile {
    my $self        = shift;

    return $self->{'HOME'};
}

#############################################################################

sub excludes {
    my $self        = shift;

    return $self->{'EXCLUDE_RACE'};
}

#############################################################################

sub action_count {
    my $self        = shift;

    return $self->{'ACTION_COUNT'};
}

#############################################################################

sub set_action_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'ACTION_COUNT'} = $value;

    return;
}

#############################################################################

sub maximum_action_count {
    my $self        = shift;
    my $action_type = shift;

    return $self->{'ACTIONS'}->{ $action_type };

}

#############################################################################

sub colony_flip_count {
    my $self        = shift;

    return $self->{'ACTION_FLIP_COLONY_COUNT'};
}

#############################################################################

sub set_colony_flip_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'ACTION_FLIP_COLONY_COUNT'} = $value;

    return;
}

#############################################################################

sub maximum_colony_flip_count {
    my $self        = shift;

    return $self->{'ACTIONS'}->{'INFLUENCE_COLONY'};
}

#############################################################################

sub total_colony_ships {
    my $self        = shift;

    return $self->{'COLONY_COUNT'};
}

#############################################################################

sub colony_ships_used {
    my $self        = shift;

    return $self->{'COLONY_USED'};
}

#############################################################################

sub set_colony_ships_used {
    my $self        = shift;
    my $value       = shift;

    $self->{'COLONY_USED'} = $value;

    return;
}

#############################################################################

sub colony_ships_available {
    my $self        = shift;

    return $self->total_colony_ships() - $self->colony_ships_used();
}

#############################################################################

sub component_overflow {
    my $self        = shift;

    return $self->{'COMPONENT_OVERFLOW'};
}

#############################################################################

sub graveyard {
    my $self        = shift;

    return $self->{'GRAVEYARD'};
}

#############################################################################

sub discovery_vps {
    my $self        = shift;

    return $self->{'DISCOVERY_VPS'};
}

#############################################################################

sub vp_items_in_slots {
    my $self            = shift;

    my %slots = (
        $VP_BATTLE => [],
        $VP_AMBASSADOR => [],
        $VP_ANY => [],
    );

    foreach my $item ( $self->{'VP_SLOTS'}->items() ) {
        my ( $type, $value ) = split( /:/, $item );

        if ( scalar( @{ $slots{ $type } } ) < $self->{'VP_SLOT_COUNTS'}->{ $type } ) {
            push( @{ $slots{ $type } }, $value )
        }
        else {
            push( @{ $slots{ $VP_ANY } }, $value )
        }
    }

    return %slots;
}


#############################################################################

sub can_add_vp_item {
    my $self            = shift;
    my $new_item        = shift;
    my $replaces_item   = shift; $replaces_item = ''                    unless defined( $replaces_item );

    unless ( $replaces_item eq ''  ) {
        if ( looks_like_number( $replaces_item ) ) {
            $replaces_item = $VP_BATTLE . ':' . $replaces_item;
        }
        else {
            $replaces_item = $VP_AMBASSADOR . ':' . $replaces_item;
        }

        unless ( $self->{'VP_SLOTS'}->contains( $replaces_item ) ) {
            return 0;
        }
    }

    if ( looks_like_number( $new_item ) ) {
        $new_item = $VP_BATTLE . ':' . $new_item;
    }
    else {
        $new_item = $VP_AMBASSADOR . ':' . $new_item;
    }

    my @items = ( $new_item );

    foreach my $item ( $self->{'VP_SLOTS'}->items() ) {
        unless ( $item eq $replaces_item ) {
            push( @items, $item );
        }
    }

    my $battle_count = $self->{'VP_SLOT_COUNTS'}->{ $VP_BATTLE };
    my $ambassador_count = $self->{'VP_SLOT_COUNTS'}->{ $VP_AMBASSADOR };
    my $extra_count = $self->{'VP_SLOT_COUNTS'}->{ $VP_ANY };

    foreach my $item ( @items ) {
        my ( $type ) = split( /:/, $item );
        if ( $type == $VP_BATTLE ) {
            if ( $battle_count > 0 ) {
                $battle_count--;
            }
            else {
                $extra_count--;
            }
        }
        else {
            if ( $ambassador_count > 0 ) {
                $ambassador_count--;
            }
            else {
                $extra_count--;
            }
        }
    }

    if ( $battle_count < 0 || $ambassador_count < 0 || $extra_count < 0 ) {
        return 0;
    }

    return 1;
}

#############################################################################

sub add_vp_item {
    my $self            = shift;
    my $item            = shift;
    my $replaces_item   = shift;

    unless ( $replaces_item eq ''  ) {
        if ( looks_like_number( $replaces_item ) ) {
            $replaces_item = $VP_BATTLE . ':' . $replaces_item;
        }
        else {
            $replaces_item = $VP_AMBASSADOR . ':' . $replaces_item;
        }

        $self->{'VP_SLOTS'}->remove_item( $replaces_item );
    }

    if ( looks_like_number( $item ) ) {
        $item = $VP_BATTLE . ':' . $item;
    }
    else {
        $item = $VP_AMBASSADOR . ':' . $item;
    }

    $self->{'VP_SLOTS'}->add_items( $item );

    return;
}

#############################################################################

sub remove_vp_item {
    my $self            = shift;
    my $item            = shift;

    if ( looks_like_number( $item ) ) {
        $item = $VP_BATTLE . ':' . $item;
    }
    else {
        $item = $VP_AMBASSADOR . ':' . $item;
    }

    $self->{'VP_SLOTS'}->remove_item( $item );

    return;
}

#############################################################################

sub vp_items {
    my $self            = shift;

    return $self->{'VP_SLOTS'}->items();
}

#############################################################################

sub vp_slot_count {
    my $self            = shift;
    my $slot_type       = shift;

    return $self->{'VP_SLOT_COUNTS'}->{ $slot_type };
}

#############################################################################

sub vp_draws {
    my $self        = shift;

    return $self->{'VP_DRAWS'};
}

#############################################################################

sub set_vp_draws {
    my $self        = shift;
    my $value       = shift;

    $self->{'VP_DRAWS'} = $value;

    return;
}

#############################################################################

sub exchange_rate {
    my $self        = shift;
    my $res_from    = shift;
    my $res_to      = shift;

    if ( $self->provides( 'spec_pirates' ) ) {
        if ( $res_from == $RES_MONEY ) {
            return ( 3, 2 );
        }
    }

    return ( $self->{'EXCHANGE'}, 1 );
}

#############################################################################

sub resource_count {
    my $self        = shift;
    my $type        = shift;

    return $self->{'RESOURCES'}->{ $type };
}

#############################################################################

sub add_resource {
    my $self        = shift;
    my $type        = shift;
    my $amount      = shift;

    $self->{'RESOURCES'}->{ $type } += $amount;

    return;
}

#############################################################################

sub exchange_resources {
    my $self        = shift;
    my $res_from    = shift;
    my $res_to      = shift;

    my ( $cost, $return ) = $self->exchange_rate( $res_from, $res_to );

    if ( $self->{'RESOURCES'}->{ $res_from } < $cost ) {
        return 0;
    }

    $self->{'RESOURCES'}->{ $res_from } -= $cost;
    $self->{'RESOURCES'}->{ $res_to } += $return;

    return 1;
}


#############################################################################

sub starting_ships {
    my $self        = shift;

    return @{ $self->{'STARTING_SHIPS'} };
}

#############################################################################

sub ship_templates {
    my $self        = shift;

    return @{ $self->{'SHIP_TEMPLATES'} };
}

#############################################################################

sub template_of_class {
    my $self        = shift;
    my $class       = shift;

#    print STDERR "\nAll Template Keys: " . join( ',', keys( %{ $self->server()->templates() } ) );
#    print STDERR "\nlooking for class " . $class;

    foreach my $template_tag ( $self->ship_templates() ) {

#        print STDERR "\n   looking for template " . $template_tag;

        my $template = $self->server()->templates()->{ $template_tag };

        if ( defined( $template ) ) {

#            print STDERR " ... class " . $template->class();

            if ( $template->class() eq $class ) {
#                print STDERR " found.";
                return $template;
            }
        }
    }

    return undef;
}

#############################################################################

sub resource_track_of {
    my $self        = shift;
    my $type_enum   = shift;

    return $self->{'TRACKS'}->{ $type_enum };
}

#############################################################################

sub tech_track_of {
    my $self        = shift;
    my $tech_enum   = shift;

    return $self->{'TECH'}->{ $tech_enum };
}
#############################################################################

sub has_technology {
    my $self        = shift;
    my $tech_tag    = shift;

    foreach ( $TECH_MILITARY, $TECH_GRID, $TECH_NANO ) {
        foreach my $possessed_tech_tag ( $self->tech_track_of( $_ )->techs() ) {
            my $tech = $self->server()->technology()->{ $possessed_tech_tag };

            if ( defined( $tech ) ) {
                if ( $tech->does_provide( $tech_tag ) ) {
                    return 1;
                }
            }
        }
    }

    return 0;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'HOME'} ) ) {
        return 0;
    }

    $self->{'HOME'} = $r_hash->{'HOME'};

    foreach my $value ( 'EXCLUDE_RACE', 'COLONY_COUNT', 'COLONY_USED', 'EXCHANGE', 'ACTION_COUNT', 'ACTION_FLIP_COLONY_COUNT', 'VP_DRAWS' ) {
        if ( defined( $r_hash->{ $value } ) ) {
            $self->{ $value } = $r_hash->{ $value };
        }
    }

    if ( defined( $r_hash->{'COMPONENT_OVERFLOW'} ) ) {
        $self->component_overflow()->fill( @{ $r_hash->{'COMPONENT_OVERFLOW'} } );
    }

    if ( defined( $r_hash->{'GRAVEYARD'} ) ) {
        $self->graveyard()->fill( @{ $r_hash->{'GRAVEYARD'} } );
    }

    if ( defined( $r_hash->{'DISCOVERY_VPS'} ) ) {
        $self->discovery_vps()->fill( @{ $r_hash->{'DISCOVERY_VPS'} } );
    }


    if ( defined( $r_hash->{'ACTIONS'} ) ) {
        foreach my $action_tag ( 'EXPLORE', 'INFLUENCE_INF', 'INFLUENCE_COLONY', 'RESEARCH', 'UPGRADE', 'BUILD', 'MOVE' ) {
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'ACTIONS'}->{ $action_tag } ) ) {
                $self->{'ACTIONS'}->{ $action_tag } = $r_hash->{'ACTIONS'}->{ $action_tag };
            }
        }
    }

    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        foreach my $resource_type ( $RES_MONEY, $RES_SCIENCE, $RES_MINERALS ) {
            my $resource_text = text_from_resource_enum( $resource_type );
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'ACTIONS'}->{ $resource_text } ) ) {
                $self->{'RESOURCES'}->{ $resource_type } = $r_hash->{'RESOURCES'}->{ $resource_text };
            }
        }
    }

    if ( defined( $r_hash->{'TRACKS'} ) ) {
        foreach my $track_tag ( 'INFLUENCE', 'MONEY', 'SCIENCE', 'MINERALS' ) {
            if ( defined( $r_hash->{'TRACKS'}->{ $track_tag } ) ) {
                my $hash = $r_hash->{'TRACKS'}->{ $track_tag };
                my $track = $self->resource_track_of( enum_from_resource_text( $track_tag ) );
                if ( defined( $track ) ) {
                    if ( defined( $hash->{'PROGRESSION'} ) ) {
                        $track->set_values( @{ $hash->{'PROGRESSION'} } );
                    }
                    if ( defined( $hash->{'COUNT'} ) ) {
                        $track->set_track_count( $hash->{'COUNT'} );
                    }
                    if ( defined( $hash->{'SPENT'} ) ) {
                        $track->set_spent_count( $hash->{'SPENT'} );
                    }
                }
            }
        }
    }

    if ( defined( $r_hash->{'TECH'} ) ) {
        foreach my $tech_type ( $TECH_MILITARY, $TECH_GRID, $TECH_NANO ) {
            my $tech_text = text_from_tech_enum( $tech_type );
            if ( defined( $r_hash->{'TECH'}->{ $tech_text} ) ) {
                $self->tech_track_of( $tech_type )->add_techs( @{ $r_hash->{'TECH'}->{ $tech_text } } );
            }
        }
    }

    if ( defined( $r_hash->{'STARTING_SHIPS'} ) ) {
        my @ships = @{ $r_hash->{'STARTING_SHIPS'} };
        $r_hash->{'STARTING_SHIPS'} = \@ships;
    }

    if ( defined( $r_hash->{'VP_SLOT_COUNTS'} ) ) {
        foreach my $section_enum ( 0 .. $VP_COUNT ) {
            my $section_tag = text_from_vp_enum( $section_enum );
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'VP_SLOT_COUNTS'}->{ $section_tag } ) ) {
                $self->{'VP_SLOT_COUNTS'}->{ $section_tag } = $r_hash->{'VP_SLOT_COUNTS'}->{ $section_tag };
            }
        }
    }

    if ( defined( $r_hash->{'VP_SLOTS'} ) ) {
        $self->{'VP_SLOTS'}->fill( @{ $r_hash->{'VP_SLOTS'} } );
    }


    foreach my $tag ( 'COST_ORBITAL', 'COST_MONUMENT' ) {
        if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
            $self->{ $tag } = $r_hash->{ $tag };
        }
    }

    my @templates = ();

    if ( defined( $r_hash->{'SHIP_TEMPLATES'} ) ) {
        if ( ref( $r_hash->{'SHIP_TEMPLATES'} ) eq 'ARRAY' ) {

            my $template_index = 1;

            foreach my $template_section ( @{ $r_hash->{'SHIP_TEMPLATES'} } ) {

                if ( ref( $template_section ) eq 'HASH' ) {

                    if ( defined( $template_section->{'COST'} ) ) {
                        my $tag = 'shiptemplate_' . $self->tag() . '_' . $template_index;

                        my $original_template = $self->{'BASE_TEMPLATES'}->{ $template_section->{'TAG'} };
                        if ( defined( $original_template ) ) {
                            my $template = $original_template->copy_of( $tag );

                            if ( defined( $template ) ) {

                                $template->set_long_name( $template_section->{'LONG_NAME'} );
                                $template->set_cost( $template_section->{'COST'} );

                                push( @templates, $template->tag() );
                                $self->server()->templates()->{ $template->tag() } = $template;

                                push( @{ $self->{'SHIP_TEMPLATES'} }, $tag );
                            }
                        }
                        else {
#                            print STDERR "\nBase Template not defined: " . $template_section->{'TAG'};
                        }
                    }

                    $template_index++;
                }
                else {
                    push( @templates, $template_section );
                }
            }
        }
    }

    $self->{'SHIP_TEMPLATES'} = \@templates;

#    print STDERR "\nTemplates for " . $self->tag() . " : " . join( ',', @templates );

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    foreach my $tag ( 'HOME', 'EXCLUDE_RACE', 'COLONY_COUNT', 'COLONY_USED', 'EXCHANGE', 'COST_ORBITAL', 'COST_MONUMENT', 'ACTION_COUNT', 'ACTION_FLIP_COLONY_COUNT', 'VP_DRAWS' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    $r_hash->{'COMPONENT_OVERFLOW'} = [ $self->component_overflow()->items() ];
    $r_hash->{'GRAVEYARD'} = [ $self->graveyard()->items() ];
    $r_hash->{'DICOVERY_VPS'} = [ $self->discovery_vps()->items() ];

    $r_hash->{'ACTIONS'} = {};
    foreach my $action_tag ( 'EXPLORE', 'INFLUENCE_INF', 'INFLUENCE_COLONY', 'RESEARCH', 'UPGRADE', 'BUILD', 'MOVE' ) {
        $r_hash->{'ACTION'}->{ $action_tag } = $self->{'ACTIONS'}->{ $action_tag };
    }

    $r_hash->{'RESOURCES'} = {};
    foreach my $resource_type ( $RES_MONEY, $RES_SCIENCE, $RES_MINERALS ) {
        $r_hash->{'RESOURCES'}->{ text_from_resource_enum( $resource_type ) } = $self->{'RESOURCES'}->{ $resource_type };
    }

    $r_hash->{'TRACKS'} = {};
    foreach my $track_tag ( 'INFLUENCE', 'MONEY', 'SCIENCE', 'MINERALS' ) {
        my $type = enum_from_resource_text( $track_tag );
        my $track = $self->resource_track_of( $type );

        $r_hash->{'TRACKS'}->{ $track_tag } = {
            'PROGRESSION' => [ $track->values() ],
            'COUNT'         => $track->available_to_spend(),
            'SPENT'         => $track->spent_count(),
        };
    }

    $r_hash->{'TECH'} = {};
    foreach my $tech_type ( $TECH_MILITARY, $TECH_GRID, $TECH_NANO ) {
        my $tech_text = text_from_tech_enum( $tech_type );
        $r_hash->{'TECH'}->{ $tech_text } = [ $self->tech_track_of( $tech_type )->techs() ];
    }

    my @ships = @{ $self->{'STARTING_SHIPS'} };
    $r_hash->{'STARTING_SHIPS'} = \@ships;

    $r_hash->{'VP_SLOT_COUNTS'} = {};
    foreach my $section_enum ( 0 .. $VP_COUNT - 1 ) {
        my $section_tag = text_from_vp_enum( $section_enum );
        $r_hash->{'VP_SLOT_COUNTS'}->{ $section_tag } = $self->{'VP_SLOT_COUNTS'}->{ $section_enum };
    }

    $r_hash->{'VP_SLOTS'} = [ $self->{'VP_SLOTS'}->items() ];

    $r_hash->{'SHIP_TEMPLATES'} = $self->{'SHIP_TEMPLATES'};

    return 1;
}

#############################################################################
#############################################################################
1
