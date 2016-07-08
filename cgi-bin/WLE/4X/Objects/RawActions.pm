package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Enums::Basic;

#############################################################################

sub _raw_add_source {
    my $self        = shift;
    my $tag         = shift;

    push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_source {
    my $self        = shift;
    my $tag         = shift;

    my @current_tags = $self->source_tags();
    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [];

    foreach my $t ( @current_tags ) {
        unless ( $t eq $tag ) {
            push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $t );
        }
    }

    return;
}

#############################################################################

sub _raw_add_option {
    my $self        = shift;
    my $tag         = shift;

    push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_option {
    my $self        = shift;
    my $tag         = shift;

    my @current_tags = $self->source_tags();
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [];

    foreach my $t ( @current_tags ) {
        unless ( $t eq $tag ) {
            push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $t );
        }
    }

    return;
}


#############################################################################

sub _raw_add_player {
    my $self        = shift;
    my $player_id   = shift;

    push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $player_id );

    return;
}


#############################################################################

sub _raw_remove_player {
    my $self        = shift;
    my $player_id   = shift;

    my @current_ids = $self->player_ids();
    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [];

    foreach my $id ( @current_ids ) {
        unless ( $id == $player_id ) {
            push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $id );
        }
    }

    return;
}

#############################################################################

sub _raw_begin {
    my $self       = shift;

    my $fh = undef;

#    print STDERR "\nraw_begin ... ";

    unless ( open( $fh, '<', $self->_file_resources() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_file_resources() );
        print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    flock( $fh, LOCK_SH );

    # using Data::Dumper

#    print STDERR "\nparsing ... ";

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    # settings
#    print STDERR "\n  settings ... ";

    unless ( defined( $VAR1->{'PLAYER_COUNT_SETTINGS'} ) ) {
        $self->set_error( 'Missing Section in resource file: PLAYER_COUNT_SETTINGS' );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    my $settings = $VAR1->{'PLAYER_COUNT_SETTINGS'}->{ scalar( $self->player_ids() ) };

    unless ( defined( $settings ) ) {
        $self->set_error( 'Invalid Player Count: ' . scalar( $self->player_ids() ) );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    unless ( $self->has_source( $settings->{'SOURCE_TAG'} ) ) {
        $self->set_error( 'Invalid player count for chosen sources: ' . scalar( $self->player_ids() ) );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    $self->{'TECH_DRAW_COUNT'} = $settings->{'ROUND_TECH_COUNT'};

    $self->{'STARTING_LOCATIONS'} = $settings->{'POSITIONS'};




    # setup ship component tiles
    # print STDERR "\n  ship components ... ";

    unless ( defined( $VAR1->{'COMPONENTS'} ) ) {
        $self->set_error( 'Missing Section in resource file: COMPONENTS' );
        return 0;
    }

    $self->{'COMPONENTS'} = {};

    foreach my $component_key ( keys( %{ $VAR1->{'COMPONENTS'} } ) ) {
        my $component = WLE::4X::Objects::ShipComponent->new(
            'server' => $self,
            'tag' => $component_key,
            'hash' => $VAR1->{'COMPONENTS'}->{ $component_key },
        );

        if ( defined( $component ) ) {

            if ( matches_any( $component->source_tag(), $self->source_tags() ) ) {
                if ( $component->required_option() eq '' ) {
                    $self->{'COMPONENTS'}->{ $component_key } = $component;
                }
                elsif ( matches_any( $component->required_option(), $self->option_tags() ) ) {
                    $self->{'COMPONENTS'}->{ $component_key } = $component;
                }
            }
        }
    }

    # setup technology tiles
#    print STDERR "\n  technology ... ";

    unless ( defined( $VAR1->{'TECHNOLOGY'} ) ) {
        $self->set_error( 'Missing Section in resource file: TECHNOLOGY' );
        return 0;
    }

    $self->{'TECHNOLOGY'} = {};
    my @tech_bag = ();

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new(
            'server' => $self,
            'tag' => $tech_key,
            'hash' => $VAR1->{'TECHNOLOGY'}->{ $tech_key },
        );

        if ( defined( $technology ) ) {
            if ( matches_any( $technology->source_tag(), $self->source_tags() ) ) {
                if (
                    $technology->required_option() eq ''
                    || matches_any( $technology->required_option(), $self->option_tags() )
                ) {
                    $self->{'TECHNOLOGY'}->{ $technology->tag() } = $technology;

                    foreach ( 1 .. $technology->count() ) {
                        push( @tech_bag, $technology->tag() );
                    }
                }
            }
        }
    }

    $self->{'TECH_BAG'} = \@tech_bag;

    # draw beginning tech tiles

    my @available_tech = ();

    foreach ( 1 .. $settings->{'START_TECH_COUNT'} ) {
        push( @available_tech, shift( @tech_bag ) );
    }

    $self->{'AVAILABLE_TECH'} = \@available_tech;

    # vp tokens
    # print STDERR "\n  vp tokens ... ";

    $self->{'VP_BAG'} = [];

    foreach my $value ( 1 .. 4 ) {
        if ( defined( $settings->{'VP_' . $value } ) ) {
            foreach ( 0 .. $settings->{'VP_' . $value } - 1 ) {
                push( @{ $self->{'VP_BAG'} }, $value );
            }
        }
    }

    # discoveries
#    print STDERR "\n  discoveries ... ";

    $self->{'DISCOVERIES'} = {};

    my @discovery_bag = ();

    foreach my $disc_key ( keys( %{ $VAR1->{'DISCOVERIES'} } ) ) {

        my $discovery = WLE::4X::Objects::Discovery->new(
            'server' => $self,
            'tag' => $disc_key,
            'hash' => $VAR1->{'DISCOVERIES'}->{ $disc_key },
        );

        if ( defined( $discovery ) ) {
            if ( matches_any( $discovery->source_tag(), $self->source_tags() ) ) {
                if (
                    $discovery->required_option() eq ''
                    || matches_any( $discovery->required_option(), $self->option_tags() )
                ) {
                    $self->{'DISCOVERIES'}->{ $discovery->tag() } = $discovery;

                    foreach ( 1 .. $discovery->count() ) {
                        push( @discovery_bag, $discovery->tag() );
                    }
                }
            }
        }
    }

    $self->{'DISCOVERY_BAG'} = \@discovery_bag;

    # tiles
#    print STDERR "\n  tiles ... ";


    $self->{'TILE_STACK_1'} = [];
    $self->{'TILE_STACK_2'} = [];
    $self->{'TILE_STACK_3'} = [];

    $self->{'TILES'} = {};

#    print STDERR "\nCreating Board ... ";
    $self->{'BOARD'} = WLE::4X::Objects::Board->new( 'server' => $self );

#    print STDERR "\nReading Tiles ... ";

    foreach my $tile_key ( keys( %{ $VAR1->{'TILES'} } ) ) {

        my $tile = WLE::4X::Objects::Tile->new(
            'server' => $self,
            'tag' => $tile_key,
            'hash' => $VAR1->{'TILES'}->{ $tile_key },
        );

#        print "\nTile: " . $tile->tag();

        if ( defined( $tile ) ) {
            if ( matches_any( $tile->source_tag(), $self->source_tags() ) ) {
                if (
                    $tile->required_option() eq ''
                    || matches_any( $tile->required_option(), $self->option_tags() )
                ) {
                    $self->{'TILES'}->{ $tile->tag() } = $tile;

#                    print STDERR "\n" . $tile->as_ascii();

                    if ( $tile->which_stack() == 0 ) {
                        $self->board()->place_tile( 0, 0, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 1 ) {
                        push( @{ $self->{'TILE_STACK_1'} }, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 2 ) {
                        push( @{ $self->{'TILE_STACK_2'} }, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 3 ) {
                        push( @{ $self->{'TILE_STACK_3'} }, $tile->tag() );
                    }
                }
            }
        }
    }

    foreach my $count ( 1 .. 3 ) {
        if ( defined( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
            if ( looks_like_number( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
                $self->{'SETTINGS'}->{'TILE_STACK_LIMIT_' . $count } = $settings->{'SECTOR_LIMIT_' . $count };
            }
        }
    }


    # developments
#    print STDERR "\n  developments ... ";

    $self->{'DEVELOPMENTS'} = {};
    $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} = -1;
    if ( looks_like_number( $settings->{'DEVELOPMENTS'} ) ) {
        $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} = $settings->{'DEVELOPMENTS'};
    }

    foreach my $dev_key ( keys( %{ $VAR1->{'DEVELOPMENTS'} } ) ) {

        my $development = WLE::4X::Objects::Development->new(
            'server' => $self,
            'tag' => $dev_key,
            'hash' => $VAR1->{'DEVELOPMENTS'}->{ $dev_key },
        );

        if ( defined( $development ) ) {
            if ( matches_any( $development->source_tag(), $self->source_tags() ) ) {
                if (
                    $development->required_option() eq ''
                    || matches_any( $development->required_option(), $self->option_tags() )
                ) {
                    $self->{'DEVELOPMENTS'}->{ $dev_key } = $development;
                }
            }
        }
    }

    # ship templates

#    print STDERR "\n  ship templates ... ";

    $self->{'SHIP_TEMPLATES'} = {};

    foreach my $template_key ( keys( %{ $VAR1->{'SHIP_TEMPLATES'} } ) ) {

#        print STDERR Dumper( $VAR1->{'SHIP_TEMPLATES'}->{ $template_key } );


        my $template = WLE::4X::Objects::ShipTemplate->new(
            'server' => $self,
            'tag' => $template_key,
            'hash' => $VAR1->{'SHIP_TEMPLATES'}->{ $template_key },
        );

        if ( defined( $template ) ) {
            $self->{'SHIP_TEMPLATES'}->{ $template->tag() } = $template;
        }
    }


    # races
#    print STDERR "\n  races ... ";

    $self->{'RACES'} = {};

    foreach my $race_key ( keys( %{ $VAR1->{'RACES'} } ) ) {

        my $race = WLE::4X::Objects::Race->new(
            'server' => $self,
            'tag' => $race_key,
            'hash' => $VAR1->{'RACES'}->{ $race_key },
        );

#        print STDERR "\nRace: " . $race->tag();

        if ( defined( $race ) ) {

            my %race_hash = ();
            $race->to_hash( \%race_hash );
#            print STDERR "\n" . Dumper( \%race_hash );

            if ( matches_any( $race->source_tag(), $self->source_tags() ) ) {
                if (
                    $race->required_option() eq ''
                    || matches_any( $race->required_option(), $self->option_tags() )
                ) {
                    $self->{'RACES'}->{ $race->tag() } = $race;
                }
            }
        }
    }

    return;
}

#############################################################################

sub _raw_set_player_order {
    my $self            = shift;
    my @new_order_ids   = @_;

    $self->{'SETTINGS'}->{'PLAYERS_DONE'} = [];
    $self->{'SETTINGS'}->{'PLAYERS_PENDING'} = [ @new_order_ids ];

    return;
}

#############################################################################

sub _raw_create_tile_stack {
    my $self            = shift;
    my $stack_id        = shift;
    my @values          = @_;

    $self->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} = [ @values ];
    $self->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} = [];

    return;
}

#############################################################################

sub _raw_create_development_stack {
    my $self            = shift;
    my @values          = @_;

    $self->{'DEVELOPMENT_STACK'} = [ @values ];

    return;
}

#############################################################################

sub _raw_select_race_and_location {
    my $self            = shift;
    my $race_tag        = shift;
    my $location_x      = shift;
    my $location_y      = shift;
    my $warp_gates      = shift;

    my $race = $self->races()->{ $race_tag };

    $race->set_owner_id( $self->current_user() );

    unless ( $self->has_option( 'all_races' ) ) {
        my $backing_race = $race->excludes();
        delete ( $self->races()->{ $backing_race } );
    }

    my $start_hex_tag = $race->home_tile();

    my $start_hex = $self->tiles()->{ $start_hex_tag };

    $start_hex->set_warps( $warp_gates );

    $self->board()->place_tile( $location_x, $location_y, $start_hex_tag );

    $self->_raw_influence_tile( $race_tag, $start_hex_tag );


    # place cubes on available spots

    my @types = (
        [ $RES_SCIENCE, 'tech_advanced_labs' ],
        [ $RES_MONEY, 'tech_advanced_economy' ],
        [ $RES_MINERALS, 'tech_advanced_mining' ],
    );

    foreach my $type ( @types ) {
        my $open_slots = $start_hex->available_resource_spots( $type->[ 0 ], 0 );

        foreach ( 1 .. $open_slots ) {
            $start_hex->add_cube( $race->owner_id(), $type->[ 0 ], 0 )
        }

        if ( $race->has_technology( $type->[ 1 ] ) ) {

            $open_slots = $start_hex->available_resource_spots( $type->[ 0 ], 1 );

            foreach ( 1 .. $open_slots ) {
                $race->remove_cube( $type->[ 0 ] );
                $start_hex->add_cube( $race->owner_id(), $type->[ 0 ], 1 )
            }
        }
    }

    # build and place initial ships

    foreach my $ship_class ( $race->starting_ships() ) {
        my $ship = $race->create_ship_of_class( $ship_class );

        if ( defined( $ship ) ) {
            print STDERR "\nPlacing Ship: " . $ship->tag();
            $start_hex->add_ship( $ship->tag() );
        }
    }

    return;
}

#############################################################################

sub _raw_place_cube_on_tile {
    my $self            = shift;
    my $race_tag        = shift;
    my $tile_tag        = shift;
    my $type            = shift;
    my $flag_advanced   = shift; $flag_advanced = 0             unless defined( $flag_advanced );

    my $race = $self->races()->{ $race_tag };
    my $tile = $self->tiles()->{ $tile_tag };

    $tile->add_cube( $race->owner_id(), $type, $flag_advanced );

    return;
}

#############################################################################

sub _raw_influence_tile {
    my $self        = shift;
    my $race_tag    = shift;
    my $tile_tag    = shift;

    my $race = $self->races()->{ $race_tag };

    $race->remove_cube( $RES_INFLUENCE );

    $self->tiles()->{ $tile_tag }->set_owner_id( $race->owner_id() );

    return;
}


#############################################################################
#############################################################################
1
