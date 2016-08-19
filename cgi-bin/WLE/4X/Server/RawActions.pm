package WLE::4X::Server::Server;

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
    \&_raw_prepare_for_first_round      => 'prepare_first_round',

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
    \&_raw_remove_ship_from_tile        => 'remove_ship_from_tile',
    \&_raw_add_discovery_to_tile        => 'add_discovery_to_tile',
    \&_raw_remove_discovery_from_tile   => 'remove_discovery_from_tile',
    \&_raw_add_slot_to_tile             => 'add_slot_to_tile',
    \&_raw_add_ancient_link_to_tile     => 'add_ancient_link_to_tile',
    \&_raw_add_wormhole_to_tile         => 'add_wormhole_to_tile',
    \&_raw_add_vp_to_tile               => 'add_vp_to_tile',
    \&_raw_add_tile_discoveries_to_hand => 'add_discovery_to_hand',

    \&_raw_place_cube_on_track          => 'place_cube_on_track',
    \&_raw_pick_up_influence            => 'pick_up_influence',
    \&_raw_return_influence_to_track    => 'return_influence_to_track',
    \&_raw_use_discovery                => 'use_discovery',

    \&_raw_set_allowed_player_actions   => 'set_allowed_actions',
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

    \&_raw_set_pending_player           => 'set_pending_player',
    \&_raw_start_combat_phase           => 'start_combat_phase',
    \&_raw_begin_combat_in_tile         => 'begin_combat_in_tile',
    \&_raw_prepare_to_retreat_ships     => 'set_ships_as_retreating',
    \&_raw_make_attack_rolls            => 'make_attack_rolls',
    \&_raw_set_defense_hits             => 'set_defense_hits',
    \&_raw_destroy_ship                 => 'destroy_ship',
    \&_raw_allocate_hits                => 'allocate_hits',
    \&_raw_apply_combat_hits            => 'apply_combat_hits',
    \&_raw_next_combat_ships            => 'next_set_of_ships',
    \&_raw_begin_attacking_population   => 'attack_population',
    \&_raw_dont_kill_population         => 'dont_kill_population',
    \&_raw_allocate_population_hits     => 'allocate_population_hits',
    \&_raw_kill_population_cube         => 'kill_population',
    \&_raw_add_vp_to_hand               => 'add_vp_to_hand',
    \&_raw_start_vp_draws               => 'start_vp_draws',
    \&_raw_select_vp_token              => 'select_vp_token',
    \&_raw_next_vp_draw_player          => 'next_vp_draw',

    \&_raw_start_upkeep                 => 'start_upkeep',

    \&_raw_swap_back_ambassadors        => 'swap_back_ambassadors',


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

    $self->set_waiting_on_player_id( 0 );
    $self->set_subphase( $SUB_NULL );

    $self->set_long_name( $long_name );
    $self->source_tags()->fill( @{ $r_source_tags } );
    $self->option_tags()->fill( @{ $r_option_tags } );

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
    push( @values, '' );

    $self->set_state( $values[ 0 ] );
    $self->set_round( $values[ 1 ] );
    $self->set_phase( $values[ 2 ] );
    $self->set_waiting_on_player_id( $values[ 3 ] );
    $self->set_subphase( $values[ 4 ] );
    $self->set_current_tile( $values[ 5 ] );

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

    my $player_id   = shift( @args );
    my $res_from    = shift( @args );
    my $res_to      = shift( @args );
    my $quantity    = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my ( $cost, $return ) = $player->race()->exchange_rate( $res_from, $res_to );
        return 'exchanged ' . $cost . ' ' . text_from_resource_enum( $res_from ) . ' for ' . $return . ' ' . text_from_resource_enum( $res_to );
    }

    $player->race()->exchange_resources( $res_from, $res_to );

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

    $self->source_tags()->add_items( $tag );


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

    $self->source_tags()->remove_item( $tag );

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

    $self->option_tags()->add_items( $tag );

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

    $self->option_tags()->remove_item( $tag );

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

    my $user_id   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added player: ' . $user_id;
    }

    my $new_player = WLE::4X::Objects::Player->new( 'server' => $self, 'user_id' => $user_id );
    $self->add_player( $new_player );

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

    my $user_id   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'player removed: ' . $user_id;
    }

    $self->remove_player( $user_id );

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
        print STDERR $self->last_error();
        return 0;
    }

    flock( $fh, LOCK_SH );

    $self->reset( 0 );

