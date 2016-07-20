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

    $self->{'ALLOWED_ACTIONS'} = WLE::Objects::Stack->new();

    $self->{'IN_HAND'} = WLE::Objects::Stack->new();
    $self->{'COMPONENT_OVERFLOW'} = WLE::Objects::Stack->new();

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

    $self->{'VP_SLOTS'} = {
        'AMBASSADOR' => 1,
        'BATTLE' => 0,
        'ANY' => 4,
    };

    $self->{'COST_ORBITAL'} = 5;

    $self->{'COST_MONUMENT'} = 10;

    $self->{'SHIP_TEMPLATES'} = [];

    $self->{'FLAG_PASSED'} = 0;

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

sub has_passed {
    my $self        = shift;

    return ( $self->{'FLAG_PASSED'} == 1 );
}

#############################################################################

sub set_flag_passed {
    my $self        = shift;
    my $value       = shift;

    $self->{'FLAG_PASSED'} = $value;

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

sub in_hand {
    my $self        = shift;

    return $self->{'IN_HAND'};
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
        if ( defined( $self->server()->components()->{ $item } ) ) {
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

sub start_turn {
    my $self        = shift;

    $self->{'ACTION_COUNT'} = 0;
    $self->{'ACTION_FLIP_COLONY_COUNT'} = 0;
    $self->allowed_actions()->clear();

    my $has_movable_ships = 0;

    foreach my $tile_tag ( $self->server()->board()->tiles_on_board() ) {
        if ( $self->server()->tiles()->{ $tile_tag }->unpinned_ship_count( $self->owner_id() ) ) {
            $has_movable_ships = 1;
            last;
        }
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
            'use_colony_ship',
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

sub can_explore {
    my $self        = shift;

    my @explorable_locations = $self->server()->board()->explorable_spaces_for_race( $self->tag() );
    return ( scalar( @explorable_locations ) > 0 );
}

#############################################################################

sub end_turn {
    my $self        = shift;

    $self->allowed_actions()->clear();

    return;
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

    foreach my $template_tag ( $self->ship_templates() ) {

        my $template = $self->server()->templates()->{ $template_tag };

        if ( defined( $template ) ) {
            if ( $template->class() eq $class ) {
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
                if ( $tech->provides( $tech_tag ) ) {
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

    foreach my $value ( 'FLAG_PASSED', 'EXCLUDE_RACE', 'COLONY_COUNT', 'COLONY_USED', 'EXCHANGE', 'ACTION_COUNT', 'ACTION_FLIP_COLONY_COUNT', 'IN_HAND' ) {
        if ( defined( $r_hash->{ $value } ) ) {
            $self->{ $value } = $r_hash->{ $value };
        }
    }

    if ( defined( $r_hash->{'COMPONENT_OVERFLOW'} ) ) {
        $self->{'COMPONENT_OVERFLOW'}->add_items( @{ $r_hash->{'COMPONENT_OVERFLOW'} } );
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

    if ( defined( $r_hash->{'VP_SLOTS'} ) ) {
        foreach my $section_tag ( 'AMBASSADOR', 'BATTLE', 'ANY' ) {
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'VP_SLOTS'}->{ $section_tag } ) ) {
                $self->{'VP_SLOTS'}->{ $section_tag } = $r_hash->{'VP_SLOTS'}->{ $section_tag };
            }
        }
    }

    foreach my $tag ( 'COST_ORBITAL', 'COST_MONUMENT' ) {
        if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
            $self->{ $tag } = $r_hash->{ $tag };
        }
    }

    if ( defined( $r_hash->{'ALLOWED_ACTIONS'} ) ) {
        $self->allowed_actions()->add_items( @{ $r_hash->{'ALLOWED_ACTIONS'} } );
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
                    }

                    $template_index++;
                }
                else {

                    push( @{ $self->{'SHIP_TEMPLATES'} }, $template_section );
                }
            }
        }
    }

    $self->{'SHIP_TEMPLATES'} = \@templates;

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    foreach my $tag ( 'HOME', 'EXCLUDE_RACE', 'COLONY_COUNT', 'COLONY_USED', 'EXCHANGE', 'COST_ORBITAL', 'COST_MONUMENT', 'FLAG_PASSED', 'ACTION_COUNT', 'ACTION_FLIP_COLONY_COUNT' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    $r_hash->{'IN_HAND'} = [ $self->in_hand()->items() ];
    $r_hash->{'COMPONENT_OVERFLOW'} = [ $self->component_overflow()->items() ];

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

    $r_hash->{'VP_SLOTS'} = {};
    foreach my $section_tag ( 'AMBASSADOR', 'BATTLE', 'ANY' ) {
        $r_hash->{'VP_SLOTS'}->{ $section_tag } = $self->{'VP_SLOTS'}->{ $section_tag };
    }

    $r_hash->{'ALLOWED_ACTIONS'} = [ $self->allowed_actions()->items() ];

    $r_hash->{'SHIP_TEMPLATES'} = $self->{'SHIP_TEMPLATES'};

    return 1;
}

#############################################################################
#############################################################################
1
