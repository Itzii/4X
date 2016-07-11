package WLE::4X::Objects::Server;

use strict;
use warnings;

use feature qw( current_sub );

use WLE::4X::Enums::Basic;

my %actions = (
    \&_raw_create_game                  => 'create',
    \&_raw_set_status                   => 'status',
    \&_raw_add_source                   => 'add_source',
    \&_raw_remove_source                => 'remove_source',
    \&_raw_add_option                   => 'add_option',
    \&_raw_remove_option                => 'remove_option',
    \&_raw_add_player                   => 'add_player',
    \&_raw_remove_player                => 'remove_player',
    \&_raw_begin                        => 'begin',
    \&_raw_set_player_order             => 'set_player_order',
    \&_raw_create_tile_stack            => 'create_tile_stack',
    \&_raw_remove_tile_from_stack       => 'remove_tile_from_stack',
    \&_raw_place_tile_on_board          => 'place_tile_on_board',
    \&_raw_discard_tile                 => 'discard_tile',
    \&_raw_create_development_stack     => 'create_development_stack',
    \&_raw_select_race_and_location     => 'select_race_and_location',
    \&_raw_place_cube_on_tile           => 'place_cube_on_tile',
    \&_raw_influence_tile               => 'influence_tile',
    \&_raw_remove_non_playing_races     => 'remove_non_playing_races',
    \&_raw_create_ship_on_tile          => 'create_ship_on_tile',
    \&_raw_add_discovery_to_tile        => 'add_discovery_to_tile',
    \&_raw_remove_discovery_from_tile   => 'remove_discovery_from_tile',
    \&_raw_remove_from_tech_bag         => 'remove_from_tech_bag',
    \&_raw_add_to_available_tech        => 'add_to_available_tech',


);

#############################################################################

sub _raw_create_game {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $owner_id        = shift( @args );
    my $long_name       = shift( @args );
    my $r_source_tags   = shift( @args );
    my $r_option_tags   = shift( @args );

    $self->{'SETTINGS'}->{'LONG_NAME'} = $long_name;
    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [ @{ $r_source_tags } ];
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [ @{ $r_option_tags } ];
    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [ $owner_id ];

    return;
}

#############################################################################

sub _raw_set_status {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $status = shift( @args );

    my @values = split( /:/, $status );

    $self->{'STATE'}->{'STATE'} = $values[ 0 ];
    $self->{'STATE'}->{'ROUND'} = $values[ 1 ];
    $self->{'STATE'}->{'PHASE'} = $values[ 2 ];
    $self->{'STATE'}->{'PLAYER'} = $values[ 3 ];
    $self->{'STATE'}->{'SUBPHASE'} = $values[ 4 ];

    return;
}

#############################################################################

sub _raw_add_source {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tag         = shift( @args );

    push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_source {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tag         = shift( @args );

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

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tag         = shift( @args );

    push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_option {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tag         = shift( @args );

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

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $player_id   = shift( @args );

    push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $player_id );

    return;
}


#############################################################################

sub _raw_remove_player {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $player_id   = shift( @args );

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

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $fh = undef;

#    print STDERR "\nraw_begin ... ";

    unless ( open( $fh, '<', $self->_file_resources() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_file_resources() );
        print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    flock( $fh, LOCK_SH );

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
    $self->{'START_TECH_COUNT'} = $settings->{'START_TECH_COUNT'};

    if ( $self->has_option( 'ancient_homeworlds') ) {
        $self->{'STARTING_LOCATIONS'} = $settings->{'POSITIONS_W_NPC'};
    }
    else {
        $self->{'STARTING_LOCATIONS'} = $settings->{'POSITIONS'};
    }

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
            if ( $self->item_is_allowed_in_game( $component ) ) {
                $self->{'COMPONENTS'}->{ $component_key } = $component;
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
            if ( $self->item_is_allowed_in_game( $technology ) ) {

                $self->{'TECHNOLOGY'}->{ $technology->tag() } = $technology;

                foreach ( 1 .. $technology->count() ) {
                    push( @tech_bag, $technology->tag() );
                }
            }
        }
    }

    $self->{'TECH_BAG'} = \@tech_bag;

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
            if ( $self->item_is_allowed_in_game( $discovery ) ) {
                $self->{'DISCOVERIES'}->{ $discovery->tag() } = $discovery;

                foreach ( 1 .. $discovery->count() ) {
                    push( @discovery_bag, $discovery->tag() );
                }
            }
        }
    }

    $self->{'DISCOVERY_BAG'} = \@discovery_bag;

    # tiles