#    print STDERR "\nparsing ... ";

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    # settings
#    print STDERR "\n  settings ... ";

    unless ( defined( $VAR1->{'PLAYER_COUNT_SETTINGS'} ) ) {
        $self->set_error( 'Missing Section in resource file: PLAYER_COUNT_SETTINGS' );
        print STDERR $self->last_error();
        return 0;
    }

    my $settings = $VAR1->{'PLAYER_COUNT_SETTINGS'}->{ scalar( $self->player_list() ) };
#    print STDERR "\nPlayer Count: " . scalar( $self->players_list() );

    unless ( defined( $settings ) ) {
        $self->set_error( 'Invalid Player Count: ' . scalar( $self->player_list() ) );
        print STDERR $self->last_error();
        return 0;
    }

    unless ( $self->source_tags()->contains( $settings->{'SOURCE_TAG'} ) ) {
        $self->set_error( 'Invalid player count for chosen sources: ' . scalar( $self->player_list() ) );
        print STDERR $self->last_error();
        return 0;
    }

    $self->set_tech_draw_count( $settings->{'ROUND_TECH_COUNT'} );
    $self->set_start_tech_count( $settings->{'START_TECH_COUNT'} );

    if ( $self->option_tags()->contains( 'ancient_homeworlds') ) {
        $self->starting_locations()->fill( @{ $settings->{'POSITIONS_W_NPC'} } );
    }
    else {
        $self->starting_locations()->fill( @{ $settings->{'POSITIONS'} } );
    }

    # setup ship component tiles
#    print STDERR "\n  ship components ... ";

    unless ( defined( $VAR1->{'COMPONENTS'} ) ) {
        $self->set_error( 'Missing Section in resource file: COMPONENTS' );
        return 0;
    }

