package WLE::4X::Objects::Server;

use strict;
use warnings;

use feature qw( current_sub );

use WLE::Methods::Simple;
use WLE::4X::Enums::Basic;

my %actions = (
    \&_raw_create_game                  => 'create',
    \&_raw_set_status                   => 'status',
    \&_raw_exchange                     => 'exchange',
    \&_raw_add_source                   => 'add_source',
    \&_raw_remove_source                => 'remove_source',
    \&_raw_add_option                   => 'add_option',
    \&_raw_remove_option                => 'remove_option',
    \&_raw_add_player                   => 'add_player',
    \&_raw_remove_player                => 'remove_player',
    \&_raw_begin                        => 'begin',

    \&_raw_set_player_order             => 'set_player_order',
    \&_raw_add_players_to_next_round    => 'queue_next_round',

    \&_raw_create_tile_stack            => 'create_tile_stack',
    \&_raw_remove_tile_from_stack       => 'remove_tile_from_stack',
    \&_raw_empty_tile_discard_stack     => 'empty_tile_discard',
    \&_raw_place_tile_on_board          => 'place_tile_on_board',
    \&_raw_discard_tile                 => 'discard_tile',

    \&_raw_create_development_stack     => 'create_development_stack',

    \&_raw_select_race_and_location     => 'select_race_and_location',
    \&_raw_remove_non_playing_races     => 'remove_non_playing_races',

    \&_raw_remove_from_tech_bag         => 'remove_from_tech_bag',
    \&_raw_add_to_available_tech        => 'add_to_available_tech',
    \&_raw_remove_from_available_tech   => 'remove_from_available_tech',
    \&_raw_next_player                  => 'next_player',
    \&_raw_start_next_round             => 'start_next_round',


    \&_raw_influence_tile               => 'influence_tile',
    \&_raw_remove_influence_from_tile   => 'uninfluence_tile',
    \&_raw_place_cube_on_tile           => 'place_cube_on_tile',
    \&_raw_create_ship_on_tile          => 'create_ship_on_tile',
    \&_raw_add_ship_to_tile             => 'add_ship_to_tile',
    \&_raw_add_discovery_to_tile        => 'add_discovery_to_tile',
    \&_raw_remove_discovery_from_tile   => 'remove_discovery_from_tile',
    \&_raw_add_slot_to_tile             => 'add_slot_to_tile',
    \&_raw_add_ancient_link_to_tile     => 'add_ancient_link_to_tile',
    \&_raw_add_wormhole_to_tile         => 'add_wormhole_to_tile',
    \&_raw_add_vp_to_tile               => 'add_vp_to_tile',

    \&_raw_place_cube_on_track          => 'place_cube_on_track',
    \&_raw_pick_up_influence            => 'pick_up_influence',
    \&_raw_return_influence_to_track    => 'return_influence_to_track',
    \&_raw_use_discovery                => 'use_discovery',

    \&_raw_set_allowed_race_actions     => 'set_allowed_actions',
    \&_raw_increment_race_action        => 'inc_race_action',

    \&_raw_spend_influence              => 'spend_influence',
    \&_raw_use_colony_ship              => 'use_colony_ship',
    \&_raw_add_item_to_hand             => 'add_hand_item',
    \&_raw_remove_item_from_hand        => 'remove_hand_item',
    \&_raw_player_pass_action           => 'player_pass',
    \&_raw_add_to_tech_track            => 'add_to_tech_track',
    \&_raw_buy_technology               => 'buy_technology',
    \&_raw_spend_resource               => 'spend_resource',
    \&_raw_upgrade_ship_component       => 'upgrade_ship',


    \&_raw_start_combat_phase           => 'start_combat_phase',

);

#############################################################################