#    print STDERR "\n  tiles ... ";

    $self->{'TILE_STACKS'} = {
        '1'                     => [],
        '2'                     => [],
        '3'                     => [],
        'homeworlds'            => [],
        'ancient_homeworlds'    => [],
    };

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
            if ( $self->item_is_allowed_in_game( $tile ) ) {
                $self->{'TILES'}->{ $tile->tag() } = $tile;
                push( @{ $self->{'TILE_STACKS'}->{ $tile->which_stack() } }, $tile->tag() );
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

    my %base_templates = ();

    foreach my $template_key ( keys( %{ $VAR1->{'SHIP_TEMPLATES'} } ) ) {

#        print STDERR Dumper( $VAR1->{'SHIP_TEMPLATES'}->{ $template_key } );
#        print STDERR "\n  creating template for key " . $template_key;


        my $template = WLE::4X::Objects::ShipTemplate->new(
            'server' => $self,
            'tag' => $template_key,
            'hash' => $VAR1->{'SHIP_TEMPLATES'}->{ $template_key },
        );

        if ( defined( $template ) ) {
            if ( matches_any( $template->source_tag(), $self->source_tags() ) ) {
                if (
                    $template->required_option() eq ''
                    || matches_any( $template->required_option(), $self->option_tags() )
                ) {
                    $base_templates{ $template->tag() } = $template;
                }
            }
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
            'base_templates' => \%base_templates,
        );

#        print STDERR "\nRace: " . $race->tag();

        if ( defined( $race ) ) {

            my $flag_added_race = 0;

            my %race_hash = ();
            $race->to_hash( \%race_hash );
#            print STDERR "\n" . Dumper( \%race_hash );

            if ( matches_any( $race->source_tag(), $self->source_tags() ) ) {
                if (
                    $race->required_option() eq ''
                    || matches_any( $race->required_option(), $self->option_tags() )
                ) {
                    $self->{'RACES'}->{ $race->tag() } = $race;
                    $flag_added_race = 1;
                }
                else {

                }
            }

            unless ( $flag_added_race ) {
                foreach my $template_tag ( $race->ship_templates() ) {
                    delete ( $self->templates()->{ $template_tag } );
                }
            }
        }
    }

    # other ship templates
#    print STDERR "\n  other ship templates ... ";

    foreach my $template_key ( keys( %base_templates ) ) {

        my $ship_template = $base_templates{ $template_key };

        unless ( WLE::Methods::Simple::matches_any( $ship_template->class(), 'class_interceptor', 'class_cruiser', 'class_dreadnought', 'class_starbase' ) ) {
            $ship_template->set_owner_id( -1 );
            $self->templates()->{ $template_key } = $ship_template;

            my $tag = 'ship_' . $template_key;

            my $ship = WLE::4X::Objects::Ship->new(
                'server' => $self,
                'template' => $ship_template,
                'owner_id' => -1,
                'tag' => $tag,
            );

            $self->ship_pool()->{ $tag } = $ship;
        }
    }

    return;
}

#############################################################################

sub _raw_set_player_order {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my @new_order_ids   = @args;

    $self->{'SETTINGS'}->{'PLAYERS_DONE'} = [];
    $self->{'SETTINGS'}->{'PLAYERS_PENDING'} = [ @new_order_ids ];

    return;
}

#############################################################################

sub _raw_create_tile_stack {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $stack_id        = shift( @args );
    my @values          = @args;

    $self->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} = [ @values ];
    $self->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} = [];

    return;
}

#############################################################################