#    print STDERR " found the section ... ";

    foreach my $component_key ( keys( %{ $VAR1->{'COMPONENTS'} } ) ) {
        my $component = WLE::4X::Objects::ShipComponent->new(
            'server' => $self,
            'tag' => $component_key,
            'hash' => $VAR1->{'COMPONENTS'}->{ $component_key },
        );

        if ( defined( $component ) ) {
            if ( $self->item_is_allowed_in_game( $component ) ) {
                $self->ship_components()->{ $component_key } = $component;
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

    foreach my $tile_key ( keys( %{ $VAR1->{'TILES'} } ) ) {

        my $tile = WLE::4X::Objects::Tile->new(
            'server' => $self,
            'tag' => $tile_key,
            'hash' => $VAR1->{'TILES'}->{ $tile_key },
        );

#        print STDERR "\n   " . $tile_key;

        if ( defined( $tile ) ) {
            if ( $self->item_is_allowed_in_game( $tile ) ) {

#                print STDERR ' added ' . $tile->tag();

                $self->tiles()->{ $tile->tag() } = $tile;
                $self->board()->add_to_draw_stack( $tile->which_stack(), $tile->tag() );
            }
        }
    }

    foreach my $count ( 1 .. 3 ) {
        if ( defined( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
            if ( looks_like_number( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
                $self->board()->set_tile_stack_limit( $settings->{'SECTOR_LIMIT_' . $count } );
            }
        }
    }


    # developments
#    print STDERR "\n  developments ... ";

    $self->set_development_limit( -1 );
    if ( looks_like_number( $settings->{'DEVELOPMENTS'} ) ) {
        $self->set_development_limit( $settings->{'DEVELOPMENTS'} )
    }

    foreach my $dev_key ( keys( %{ $VAR1->{'DEVELOPMENTS'} } ) ) {

        my $development = WLE::4X::Objects::Development->new(
            'server' => $self,
            'tag' => $dev_key,
            'hash' => $VAR1->{'DEVELOPMENTS'}->{ $dev_key },
        );

        if ( defined( $development ) ) {
            if ( $self->item_is_allowed_in_game( $development ) ) {
                $self->developments()->{ $dev_key } = $development;
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
#                print STDERR " added template.";
                $base_templates{ $template->tag() } = $template;
            }
        }
    }


    # races
#    print STDERR "\n  races ... ";

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
                $self->races()->{ $race->tag() } = $race;
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

            foreach ( 1 .. $ship_template->count() ) {
                my $tag = $self->new_ship_tag( $template_key, -1 );

                my $ship = WLE::4X::Objects::Ship->new(
                    'server' => $self,
                    'template' => $ship_template,
                    'owner_id' => -1,
                    'tag' => $tag,
                );

                $self->ship_pool()->{ $tag } = $ship;
            }
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

    $self->set_new_player_order( @new_order_ids );

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

    $self->players_next_round()->add_items( @player_ids );

    return;
}

#############################################################################

sub _raw_set_pending_player {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $pending_id = shift( @args );

    my $race = $self->race_of_player_id( $pending_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( defined( $race ) ) {
            return 'now waiting on ' . $race->tag();
        }
        else {
            return 'now waiting on no one.';
        }
    }

    $self->set_waiting_on_player_id( $pending_id );

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

    my $outermost_combat_tile = $self->board()->outermost_combat_tile();

    $self->_raw_begin_combat_in_tile( $EV_SUB_ACTION, $outermost_combat_tile, 1 );

    return;
}
#############################################################################

sub _raw_begin_combat_in_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $flag_first_in_tile = shift( @args );

    my $tile = $self->tiles()->{ $tile_tag };

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    my $defender_race = 'ancients';

    if ( $defender_id > -1 ) {
        $defender_race = $self->race_of_player_id( $defender_id )->tag();
    }

    my $attacker_race = $self->race_of_player_id( $attacker_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $attacker_race . ' attacks ' . $defender_race . ' in ' . $tile_tag;
    }

    $self->start_combat_in_tile( $tile_tag, $flag_first_in_tile );

    return;
}

#############################################################################

sub _raw_make_attack_rolls {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @rolls = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'combat rolls are made: ' . join( ',', @rolls );
    }

    $self->combat_rolls()->clear();
    $self->combat_rolls()->add_items( @rolls );

    return;
}

#############################################################################

sub _raw_set_defense_hits {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $hit_count = shift( @args );
    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $hit_count . ' missile defense rolls succeeded.';
    }

    $self->set_missile_defense_hits( $hit_count );

    return;
}

#############################################################################

sub _raw_destroy_ship {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $ship_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $ship_tag . ' is destroyed';
    }

    $self->_raw_remove_ship_from_tile( $EV_SUB_ACTION, $tile_tag, $ship_tag );

    my $template = $self->templates()->{ $ship_tag };
    $template->set_count( $template->count() + 1 );

    delete( $self->ships()->{ $ship_tag } );

    return;
}

#############################################################################

sub _raw_allocate_hits {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @hits = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'combat rolls are allocated: ' . join( ',', @hits );
    }

    $self->combat_rolls()->clear();
    $self->combat_rolls()->add_items( @hits );

    return;
}

#############################################################################

sub _raw_apply_combat_hits {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'combat damage is being applied';
    }

    $self->apply_combat_hits();

    return;
}

#############################################################################

sub _raw_next_combat_ships {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'moving to next set of ship initiatives';
    }

    $self->next_combat_ships();

    return;
}

#############################################################################

sub _raw_prepare_to_retreat_ships {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id = shift( @args );
    my $tile_tag = shift( @args );
    my $template_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' begins retreating ships of type ' . $template_tag;
    }

    $self->tag_ships_to_retreat( $tile_tag, $template_tag );

    return;
}

#############################################################################

sub _raw_begin_attacking_population {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id = shift( @args );
    my $tile_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' begins attacking population in ' . $tile_tag;
    }

    $self->attack_population( $tile_tag );

    return;
}