sub _raw_create_game {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE ) {
        $self->_log_event( __SUB__, @args );
    }

    my $owner_id        = shift( @args );
    my $long_name       = shift( @args );
    my $r_source_tags   = shift( @args );
    my $r_option_tags   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'game created by ' . $owner_id . '. sources used: ' . join( ',', @{ $r_source_tags } ) . '; options used: ' . join( ',', @{ $r_option_tags } );
    }

    $self->{'SETTINGS'}->{'LONG_NAME'} = $long_name;
    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [ @{ $r_source_tags } ];
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [ @{ $r_option_tags } ];
    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [ $owner_id ];

    return;
}

#############################################################################

sub _raw_set_status {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

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

sub _raw_exchange {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $res_from    = shift( @args );
    my $res_to      = shift( @args );
    my $quantity    = shift( @args );

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my ( $cost, $return ) = $race->exchange_rate( $res_from, $res_to );
        return 'exchanged ' . $cost . ' ' . text_from_resource_enum( $res_from ) . ' for ' . $return . ' ' . text_from_resource_enum( $res_to );
    }

    $race->exchange_resources( $res_from, $res_to );

    return;
}

#############################################################################

sub _raw_add_source {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added source: ' . $tag;
    }


    push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_source {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {

        return 'source removed: ' . $tag;
    }

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
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added option: ' . $tag;
    }

    push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_option {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'option removed: ' . $tag;
    }

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
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added player: ' . $player_id;
    }

    push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $player_id );

    return;
}


#############################################################################

sub _raw_remove_player {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'player removed: ' . $player_id;
    }

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
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'game started';
    }

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

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new(
            'server' => $self,
            'tag' => $tech_key,
            'hash' => $VAR1->{'TECHNOLOGY'}->{ $tech_key },
        );

        if ( defined( $technology ) ) {
            if ( $self->item_is_allowed_in_game( $technology ) ) {

                $self->technology()->{ $technology->tag() } = $technology;

                foreach ( 1 .. $technology->count() ) {
                    $self->tech_bag()->add_items( $technology->tag() );
                }
            }
        }
    }

    # vp tokens
    # print STDERR "\n  vp tokens ... ";

    foreach my $value ( 1 .. 4 ) {
        if ( defined( $settings->{'VP_' . $value } ) ) {
            foreach ( 0 .. $settings->{'VP_' . $value } - 1 ) {
                $self->vp_bag()->add_items( $value );
            }
        }
    }

    # discoveries
#    print STDERR "\n  discoveries ... ";

    $self->{'DISCOVERIES'} = {};

    foreach my $disc_key ( keys( %{ $VAR1->{'DISCOVERIES'} } ) ) {

        my $discovery = WLE::4X::Objects::Discovery->new(
            'server' => $self,
            'tag' => $disc_key,
            'hash' => $VAR1->{'DISCOVERIES'}->{ $disc_key },
        );

        if ( defined( $discovery ) ) {
            if ( $self->item_is_allowed_in_game( $discovery ) ) {
                $self->discoveries()->{ $discovery->tag() } = $discovery;

                foreach ( 1 .. $discovery->count() ) {
                    $self->discovery_bag()->add_items( $discovery->tag() );
                }
            }
        }
    }

    # tiles
#    print STDERR "\n  tiles ... ";

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
                $self->{'BOARD'}->add_to_draw_stack( $tile->which_stack(), $tile->tag() );
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
            if ( $self->item_is_allowed_in_game( $development ) ) {
                $self->{'DEVELOPMENTS'}->{ $dev_key } = $development;
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
            if ( $self->item_is_allowed_in_game( $template ) ) {
                $base_templates{ $template->tag() } = $template;
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

            if ( $self->item_is_allowed_in_game( $race ) ) {
                $race->set_flag_passed( 1 );
                $self->{'RACES'}->{ $race->tag() } = $race;
            }
            else {
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

        unless ( matches_any( $ship_template->class(), 'class_interceptor', 'class_cruiser', 'class_dreadnought', 'class_starbase' ) ) {
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
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @new_order_ids   = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'player order set: ' . join( ',', @new_order_ids );
    }


    $self->{'SETTINGS'}->{'PLAYERS_DONE'} = [];
    $self->{'SETTINGS'}->{'PLAYERS_PENDING'} = [ @new_order_ids ];

    return;
}

#############################################################################

sub _raw_add_players_to_next_round {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @player_ids = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'players queued for next round: ' . join( ',', @player_ids );
    }

    my @next_round_player_ids = @{ $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} };
    push( @next_round_player_ids, @player_ids );

    $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} = \@next_round_player_ids;

    return;
}