sub _raw_remove_tile_from_stack {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );

    my $stack_id = $self->tiles()->{ $tile_tag }->which_stack();

    my @new_stack = ();

    foreach my $current_tag ( @{ $self->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} } ) {
        unless ( $current_tag eq $tile_tag ) {
            push( @new_stack, $current_tag );
        }
    }

    $self->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} = \@new_stack;

    return;
}

#############################################################################

sub _raw_place_tile_on_board {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );
    my $location_x      = shift( @args );
    my $location_y      = shift( @args );

    $self->board()->place_tile( $location_x, $location_y, $tile_tag );

    return;
}

#############################################################################

sub _raw_discard_tile {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );

    my $stack_id = $self->tiles()->{ $tile_tag }->which_stack();

    push( @{ $self->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} }, $tile_tag );

    return;
}


#############################################################################

sub _raw_create_development_stack {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my @values          = @args;

    $self->{'DEVELOPMENT_STACK'} = [ @values ];

    return;
}

#############################################################################

sub _raw_select_race_and_location {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $race_tag        = shift( @args );
    my $location_x      = shift( @args );
    my $location_y      = shift( @args );
    my $warp_gates      = shift( @args );

    my $race = $self->races()->{ $race_tag };

    $race->set_owner_id( $self->current_user() );

    unless ( $self->has_option( 'all_races' ) ) {
        my $backing_race = $race->excludes();
        delete ( $self->races()->{ $backing_race } );
    }

    my $start_hex_tag = $race->home_tile();

    my $start_hex = $self->tiles()->{ $start_hex_tag };

    $start_hex->set_warps( $warp_gates );

    $self->_raw_remove_tile_from_stack( 0, $start_hex_tag );
    $self->_raw_place_tile_on_board( 0, $start_hex_tag, $location_x, $location_y );
    $self->_raw_influence_tile( 0, $race_tag, $start_hex_tag );


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
#            print STDERR "\nPlacing Ship: " . $ship->tag();
            $start_hex->add_ship( $ship->tag() );
        }
    }

    return;
}

#############################################################################

sub _raw_place_cube_on_tile {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $race_tag        = shift( @args );
    my $tile_tag        = shift( @args );
    my $type            = shift( @args );
    my $flag_advanced   = shift( @args ); $flag_advanced = 0             unless defined( $flag_advanced );

    my $race = $self->races()->{ $race_tag };
    my $tile = $self->tiles()->{ $tile_tag };

    $tile->add_cube( $race->owner_id(), $type, $flag_advanced );

    return;
}

#############################################################################

sub _raw_influence_tile {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $race_tag    = shift( @args );
    my $tile_tag    = shift( @args );

    my $race = $self->races()->{ $race_tag };

    $race->remove_cube( $RES_INFLUENCE );

    $self->tiles()->{ $tile_tag }->set_owner_id( $race->owner_id() );

    return;
}

#############################################################################

sub _raw_remove_non_playing_races {
    my $self        = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    foreach my $race_tag ( keys( %{ $self->races() } ) ) {
        my $race = $self->races()->{ $race_tag };

        if ( $race->owner_id() eq '' ) {

            foreach my $template_tag ( $race->ship_templates() ) {
                delete ( $self->templates()->{ $template_tag } );
            }

            my $home_tile = $race->home_tile();
            $self->_raw_remove_tile_from_stack( 0, $home_tile );

            delete ( $self->tiles()->{ $home_tile } );

            delete ( $self->races()->{ $race_tag } );
        }
    }

    return;
}

#############################################################################

sub _raw_create_ship_on_tile {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );
    my $template_tag    = shift( @args );
    my $owner_id        = shift( @args );
    my $ship_tag        = shift( @args );

    my $template = $self->templates()->{ $template_tag };

    my $ship = WLE::4X::Objects::Ship->new(
        'server'        => $self,
        'template'      => $template,
        'owner_id'      => $owner_id,
        'tag'           => $ship_tag,
    );

    $self->ships()->{ $ship->tag() } = $ship;

    my $tile = $self->tiles()->{ $tile_tag };
    $tile->add_ship( $ship->tag() );

    return;
}