#############################################################################

sub _raw_dont_kill_population {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' refrains from attacking population in ' . $self->current_tile();
    }

    $self->next_population_attacker();

    return;
}

#############################################################################

sub _raw_allocate_population_hits {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my @hits = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'combat rolls are allocated: ' . join( ',', @hits );
    }

    $self->combat_rolls()->clear();
    $self->combat_rolls()->add_items( @hits );

    return;
}

#############################################################################

sub _raw_kill_population {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id = shift( @args );
    my @cubes_to_kill = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' kills population in ' . $self->current_tile() . ': ' . join( ',', @cubes_to_kill );
    }

    $self->kill_population( @cubes_to_kill );

    return;
}

#############################################################################

sub _raw_kill_population_cube {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $type = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'population in ' . $tile_tag . ' of type ' . $type . ' is killed';
    }

    $self->kill_population_cube( $tile_tag, $type );

    return;
}

#############################################################################

sub _raw_start_vp_draws {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'vp draws beginning in ' . $tile_tag;
    }

    $self->start_vp_draws( $tile_tag );

    return;
}

#############################################################################

sub _raw_add_vp_to_hand {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id = shift( @args );
    my @vp_tokens = @args;

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'vp tokens added to ' . $player_id . ' hand';
    }

    foreach my $token ( @vp_tokens ) {
        $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player_id, $token );
        $self->vp_bag()->remove_item( $token );
    }

    $self->_raw_set_allowed_player_actions( $EV_SUB_ACTION, $player_id, 'select_vp_token' );

    return;
}

#############################################################################

sub _raw_select_vp_token {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag = shift( @args );
    my $new_token = shift( @args );
    my $old_token = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( $old_token eq '' ) {
            return $race_tag . ' adds vp token to set: ' . $new_token;
        }
        else {
            return $race_tag . ' replaces ' . $old_token . ' with new token: ' . $new_token;
        }
    }

    my $race = $self->races()->{ $race_tag };
    $race->add_vp_item( $new_token, $old_token );

    unless ( $old_token eq '' ) {
        if ( looks_like_number( $old_token ) ) {
            $self->server()->vp_bag()->add_items( $old_token );
        }
    }

    $self->server()->vp_bag()->add_items( $race->in_hand()->items() );
    $race->in_hand()->clear();

    return;
}

#############################################################################

sub _raw_next_vp_draw_player {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'next vp draw in ' . $tile_tag;
    }

    $self->next_vp_draw( $tile_tag );

    return;
}

#############################################################################