#############################################################################

sub _raw_start_combat_phase {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'beginning combat phase';
    }

    # TODO start the combat phase

    # get a list of tiles that combat is going to take place in.
    # if there are any then we begin the combat phase in the outermost tile
    # otherwise we skip to the upkeep phase



    $self->{'STATE'} = {
        'STATE' => $ST_NORMAL,
        'ROUND' => $self->round(),
        'PHASE' => $PH_COMBAT,
        'PLAYER' => -1,
        'SUBPHASE' => 0,
    };

    $self->_raw_set_status( $EV_SUB_ACTION, $self->status() );

    return;
}

#############################################################################

sub _raw_create_tile_stack {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $stack_id        = shift( @args );
    my @values          = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tile stack ' . $stack_id . ' created with ' . scalar( @values ) . ' tiles.';
    }

    $self->board()->clear_tile_stack( $stack_id );
    $self->board()->add_to_draw_stack( $stack_id, @values );

    return;
}

#############################################################################

sub _raw_remove_tile_from_stack {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );

    my $stack_id = $self->tiles()->{ $tile_tag }->which_stack();


    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tile ' . $tile_tag . ' removed from stack ' . $stack_id;
    }

    my $stack = $self->board()->tile_draw_stack( $stack_id );

    unless ( defined( $stack ) ) {
        return;
    }

    $stack->remove_item( $tile_tag );

    return;
}

#############################################################################

sub _raw_empty_tile_discard_stack {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $stack_id = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'discard pile for tile stack ' . $stack_id . ' emptied';
    }

    $self->board()->tile_discard_stack( $stack_id )->clear();

    return;
}

#############################################################################

sub _raw_place_tile_on_board {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $location_x      = shift( @args );
    my $location_y      = shift( @args );
    my $warps           = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tile ' . $tile_tag . ' placed on board at location ' . $location_x . ',' . $location_y;
    }

    $self->tiles()->{ $tile_tag }->set_warps( $warps );
    $self->board()->place_tile( $location_x, $location_y, $tile_tag );

    return;
}

#############################################################################

sub _raw_discard_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tile ' . $tile_tag . ' discarded';
    }

    my $stack_id = $self->tiles()->{ $tile_tag }->which_stack();

    my $stack = $self->board()->tile_discard_stack( $stack_id );

    unless ( defined( $stack ) ) {
        return;
    }

    $stack->add_items( $tile_tag );

    return;
}

#############################################################################

sub _raw_create_development_stack {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @values = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'development stack created with ' . scalar( @values ) . ' developments';
    }

    $self->{'DEVELOPMENT_STACK'} = [ @values ];

    return;
}

#############################################################################

sub _raw_select_race_and_location {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag        = shift( @args );
    my $location_x      = shift( @args );
    my $location_y      = shift( @args );
    my $warp_gates      = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'player ' . $self->{'SETTINGS'}->{'PLAYER_IDS'}->[ $self->current_user() ] . ' has selected ' . $race_tag . ' as race and is beginning at location ' . $location_x . ',' . $location_y;
    }


    my $race = $self->races()->{ $race_tag };

    $race->set_owner_id( $self->current_user() );

    unless ( $self->has_option( 'all_races' ) ) {
        my $backing_race = $race->excludes();
        delete ( $self->races()->{ $backing_race } );
    }

    my $start_hex_tag = $race->home_tile();

    my $start_hex = $self->tiles()->{ $start_hex_tag };

    $self->_raw_remove_tile_from_stack( $EV_SUB_ACTION, $start_hex_tag );
    $self->_raw_place_tile_on_board( $EV_SUB_ACTION, $start_hex_tag, $location_x, $location_y, $warp_gates );
    $self->_raw_influence_tile( $EV_SUB_ACTION, $race_tag, $start_hex_tag );


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
                $race->resource_track_of( $type->[ 0 ] )->spend();
                $start_hex->add_cube( $race->owner_id(), $type->[ 0 ], 1 )
            }
        }
    }

    # build and place initial racial ships

    foreach my $ship_class ( $race->starting_ships() ) {

        my $template = $race->template_of_class( $ship_class );

        $self->_raw_create_ship_on_tile(
            $EV_SUB_ACTION,
            $start_hex->tag(),
            $template->tag(),
            $race->owner_id(),
        );
    }

    return;
}