#############################################################################

sub _raw_add_discovery_to_tile {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );
    my $discovery_tag   = shift( @args );

    $self->tiles()->{ $tile_tag }->add_discovery( $discovery_tag );

    return;
}

#############################################################################

sub _raw_remove_discovery_from_tile {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my $tile_tag        = shift( @args );
    my $discovery_tag   = shift( @args );

    $self->tiles()->{ $tile_tag }->remove_discovery( $discovery_tag );

    return;
}

#############################################################################

sub _raw_remove_from_tech_bag {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my @removed_tech = @args;

    foreach my $tech_tag ( @removed_tech ) {

        my @holder = ();

        foreach my $old_tech ( @{ $self->{'TECH_BAG'} } ) {
            if ( $old_tech eq $tech_tag ) {
                $tech_tag = '';
            }
            else {
                push( @holder, $old_tech );
            }
        }

        $self->{'TECH_BAG'} = \@holder;
    }

    return;

}

#############################################################################

sub _raw_add_to_available_tech {
    my $self            = shift;

    my @args = $self->_log_if_needed( shift( @_ ), __SUB__, @_ );

    my @new_tech = @args;

    push( @{ $self->{'AVAILABLE_TECH'} }, @new_tech );

    return;
}


#############################################################################

sub _log_if_needed {
    my $self            = shift;
    my $event_type      = shift;
    my $ref_to_method   = shift;
    my @args            = @_;

    unless ( $event_type == $EV_FROM_INTERFACE ) {
        return @args;
    }

    $Data::Dumper::Indent = 0;
    $self->_log_data( $actions{ $ref_to_method } . ':' . Dumper( \@args ) );

    return @args;
}

#############################################################################
#
# action_parse_state_from_log - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
#

sub action_parse_state_from_log {
    my $self        = shift;
    my %args        = @_;

    $self->set_error( '' );

    unless ( $self->set_log_id( $args{'log_id'} ) ) {
        $self->set_error( 'Invalid Log ID: ' . $args{'log_id'} );
        return 0;
    }

    my $fh_state;
    my $fh_log;

    unless ( open( $fh_state, '>', $self->_state_file() ) ) {
        $self->set_error( 'Failed to write state file: ' . $self->_state_file() );
        return 0;
    }

    unless( flock( $fh_state, LOCK_EX ) ) {
        $self->set_error( 'Failed to lock state file: ' . $self->_state_file() );
        return 0;
    }

    unless ( open( $fh_log, '<', $self->_log_file() ) ) {
        $self->set_error( 'Unable to open log file: ' . $self->_log_file() );
        return 0;
    }

    flock( $fh_log, LOCK_SH );

    $self->{'DATA'}->{'LONG_NAME'} = <$fh_log>;

    $self->{'DATA'}->{'SOURCE_TAGS'} = split( /,/, <$fh_log> );

    if ( scalar( @{ $self->{'DATA'}->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Missing source tags' );
        return 0;
    }

    $self->{'DATA'}->{'OPTION_TAGS'} = split( /,/, <$fh_log> );

    my $line = <$fh_log>;

    while ( defined( $line ) ) {

        my ( $action, $data ) = split( /:/, $line, 2 );
        my $VAR1;

        eval $data; warn $@ if $@;

        my $flag_found_method = 0;

        foreach my $method ( keys( %actions ) ) {
            if ( $actions{ $method } eq $action ) {
                $flag_found_method = 1;
                $method->( $self, 0, $data );
                last;
            }
        }

        unless ( $flag_found_method ) {
            $self->set_error( 'Invalid Action In Log: ' . $action );
        }

        $line = <$fh_log>;
    }

    # using Data::Dumper

    print $fh_state Dumper( $self->{'DATA'} );

    # using Storable

#    store_fd( $self->{'DATA'}, $fh_state );

    close( $fh_state );

    close( $fh_log );

    return 1;
}

#############################################################################
#############################################################################
1