sub _raw_swap_back_ambassadors {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $race_tag = shift( @args );
    my $other_race_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $race_tag . ' and ' . $other_race_tag . ' swap back ambassadors';
    }

    $self->races()->{ $other_race_tag }->remove_vp_item( $race_tag );
    $self->races()->{ $other_race_tag }->in_hand()->add_items( 'cube:' . $RES_WILD );

    $self->races()->{ $race_tag }->remove_vp_item( $other_race_tag );
    $self->races()->{ $race_tag }->in_hand()->add_items( 'cube:' . $RES_WILD );

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

    $self->tiles()->{ $tile_tag }->add_starting_ships();



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

    $self->development_stack()->fill( @values );

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

    my $player_id       = shift( @args );
    my $race_tag        = shift( @args );
    my $location_x      = shift( @args );
    my $location_y      = shift( @args );
    my $warp_gates      = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'player ' . $player_id . ' has selected ' . $race_tag . ' as race and is beginning at location ' . $location_x . ',' . $location_y;
    }

    $player->set_race_tag( $race_tag );

    unless ( $self->has_option( 'all_races' ) ) {
        my $backing_race = $player->race()->excludes();
        delete ( $self->races()->{ $backing_race } );
    }

    my $start_hex_tag = $player->race()->home_tile();

    my $start_hex = $self->tiles()->{ $start_hex_tag };

    $self->_raw_remove_tile_from_stack( $EV_SUB_ACTION, $start_hex_tag );
    $self->_raw_place_tile_on_board( $EV_SUB_ACTION, $start_hex_tag, $location_x, $location_y, $warp_gates );
    $self->_raw_influence_tile( $EV_SUB_ACTION, $player_id, $start_hex_tag );


    # place cubes on available spots

    my @types = (
        [ $RES_SCIENCE, 'tech_advanced_labs' ],
        [ $RES_MONEY, 'tech_advanced_economy' ],
        [ $RES_MINERALS, 'tech_advanced_mining' ],
    );

    foreach my $type ( @types ) {
        my $open_slots = $start_hex->available_resource_spots( $type->[ 0 ], 0 );

        foreach ( 1 .. $open_slots ) {
            $start_hex->add_cube( $player_id, $type->[ 0 ], 0 )
        }

        if ( $player->race()->has_technology( $type->[ 1 ] ) ) {

            $open_slots = $start_hex->available_resource_spots( $type->[ 0 ], 1 );

            foreach ( 1 .. $open_slots ) {
                $player->race()->resource_track_of( $type->[ 0 ] )->spend();
                $start_hex->add_cube( $player_id, $type->[ 0 ], 1 )
            }
        }
    }

    # build and place initial racial ships

    foreach my $ship_class ( $player->race()->starting_ships() ) {

        my $template = $player->race()->template_of_class( $ship_class );

#        unless ( defined( $template ) ) {
#            print STDERR "\nNo template found ($ship_class) for player id " . $player->id();
#        }

        $self->_raw_create_ship_on_tile(
            $EV_SUB_ACTION,
            $start_hex->tag(),
            $template->tag(),
            $player_id,
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

    my $player_id       = shift( @args );
    my $tile_tag        = shift( @args );
    my $type            = shift( @args );
    my $flag_advanced   = shift( @args ); $flag_advanced = 0             unless defined( $flag_advanced );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( $flag_advanced ) {
            $type = '(adv) ' . $type;
        }
        return $player_id . ' placed ' . $type . ' cube on tile ' . $tile_tag;
    }

    my $tile = $self->tiles()->{ $tile_tag };

    $tile->add_cube( $player_id, $type, $flag_advanced );

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

    my $player_id   = shift( @args );
    my $cube_type   = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' returned cube to track ' . text_from_resource_enum( $cube_type );
    }

    $self->player_of_id( $player_id )->race()->resource_track_of( $cube_type )->add_to_track();

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

    my $player_id   = shift( @args );
    my $tile_tag    = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' influenced tile ' . $tile_tag;
    }

    $self->player_of_id( $player_id )->race()->resource_track_of( $RES_INFLUENCE )->spend();

    $self->tiles()->{ $tile_tag }->set_owner_id( $player_id );

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

    my $player_id   = shift( @args );
    my $tile_tag    = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' picked up influence from ' . $tile_tag;
    }

    if ( $tile_tag eq 'track' ) {
        $player->race()->resource_track_of( $RES_INFLUENCE )->spend();
    }
    else {
        my $tile = $self->tiles()->{ $tile_tag };
        $tile->set_owner_id( -1 );
        $self->_raw_remove_all_cubes_of_owner( $EV_SUB_ACTION, $tile_tag );
    }

    $player->in_hand()->add_items( 'influence_token' );

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

    my $player_id = shift( @args );
    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' returned influence to the resource track';
    }

    $player->in_hand()->remove_item( 'influence_token' );

    $player->race()->resource_track_of( $RES_INFLUENCE )->add_to_track();

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

    my $player_id   = shift( @args );
    my $tile_tag    = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' removed influence from tile ' . $tile_tag;
    }

    $self->_raw_pick_up_influence( $EV_SUB_ACTION, $player_id, $tile_tag );
    $self->_raw_return_influence_to_track( $EV_SUB_ACTION, $player_id );

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

    my $tile = $self->tiles()->{ $tile_tag };
    my $player = $self->player_of_id( $tile->owner_id() );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player->id() . ' removed cubes from tile ' . $tile_tag;
    }

    my @cubes = $self->tiles()->{ $tile_tag }->remove_all_cubes_of_owner( $player->id() );

    foreach my $cube_type ( @cubes ) {
        if ( $cube_type == $RES_WILD ) {
            $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player->id(), 'cube:' . $cube_type );
        }
        else {
            if ( $player->race()->resource_track_of( $cube_type )->available_spaces() > 0 ) {
                $player->race()->resource_track_of( $cube_type )->add_to_track();
            }
            else {
                $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player->id(), 'cube:' . $RES_WILD );
            }
        }
    }

    return;
}