#############################################################################

sub _raw_place_cube_on_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag        = shift( @args );
    my $tile_tag        = shift( @args );
    my $type            = shift( @args );
    my $flag_advanced   = shift( @args ); $flag_advanced = 0             unless defined( $flag_advanced );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( $flag_advanced ) {
            $type = '(adv) ' . $type;
        }
        return $race_tag . ' placed ' . $type . ' cube on tile ' . $tile_tag;
    }

    my $race = $self->races()->{ $race_tag };
    my $tile = $self->tiles()->{ $tile_tag };

    $tile->add_cube( $race->owner_id(), $type, $flag_advanced );

    return;
}

#############################################################################

sub _raw_place_cube_on_track {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag    = shift( @args );
    my $cube_type   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race_tag . ' returned cube to track ' . text_from_resource_enum( $cube_type );
    }

    $self->race_of_current_user()->resource_track_of( $cube_type )->add_to_track();

    return;
}

#############################################################################

sub _raw_influence_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag    = shift( @args );
    my $tile_tag    = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race_tag . ' influenced tile ' . $tile_tag;
    }

    my $race = $self->races()->{ $race_tag };

    $race->resource_track_of( $RES_INFLUENCE )->spend();

    $self->tiles()->{ $tile_tag }->set_owner_id( $race->owner_id() );

    return;
}

#############################################################################

sub _raw_pick_up_influence {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag    = shift( @args );
    my $race        = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' picked up influence from ' . $tile_tag;
    }

    if ( $tile_tag eq 'track' ) {
        $race->resource_track_of( $RES_INFLUENCE )->spend();
    }
    else {
        my $tile = $self->tiles()->{ $tile_tag };
        $tile->set_owner_id( -1 );
        $self->_raw_remove_all_cubes_of_owner( $EV_SUB_ACTION, $tile_tag );
    }

    $race->in_hand()->add_items( 'influence_token' );

    return;
}

#############################################################################

sub _raw_return_influence_to_track {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' returned influence to the resource track';
    }

    $race->in_hand()->remove_item( 'influence_token' );

    $race->resource_track_of( $RES_INFLUENCE )->add_to_track();

    return;
}

#############################################################################

sub _raw_remove_influence_from_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag    = shift( @args );
    my $race        = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' removed influence from tile ' . $tile_tag;
    }

    $self->_raw_pick_up_influence( $EV_SUB_ACTION, $tile_tag );
    $self->_raw_return_influence_to_track( $EV_SUB_ACTION );

    return;
}

#############################################################################

sub _raw_remove_all_cubes_of_owner {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' removed cubes from tile ' . $tile_tag;
    }

    my @cubes = $self->tiles()->{ $tile_tag }->remove_all_cubes_of_owner( $race->owner_id() );

    foreach my $cube_type ( @cubes ) {
        if ( $cube_type == $RES_WILD ) {
            $self->_raw_add_item_to_hand( $EV_SUB_ACTION, 'cube:' . $cube_type );
        }
        else {
            if ( $race->resource_track_of( $cube_type )->available_spaces() > 0 ) {
                $race->resource_track_of( $cube_type )->add_to_track();
            }
            else {
                $self->_raw_add_item_to_hand( $EV_SUB_ACTION, 'cube:' . $RES_WILD );
            }
        }
    }

    return;
}

#############################################################################