#############################################################################

sub _raw_set_allowed_player_actions {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id   = shift( @args );
    my @allowed     = @args;

    my $player = $self->player_of_id( $player_id );

    $player->allowed_actions()->clear();
    $player->allowed_actions()->add_items( @allowed );

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

    my %removable_races = ();
    foreach ( keys( %{ $self->races() } ) ) {
        $removable_races{ $_ } = 1;
    }

    foreach my $player ( $self->player_list() ) {
        delete( $removable_races{ $player->race_tag() } );
    }

    foreach my $race_tag ( keys( %removable_races ) ) {
        my $race = $self->races()->{ $race_tag };

        foreach my $template_tag ( $race->ship_templates() ) {
            delete ( $self->templates()->{ $template_tag } );
        }

        my $home_tile = $race->home_tile();

        $self->_raw_remove_tile_from_stack( $EV_SUB_ACTION, $home_tile );

        delete ( $self->tiles()->{ $home_tile } );

        delete ( $self->races()->{ $race_tag } );
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
        return $owner_id . ' created ship ' . $ship_tag . ' on tile ' . $tile_tag;
    }

#    print "\nCreating ship $template_tag on $tile_tag";

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
        my $ship = $self->ships()->{ $ship_tag };
        return $ship->owner_id() . ' placed ship ' . $ship_tag . ' on tile ' . $tile_tag;
    }


    my $tile = $self->tiles()->{ $tile_tag };
    $tile->add_ship( $ship_tag );

    return;
}

#############################################################################

sub _raw_remove_ship_from_tile {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $tile_tag = shift( @args );
    my $ship_tag = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $ship = $self->ships()->{ $ship_tag };
        return $ship->owner_id() . ' removed ship ' . $ship_tag . ' from tile ' . $tile_tag;
    }


    my $tile = $self->tiles()->{ $tile_tag };
    $tile->remove_ship( $ship_tag );

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