sub _raw_set_allowed_race_actions {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag    = shift( @args );
    my @allowed     = @args;

    my $race = $self->races()->{ $race_tag };

    $race->allowed_actions()->clear();
    $race->allowed_actions()->add_items( @allowed );

    return;
}

#############################################################################

sub _raw_remove_non_playing_races {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'removed non-played races and associated resources';
    }

    foreach my $race_tag ( keys( %{ $self->races() } ) ) {
        my $race = $self->races()->{ $race_tag };

        if ( $race->owner_id() eq '' ) {

            foreach my $template_tag ( $race->ship_templates() ) {
                delete ( $self->templates()->{ $template_tag } );
            }

            my $home_tile = $race->home_tile();

            $self->_raw_remove_tile_from_stack( $EV_SUB_ACTION, $home_tile );

            delete ( $self->tiles()->{ $home_tile } );

            delete ( $self->races()->{ $race_tag } );
        }
    }

    return;
}

#############################################################################

sub _raw_create_ship_on_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $template_tag    = shift( @args );
    my $owner_id        = shift( @args );

    my $ship_tag        = $self->new_ship_tag( $template_tag, $owner_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $race_tag = $self->race_tag_of_current_user();
        if ( $race_tag eq '' ) {
            $race_tag = 'game';
        }

        return $race_tag . ' created ship ' . $ship_tag . ' on tile ' . $tile_tag;
    }

    my $template = $self->templates()->{ $template_tag };

    if ( $template->count() > 0 ) {
        $template->set_count( $template->count() - 1 );
    }

    my $ship = WLE::4X::Objects::Ship->new(
        'server'        => $self,
        'template'      => $template,
        'owner_id'      => $owner_id,
        'tag'           => $ship_tag,
    );

    $self->ships()->{ $ship->tag() } = $ship;

    $self->_raw_add_ship_to_tile( $EV_SUB_ACTION, $tile_tag, $ship->tag() );

    return;
}

#############################################################################

sub _raw_add_ship_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $ship_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $race_tag = $self->race_tag_of_current_user();
        if ( $race_tag eq '' ) {
            $race_tag = 'game';
        }

        return $race_tag . ' placed ship ' . $ship_tag . ' on tile ' . $tile_tag;
    }


    my $tile = $self->tiles()->{ $tile_tag };
    $tile->add_ship( $ship_tag );

    return;
}

#############################################################################

sub _raw_add_discovery_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $discovery_tag   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'discovery added to tile ' . $tile_tag;
    }

    $self->tiles()->{ $tile_tag }->add_discovery( $discovery_tag );

    return;
}

#############################################################################

sub _raw_remove_discovery_from_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $discovery_tag   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $discovery_tag . ' removed from tile ' . $tile_tag;
    }

    $self->tiles()->{ $tile_tag }->remove_discovery( $discovery_tag );

    return;
}

#############################################################################

sub _raw_add_slot_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $type            = shift( @args );
    my $flag_advanced   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $adv_text = ( $flag_advanced == 1 ) ? '(adv) ' : '';
        return 'resource slot created on tile : ' . text_from_resource_enum( $type );
    }

    my $slot = WLE::4X::Objects::ResourceSpace->new();
    $slot->set_resource_type( $type );
    $slot->set_is_advanced( $flag_advanced );

    $self->tiles()->{ $tile_tag }->add_slot( $slot );

    return;
}

#############################################################################

sub _raw_add_ancient_link_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'ancient link added to tile : ' . $tile_tag;
    }

    my $tile = $self->tiles()->{ $tile_tag };

    $tile->set_ancient_link( $tile->ancient_links() + 1 );

    return;
}

#############################################################################

sub _raw_add_wormhole_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'wormhole added to tile : ' . $tile_tag;
    }

    $self->tiles()->{ $tile_tag }->set_wormhole( 1 );

    return;
}

#############################################################################

sub _raw_add_vp_to_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag        = shift( @args );
    my $value           = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'vp added to tile : ' . $tile_tag;
    }

    my $tile = $self->tiles()->{ $tile_tag };

    $tile->set_vp( $tile->base_vp() + $value );

    return;
}

#############################################################################

sub _raw_use_discovery {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $discovery_tag   = shift( @args );
    my $tile_tag        = shift( @args );
    my $flag_as_vp      = shift( @args );

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $as_text = ( $flag_as_vp == 1 ) ? 'as 2 vp' : 'for effect';
        return $race->tag() . ' used discovery ' . $as_text;
    }

    if ( $flag_as_vp ) {
        # TODO
        # $race->add_vp_to_category( $VP_DISCOVERIES, 2 );
    }
    else {
        $self->use_discovery( $tile_tag, $discovery_tag );
    }

    $race->in_hand()->remove_item( $tile_tag . ':' . $discovery_tag );

    return;
}

#############################################################################

sub _raw_remove_from_tech_bag {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @removed_tech = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tech tiles removed from bag: ' . join( ',', @removed_tech );
    }

    foreach my $tech_tag ( @removed_tech ) {
        $self->tech_bag()->remove_item( $tech_tag );
    }

    return;

}

#############################################################################

sub _raw_add_to_available_tech {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @new_tech = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tech tiles added to available tech: ' . join( ',', @new_tech );
    }

    $self->available_tech()->add_items( @new_tech );

    return;
}

#############################################################################

sub _raw_remove_from_available_tech {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tech_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'tech tile removed from available tech: ' . $tech_tag;
    }

    $self->available_tech()->remove_item( $tech_tag );

    return;
}

#############################################################################

sub _raw_increment_race_action {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    $race->set_action_count( $self->action_count() + 1 );

    return;
}

#############################################################################

sub _raw_spend_influence {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' spent 1 influence';
    }

    $race->resource_track_of( $RES_INFLUENCE )->spend_but_keep();

    return;
}

#############################################################################

sub _raw_spend_resource {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $resource_type   = shift( @args );
    my $amount          = shift( @args );

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' spent ' . $amount . ' ' . text_from_resouce_enum( $resource_type );;
    }

    $race->add_resource( $resource_type, - $amount );

    return;
}

#############################################################################

sub _raw_upgrade_ship_component {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $template_tag    = shift( @args );
    my $component_tag   = shift( @args );
    my $replaces        = shift( @args );

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( $replaces eq '' ) {
            return $race->tag() . ' upgraded template ' . $template_tag . ' with ' . $component_tag;
        }
        else {
            return $race->tag() . ' upgraded template ' . $template_tag . ' replacing ' . $replaces . ' with ' . $component_tag;
        }
    }

    my $template = $self->ship_templates()->{ $template_tag };

    my $message_holder = '';
    $template->add_component( $component_tag, $replaces, \$message_holder );

    $race->component_overflow()->remove_item( $component_tag );

    return;
}

#############################################################################

sub _raw_use_colony_ship {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag    = shift( @args );
    my $type        = shift( @args );
    my $advanced    = shift( @args );

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $advanced_text = ( $advanced == 1 ) ? ' (adv) ' : '';
        return $race->tag() . ' used colony ship to place an ' . $advanced_text . text_from_resource_enum( $type ) . ' cube on ' . $tile_tag;
    }

    $race->set_colony_ships_used( $race->colony_ships_used() + 1 );

    $race->track_tag( $type )->spend();

    $self->_raw_place_cube_on_tile( $race->tag(), $tile_tag, $type, $advanced );

    return;
}

#############################################################################

sub _raw_unuse_colony_ship {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' flipped a colony ship';
    }

    $race->set_colony_ships_used( $race->colony_ships_used() - 1 );

    return;
}

#############################################################################

sub _raw_add_item_to_hand {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();
    my $item = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added to hand: ' . $item;
    }

    $race->in_hand()->add_items( $item );

    return;
}

#############################################################################

sub _raw_remove_item_from_hand {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();
    my $item = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'removed from hand: ' . $item;
    }

    $race->in_hand()->remove_item( $item );

    return;
}

#############################################################################