sub _raw_add_tile_discoveries_to_hand {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    my $player_id       = shift( @args );
    my $tile_tag        = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' claiming discoveries from tile ' . $tile_tag;
    }

    foreach my $discovery_tag ( $self->tiles()->{ $tile_tag }->discoveries() ) {
        $self->_raw_remove_discovery_from_tile( $EV_SUB_ACTION, $tile_tag, $discovery_tag );
        $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player_id, $tile_tag . ':' . $discovery_tag );
    }

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

    my $player_id       = shift( @args );
    my $discovery_tag   = shift( @args );
    my $tile_tag        = shift( @args );
    my $flag_as_vp      = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $as_text = ( $flag_as_vp == 1 ) ? 'as 2 vp' : 'for effect';
        return $player_id . ' used discovery ' . $as_text;
    }

    if ( $flag_as_vp ) {
        $player->race()->discovery_vps()->add_items( $discovery_tag );
    }
    else {
        $self->use_discovery( $tile_tag, $discovery_tag );
    }

    $player->in_hand()->remove_item( $tile_tag . ':' . $discovery_tag );

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

    my $player_id = shift( @args );

    my $player = $self->player_of_id( $player_id );

    $player->race()->set_action_count( $player->race()->action_count() + 1 );

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

    my $player_id = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' spent 1 influence';
    }

    $player->race()->resource_track_of( $RES_INFLUENCE )->spend_but_keep();

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

    my $player_id       = shift( @args );
    my $resource_type   = shift( @args );
    my $amount          = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' spent ' . $amount . ' ' . text_from_resouce_enum( $resource_type );;
    }

    $player->race()->add_resource( $resource_type, - $amount );

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

    my $player_id       = shift( @args );
    my $template_tag    = shift( @args );
    my $component_tag   = shift( @args );
    my $replaces        = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        if ( $replaces eq '' ) {
            return $player_id . ' upgraded template ' . $template_tag . ' with ' . $component_tag;
        }
        else {
            return $player_id . ' upgraded template ' . $template_tag . ' replacing ' . $replaces . ' with ' . $component_tag;
        }
    }

    my $template = $self->ship_templates()->{ $template_tag };

    my $message_holder = '';
    $template->add_component( $component_tag, $replaces, \$message_holder );

    $player->race()->component_overflow()->remove_item( $component_tag );

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

    my $player_id   = shift( @args );
    my $tile_tag    = shift( @args );
    my $type        = shift( @args );
    my $advanced    = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        my $advanced_text = ( $advanced == 1 ) ? ' (adv) ' : '';
        return $player_id . ' used colony ship to place an ' . $advanced_text . text_from_resource_enum( $type ) . ' cube on ' . $tile_tag;
    }

    $player->race()->set_colony_ships_used( $player->race()->colony_ships_used() + 1 );

    $player->race()->resource_track_of( $type )->spend();

    $self->_raw_place_cube_on_tile( $EV_SUB_ACTION, $player_id, $tile_tag, $type, $advanced );

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

    my $player_id = shift( @args );

    my $player = $self->player_of_id( $player_id );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' flipped a colony ship';
    }

    $player->race()->set_colony_ships_used( $player->race()->colony_ships_used() - 1 );

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

    my $player_id = shift( @args );
    my $item = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'added to hand: ' . $item;
    }

    $self->player_of_id( $player_id )->in_hand()->add_items( $item );

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

    my $player_id = shift( @args );
    my $item = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . 'removed from hand: ' . $item;
    }

    $self->player_of_id( $player_id )->in_hand()->remove_item( $item );

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

    my $player_id = shift( @args );
    my $tech_tag = shift( @args );
    my $track_type = shift( @args );

    my $player = $self->player_of_id( $player_id );
    my $tech = $self->technology()->{ $tech_tag };

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' researched ' . $tech_tag;
    }

    my $cost = $self->technology()->{ $tech_tag }->base_cost();
    my $credit = $player->race()->tech_track_of( $track_type )->current_credit();

    $cost -= $credit;
    if ( $cost < $tech->min_cost() ) {
        $cost = $tech->min_cost();
    }

    $player->race()->add_resource( $RES_SCIENCE, - $cost );

    $self->_raw_remove_from_available_tech( $EV_SUB_ACTION, $tech_tag );
    $self->_raw_add_to_tech_track( $EV_SUB_ACTION, $player_id, $tech_tag, $track_type );

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

    my $player_id = shift( @args );
    my $tech_tag = shift( @args );
    my $track_type = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' added ' . $tech_tag . ' to tech track ' . text_from_tech_enum( $track_type );
    }

    $self->player_of_id( $player_id )->race()->tech_track_of( $track_type )->add_techs( $tech_tag );

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

    my $player_id = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return $player_id . ' passed';
    }

    $self->player_of_id( $player_id )->set_flag_passed( 1 );

    if ( $self->has_option( 'option_order_by_passing' ) ) {
        unless ( $self->players_next_round()->contains( $player_id ) ) {
            $self->players_next_round()->add_items( $player_id );
        }
    }
    elsif ( $self->has_option( 'option_order_direction' ) ) {
        if ( $self->players_next_round()->count() == 0 ) {
            $self->players_next_round()->add_items( $player_id );
        }
        elsif ( $self->players_next_round()->count() == 1 ) {
            unless ( $self->players_next_round()->contains( $player_id ) {
                my $first_player = ($self->players_next_round())[ 0 ];

                my @order = $self->pending_players()->items();
                push( @order, $self->done_players()->items() );

                while ( $order[ 0 ] != $first_player ) {
                    push( @order, shift( @order ) );
                }

                $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player_id, 'order:' . join( ',', @order ) );

                push( @order, shift( @order ) );
                @order = reverse( @order );

                $self->_raw_add_item_to_hand( $EV_SUB_ACTION, $player_id, 'order:', join( ',', @order ) );
            }
        }

    }
    elsif ( $self->players_next_round()->count() == 0 ) {
        my @order = $self->pending_players()->items();
        push( @order, $self->done_players()->items() );

        while ( $order[ 0 ] != $first_player ) {
            push( @order, shift( @order ) );
        }

        $self->players_next_round()->add_items( @order );
    }

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

    my $player_id = shift( @args );

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'next player';
    }

    $self->player_of_id( $player_id )->end_turn();

    my $done_player = $self->waiting_on_player_id();
    $self->pending_players()->remove_item( $done_player );
    $self->done_players()->add_items( $done_player );

    if ( $self->pending_players()->count() > 0 ) {
        my $current_player_id = ( $self->pending_players()->items() )[ 0 ];
        $self->player_of_id( $current_player_id )->start_turn();

        $self->set_waiting_on_player_id( $current_player_id );
        return;
    }
    else {
        my $flag_continue_round = 0;

        foreach my $player ( $self->player_list() ) {
            unless ( $player->has_passed() ) {
                $flag_continue_round = 1;
                last;
            }
        }

        if ( $flag_continue_round ) {
            $self->pending_players()->fill( $self->done_players()->items() );
            $self->done_players()->clear();
            $self->set_waiting_on_player_id( ( $self->pending_players()->items() )[ 0 ] );

            $self->player_of_id( $self->waiting_on_player_id() )->start_turn();
        }
        else {
            $self->set_waiting_on_player_id( -1 );
        }
    }

    return;
}

#############################################################################

sub _raw_prepare_for_first_round {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'preparing first round';
    }


    $self->_prepare_for_first_round();

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

#    print STDERR "\nNext Round: " . join( ',', $self->players_next_round()->items() );

    my @ready = $self->players_next_round()->items();
    $self->players_next_round()->clear();
    $self->done_players()->clear();

    $self->pending_players()->fill( @ready );

    my $new_round = $self->round() + 1;

    my $next_player = ( $self->pending_players()->items() )[ 0 ];

    my $player = $self->player_of_id( $next_player );
    $player->start_turn();

    $self->set_state( $ST_NORMAL );
    $self->set_round( $new_round );
    $self->set_phase( $PH_ACTION );
    $self->set_waiting_on_player_id( $next_player );
    $self->set_subphase( $SUB_NULL );
    $self->set_current_tile( '' );

    $self->_raw_set_status( $EV_SUB_ACTION, $self->status() );

    return;
}

#############################################################################

sub _raw_start_upkeep {
    my $self        = shift;
    my $source      = shift;
    my @args        = @_;

    if ( $source == $EV_FROM_INTERFACE || $source == $EV_SUB_ACTION ) {
        $self->_log_event( $source, __SUB__, @args );
    }

    if ( $source == $EV_FROM_LOG_FOR_DISPLAY ) {
        return 'starting upkeep';
    }

    my @ready = $self->done_players()->items();
    $self->done_players()->clear();
    $self->pending_players()->fill( @ready );

    my $next_player = ( $self->pending_players()->items() )[ 0 ];

    my $player = $self->player_of_id( $next_player );
    $player->start_upkeep();

    $self->set_state( $ST_NORMAL );
    $self->set_phase( $PH_UPKEEP );
    $self->set_waiting_on_player_id( $next_player );
    $self->set_subphase( $SUB_NULL );
    $self->set_current_tile( '' );

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

    $self->set_long_name( <$fh_log> );

    $self->source_tags()->fill( split( /,/, <$fh_log> ) );

    unless ( $self->source_tags()->count() > 0 ) {
        $self->set_error( 'Missing source tags' );
        return 0;
    }

    $self->option_tags()->fill( split( /,/, <$fh_log> ) );

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