sub _raw_buy_technology {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tech_tag = shift( @args );
    my $track_type = shift( @args );

    my $race = $self->race_of_current_user();
    my $tech = $self->technologies()->{ $tech_tag };

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' researched ' . $tech_tag;
    }

    my $cost = $self->technologies()->base_cost();
    my $credit = $race->tech_track_of( $track_type )->current_credit();

    $cost -= $credit;
    if ( $cost < $tech->min_cost() ) {
        $cost = $tech->min_cost();
    }

    $race->add_resource( $RES_SCIENCE, - $cost );

    $self->_raw_remove_from_available_tech( $EV_SUB_ACTION, $tech_tag );
    $self->_raw_add_to_tech_track( $EV_SUB_ACTION, $tech_tag, $track_type );

    return;
}

#############################################################################

sub _raw_add_to_tech_track {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    my $tech_tag = shift( @args );
    my $track_type = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' added ' . $tech_tag . ' to tech track ' . text_from_tech_enum( $track_type );
    }

    $race->tech_track_of( $track_type )->add_techs( $tech_tag );

    return;
}

#############################################################################

sub _raw_player_pass_action {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race = $self->race_of_current_user();

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race->tag() . ' passed';
    }

    $race->set_flag_passed( 1 );

    return;
}

#############################################################################

sub _raw_next_player {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'next player';
    }

    my $race = $self->race_of_current_user();
    if ( defined( $race ) ) {
        $race->end_turn();
    }

    my $done_player = shift( @{ $self->{'SETTINGS'}->{'PLAYERS_PENDING'} } );

    push( @{ $self->{'SETTINGS'}->{'PLAYERS_DONE'} }, $done_player );

    if ( scalar( @{ $self->{'SETTINGS'}->{'PLAYERS_PENDING'} } ) > 0 ) {

        my $current_player = $self->{'SETTINGS'}->{'PLAYERS_PENDING'}->[ 0 ];

        $race = $self->race_of_player_id( $current_player );
        if ( defined( $race ) ) {
            $race->start_turn();
        }

        $self->{'STATE'}->{'PLAYER'} = $current_player;
        return;
    }

    foreach my $race ( values( %{ $self->races() } ) ) {
        unless ( $race->has_passed() ) {
            @{ $self->{'SETTINGS'}->{'PLAYERS_PENDING'} } = @{ $self->{'SETTINGS'}->{'PLAYERS_DONE'} };
            $self->{'SETTINGS'}->{'PLAYERS_DONE'} = [];
            return;
        }
    }

    return;
}

#############################################################################

sub _raw_start_next_round {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'starting new round';
    }

    my @ready = @{ $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} };
    $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} = [];
    $self->{'SETTINGS'}->{'PLAYERS_DONE'} = [];

    $self->{'SETTINGS'}->{'PLAYERS_PENDING'} = \@ready;

    my $new_round = $self->{'STATE'}->{'ROUND'} + 1;
    my $current_player = $self->{'SETTINGS'}->{'PLAYERS_PENDING'}->[ 0 ];

    my $race = $self->race_of_player_id( $current_player );
    $race->start_turn();

    $self->{'STATE'} = {
        'STATE' => $ST_NORMAL,
        'ROUND' => $new_round,
        'PHASE' => $PH_ACTION,
        'PLAYER' => $current_player,
        'SUBPHASE' => 0,
    };

    $self->_raw_set_status( $EV_SUB_ACTION, $self->status() );

    return;
}

#############################################################################

sub _log_event {
    my $self            = shift;
    my $event_type      = shift;
    my $ref_to_method   = shift;
    my @args            = @_;

    $Data::Dumper::Indent = 0;

    if ( $event_type == $EV_FROM_INTERFACE ) {
        $self->_log_data( $actions{ $ref_to_method } . ':' . Dumper( \@args ) );
    }
    elsif ( $event_type == $EV_SUB_ACTION ) {
        $self->_log_data( '  _' . $actions{ $ref_to_method } . ':' . Dumper( \@args ) );
    }

    return;
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
                $method->( $self, $EV_FROM_LOG, $data );
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
