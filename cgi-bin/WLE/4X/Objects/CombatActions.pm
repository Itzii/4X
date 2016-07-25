package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;


#############################################################################

sub action_attack {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    my $tile_tag = $self->current_tile();
    my $template_tag = ($self->template_combat_order())[ 0 ];
    my $ship_owner = $self->ship_templates()->{ $template_tag }->owner_id();

    my $tile = $self->tiles()->{ $tile_tag };

    my %attacks = ();

    foreach my $ship ( $tile->ships()->items() ) {
        if ( $ship->template()->tag() eq $template_tag ) {
            my %ship_attacks = ();

            if ( $self->subphase() == $SUB_MISSILE ) {
                %ship_attacks = $ship->total_missile_attacks();
            }
            else {
                %ship_attacks = $ship->total_beam_attacks();
            }

            foreach my $strength ( keys( %ship_attacks ) ) {
                if ( defined( $attacks{ $strength } ) ) {
                    $attacks{ $strength } += $ship_attacks{ $strength };
                }
                else {
                    $attacks{ $strength } = $ship_attacks{ $strength };
                }
            }
        }
    }

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    my $enemy_id = $defender_id;
    if ( $enemy_id == $ship_owner ) {
        $enemy_id = $attack_id;
    }

    my @rolls = ();

    foreach my $strength ( sort( keys( %attacks ) ) ) {
        foreach ( 1 .. $attacks{ $strength } ) {
            push( @rolls, $strength . ':' . $self->roll_die() );
        }
    }

    $self->_raw_make_attack_rolls( $EV_FROM_INTERFACE, @rolls );

    $self->_raw_set_pending_player( $EV_FROM_INTERFACE, $ship_owner );
    my $race = $self->race_of_player_id( $ship_owner );
    $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $race->tag(), 'allocate_hits' );

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_roll_npc {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    my $tile_tag = $self->current_tile();
    my $template_tag = ($self->template_combat_order())[ 0 ];

    my $tile = $self->tiles()->{ $tile_tag };

    my %attacks = ();

    foreach my $ship ( $tile->ships()->items() ) {
        if ( $ship->template()->tag() eq $template_tag ) {
            my %ship_attacks = ();

            if ( $self->subphase() == $SUB_MISSILE ) {
                %ship_attacks = $ship->total_missile_attacks();
            }
            else {
                %ship_attacks = $ship->total_beam_attacks();
            }

            foreach my $strength ( keys( %ship_attacks ) ) {
                if ( defined( $attacks{ $strength } ) ) {
                    $attacks{ $strength } += $ship_attacks{ $strength };
                }
                else {
                    $attacks{ $strength } = $ship_attacks{ $strength };
                }
            }
        }
    }

    my $enemy_id = $self->real_player_in_combat();

    my @rolls = ();

    foreach my $strength ( sort( keys( %attacks ) ) ) {
        foreach ( 1 .. $attacks{ $strength } ) {
            push( @rolls, $strength . ':' . $self->roll_die() );
        }
    }

    $self->_raw_make_attack_rolls( $EV_FROM_INTERFACE, @rolls );

    @rolls = $self->ai_descision_allocate_hits( $template_tag, @rolls );

    $self->_raw_allocate_hits( $EV_FROM_INTERFACE, @rolls );

    if ( $self->subphase() == $SUB_MISSILE ) {
        foreach my $ship ( $tile->ships()->items() ) {
            if ( $ship->owner_id() == $enemy_id ) {
                $missile_defense_hits += $ship->roll_missile_defense();
            }
        }
    }

    $self->_raw_set_pending_player( $enemy_id );

    if ( $missile_defense_hits > 0 ) {
        $self->_raw_set_defense_hits( $EV_FROM_INTERFACE, $missile_defense_hits );
        $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $enemy_id ), 'allocate_defense_hits' );
    }
    else {
        $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $enemy_id ), 'acknowledge_hits' );
    }

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_allocate_hits {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    my ( $defender_id, $attacker_id ) = $self->tiles()->{ $self->current_tile() }->current_combatant_ids();

    my $self_id = $attacker_id;
    my $enemy_id = $defender_id;
    if ( $enemy_id = $self->current_user() ) {
        $enemy_id = $attacker_id;
        $self_id = $defender_id;
    }

    my $attacking_template = $self->ship_templates()->{ ($self->template_combat_order())[ 0 ] };

    my $hits_recorded = WLE::Objects::Stack->new();
    $hits_recorded->add_items( $self->combat_rolls()->items() );

    my %allocated_hits = %args;

    foreach my $ship_tag ( keys( %allocated_hits ) ) {

        my $ship = $self->ships()->{ $ship_tag };

        unless ( defined( $ship ) ) {
            $self->set_error( 'Non-existant Target Ship' );
            return 0;
        }

        unless ( $ship->owner_id() == $enemy_id ) {
            $self->set_error( 'Invalid Target Ship' );
            return 0;
        }

        foreach my $hit ( split( /,/, $allocated_hits{ $ship_tag } ) ) {
            unless ( $hits_recorded->contains( $hit ) ) {
                $self->set_error( 'Invalid Hit: ' . $hit );
                return 0;
            }

            my ( $strength, $roll ) = split( /:/, $hit );
            if ( $self->does_roll_hit_ship( $roll, $attacking_template, $ship->template() ) ) {
                $self->set_error( 'Allocating Missed Roll' );
                return 0;
            }

            $hits->recorded()->remove_item( $hit );
        }
    }

    my $tile = $self->tiles()->{ $self->current_tile() };
    my $missile_defense_hits = 0;

    if ( $self->subphase() == $SUB_MISSILE ) {
        foreach my $ship ( $tile->ships()->items() ) {
            if ( $ship->owner_id() == $enemy_id ) {
                $missile_defense_hits += $ship->roll_missile_defense();
            }
        }
    }

    if ( $enemy_id == -1 ) {
        if ( $missile_defense_hits > 0 ) {
            %allocated_hits = $self->ai_decision_apply_missile_defense(
                $missile_defense_hits,
                %allocated_hits,
            );
        }

        $self->_raw_set_pending_player( $EV_FROM_INTERFACE, $self_id );
        $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $self_id ), 'acknowledge_hits' );
    }
    else {
        $self->_raw_set_pending_player( $enemy_id );

        if ( $missile_defense_hits > 0 ) {
            $self->_raw_set_defense_hits( $EV_FROM_INTERFACE, $missile_defense_hits );
            $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $enemy_id ), 'allocate_defense_hits' );
        }
        else {
            $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $enemy_id ), 'acknowledge_hits' );
        }
    }

    my @current_hits = ();
    foreach my $ship_tag ( keys( %allocated_hits ) ) {
        my @hits = split( /,/, $allocated_hits{ $ship_tag } );
        foreach ( @hits ) {
            push( @current_hits, $ship_tag . ':' . $_ );
        }
    }

    $self->_raw_allocate_hits( $EV_FROM_INTERFACE, @current_hits );

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_allocate_defense_hits {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'hits'} ) ) {
        $self->set_error( 'Missing Hits Argument' );
        return 0;
    }

    my $hits_recorded = WLE::Objects::Stack->new();
    $hits_recorded->add_items( $self->combat_rolls()->items() );

    my @allocated_defense_hits = split( /,/, $args{'hits'} );

    if ( scalar( @allocated_defense_hits ) > $self->missile_defense_hits() ) {
        $self->set_error( 'Too many hits allocated' );
        return 0;
    }

    foreach my $hit ( @allocated_defense_hits ) {
        unless ( $hits_recorded->contains( $hit ) ) {
            $self->set_error( 'Invalid Hit' );
            return 0;
        }

        $hits_recorded->remove_item( $hit );

        my ( $ship_tag, $strength, $roll ) = split( /:/, $hit );
        $hits_recorded->add( 'countered:' . $strength . ':' . $roll );
    }

    my ( $defender_id, $attacker_id ) = $self->tiles()->{ $self->current_tile() }->current_combatant_ids();

    my $self_id = $attacker_id;
    my $enemy_id = $defender_id;

    if ( $enemy_id = $self->current_user() ) {
        $enemy_id = $attacker_id;
        $self_id = $defender_id;
    }

    $self->_raw_allocate_hits( $EV_FROM_INTERFACE, @hits_recorded );

    if ( $enemy_id == -1 ) {
        $self->_raw_set_pending_player( $EV_FROM_INTERFACE, $self_id );
        $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $self_id ), 'acknowledge_hits' );
    }
    else {
        $self->_raw_set_pending_player( $EV_FROM_INTERFACE, $enemy_id );
        $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $self->race_of_player_id( $enemy_id ), 'acknowledge_hits' );
    }

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_acknowledge_hits {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    $self->_raw_apply_combat_hits( $EV_FROM_INTERFACE );



    $self->_raw_next_combat_ships( $EV_FROM_INTERFACE );

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_retreat {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    my $tile_tag = $self->current_tile();
    my $template_tag = ($self->template_combat_order())[ 0 ];

    $self->_raw_prepare_to_retreat_ships( $EV_FROM_INTERFACE, $tile_tag, $template_tag );

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_draw_vp {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    # TODO


    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################
# general combat methods
#############################################################################

sub does_roll_hit_ship {
    my $self                = shift;
    my $roll                = shift;
    my $attacking_template  = shift;
    my $defending_template  = shift;

    if ( $roll == 1 ) {
        return 0;
    }

    if ( $roll == 6 ) {
        return 1;
    }

    $roll += $attacking_template->total_computer();
    $roll -= $defending_template->total_shields();

    if ( $self->subphase() == $SUB_MISSILE ) {
        if ( $defending_template->does_provide( 'tech_missile_shield2') ) {
            $roll -= 2;
        }
    }

    return ( $roll >= 6 );
}

#############################################################################

sub real_player_in_combat {
    my $self            = shift;

    my ( $combat_id_1, $combat_id_2 ) = $self->tiles()->{ $self->current_tile() }->current_combatant_ids();

    if ( $combat_id_1 == -1 ) {
        return $combat_id_2;
    }

    return $combat_id_1;
}

#############################################################################

sub npc_attacks {
    my $self            = shift;

    # TODO






}

#############################################################################

sub apply_combat_hits {
    my $self            = shift;

    my ( $combat_id_1, $combat_id_2 ) = $self->tiles()->{ $self->current_tile() }->current_combatant_ids();

    my @hits = $self->combat_hits()->items();

    foreach my $hit ( @hits ) {
        my ( $ship_tag, $strength, $roll ) = split( /:/, $hit );

        my $ship = $self->ships()->{ $ship_tag };
        $ship->add_damage( $strength );
    }

    foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
        my $ship = $self->ships()->{ $ship_tag };

        if ( $ship->is_destroyed() ) {
            my $receiver_id = ( $ship->owner_id() == $combat_id_1 ) ? $combat_id_2 : $combat_id_1;
            if ( $receiver_id > -1 ) {
                my $race = $self->race_of_player_id( $receiver_id );
                $race->set_vp_draws( $race->vp_draws() + $ship->vp_draws() );
            }

            $self->_raw_destroy_ship( $EV_SUB_ACTION, $self->current_tile(), $ship->tag() );
        }
    }

    return;
}

#############################################################################

sub next_combat_ships {
    my $self            = shift;

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    my $defender_count = $self->tiles()->{ $self->current_tile() }->user_ship_count( $defender_id );
    my $attacker_count = $self->tiles()->{ $self->current_tile() }->user_ship_count( $attacker_id );

    if ( $attacker_count == 0 || $defender_count == 0 ) {
        $self->end_combat();
        return;
    }

    # check for stalemate
    # if no one has beam weapons and the attacker has no retreat route then the attacker's
    # ships are destroyed

    my $flag_someone_has_beam_weapons = 0;

    foreach my $user_id ( $defender_id, $attacker_id ) {
        foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
            my $ship = $self->ships()->{ $ship_tag };
            if ( $ship->owner_id() == $user_id ) {
                my %beam_attacks = $ship->total_beam_attacks();
                if ( scalar( keys( %beam_attacks ) ) > 0 ) {
                    $flag_someone_has_beam_weapons = 1;
                }
            }
        }
    }

    unless ( $flag_someone_has_beam_weapons ) {
        my @retreat_options = $self->board()->player_retreat_options( $tile_tag, $player_id );

        if ( scalar( @retreat_options ) == 0 ) {
            foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
                my $ship = $self->ships()->{ $ship_tag };
                if ( $ship->owner_id() == $attacker_id ) {
                    $self->_raw_destroy_ship( $EV_SUB_ACTION, $self->current_tile(), $ship_tag );
                }
            }

            $self->end_combat();
            return;
        }
    }


    # if there are no more ship classes to fight with then we end the round

    my $done_template = ( $self->template_combat_order()->items() )[ 0 ];
    $self->template_combat_order()->remove_item( $done_template );

    if ( $self->template_combat_order()->count() == 0 ) {
        $self->end_combat_round();
        return;
    }

    # still got more fight

    my $player_id = $self->ship_templates()->{ $templates[ 0 ] }->owner_id();

    if ( $player_id > -1 ) {
        $self->set_waiting_on_player_id( $player_id );
        $self->_give_attack_or_retreat_option();
        return;
    }
    else { # computer player
        my $real_player_id = $self->real_player_in_combat();
        $self->set_waiting_on_player_id( $real_player_id );
        $self->_raw_set_allowed_race_actions( $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
        return;
    }
}

#############################################################################

sub end_combat_round {
    my $self            = shift;

    # do regeneration if needed

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
        my $ship = $self->ships()->{ $ship_tag };

        if ( $ship->owner_id() == $defender_id || $ship->owner_id() == $attacker_id ) {
            if ( $ship->does_provide( 'tech_regenerate' ) ) {
                if ( $ship->damage() > 0 ) {
                    $self->add_damage( -1 );
                }
            }
        }
    }

    $self->start_combat_round( 0 );

    return;
}

#############################################################################

sub start_combat_round {
    my $self            = shift;
    my $flag_missile    = shift;

    my $first_player_id = undef;

    if ( $flag_missile ) {
        $self->set_subphase( $SUB_MISSILE );

        $first_player_id = $self->_queue_up_ships( $tile_tag, 1 );

        if ( defined( $first_player_id ) ) {
            $self->set_subphase( $SUB_MISSILE );

            if ( $first_player_id > -1 ) {
                $self->set_waiting_on_player_id( $first_player_id );
                $self->_give_attack_or_retreat_option();
                return 1;
            }
            else { # computer player
                my $real_player_id = $self->real_player_in_combat();
                $self->set_waiting_on_player_id( $real_player_id );
                $self->_raw_set_allowed_race_actions( $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
                return 1;
            }
        }
    }

    my $first_player_id = $self->_queue_up_ships( $self->current_tile(), 0 );

    if ( defined( $first_player_id ) ) {
        $self->set_subphase( $SUB_BEAM );

        if ( $first_player_id > -1 ) {
            $self->set_waiting_on_player_id( $first_player_id );
            $self->_give_attack_or_retreat_option();
            return 1;
        }
        else { # computer player
            my $real_player_id = $self->real_player_in_combat();
            $self->set_waiting_on_player_id( $real_player_id );
            $self->_raw_set_allowed_race_actions( $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub attack_population {
    my $self            = shift;






    return;
}


#############################################################################

sub end_combat {
    my $self            = shift;


    # more combats in this tile ?

    my $tile = $self->tiles()->{ $self->current_tile() };

    $tile->set_combatant_ids();

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    if ( $defender_id > -1 || $attacker_id > -1 ) {
        $self->_raw_begin_combat_in_tile( $EV_SUB_ACTION, $tile->tag() );
        return;
    }

    # check for population to attack

    if ( $tile->owner_id() > -1 ) {

        # TODO


        $self->attack_population();


    }

    # no population to attack - we now go to vp draws

    $self->_raw_start_vp_draws( $EV_SUB_ACTION, $tile->tag() );

    return;
}

#############################################################################

sub start_vp_draws {
    my $self            = shift;
    my $tile_tag        = shift;

    my $tile = $self->tiles()->{ $tile_tag };

    my @draw_queue = ();
    foreach my $user_id ( $tile->vp_draw_queue() ) {
        if ( $user_id != -1 ) {
            push( @draw_queue, $user_id );
        }
    }

    $self->set_subphase( $SUB_VP_DRAW );
    $self->set_pending_players( $tile->vp_draw_queue() );

    $self->_raw_next_vp_draw_player( $EV_SUB_ACTION, $tile_tag );

    return;
}

#############################################################################

sub next_vp_draw {
    my $self            = shift;
    my $tile_tag        = shift;

    my $tile = $self->tiles()->{ $tile_tag };

    my $race = $self->race_of_player_id( $self->waiting_on_player_id() );

    $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, 'draw_vp' );

    return;
}

#############################################################################

sub tag_ships_to_retreat {
    my $self            = shift;
    my $tile_tag        = shift;
    my $template_tag    = shift;

    my $tile = $self->tiles()->{ $tile_tag };

    my $flag_has_more_ships = 0;
    my $owner_id = $self->ship_templates()->{ $template_tag }->owner_id();

    foreach my $ship ( $tile->ships()->items() ) {
        if ( $ship->template()->tag() eq $template_tag ) {
            $ship->set_retreating( 1 );
        }
        elsif ( $ship->owner_id() == $owner_id ) {
            $flag_has_more_ships = 1;
        }

    }

    # if this is the last of the races ships in the battle then
    # we take away the vp draw for participating in the battle

    unless ( $flag_has_more_ships ) {
        my $race = $self->race_of_player_id( $owner_id );
        $race->set_vp_draws( $race->vp_draws() - 1 );
    }

    return;
}

#############################################################################

sub start_combat_in_tile {
    my $self                = shift;
    my $tile_tag            = shift;
    my $flag_first_in_tile  = shift; $flag_first_in_tile = 0            unless defined( $flag_first_in_tile );

    $self->set_phase( $PH_COMBAT );
    $self->set_current_tile( $tile_tag );

    my $tile = $self->tiles()->{ $tile_tag };
    $tile->set_combatant_ids();

    if ( $flag_first_in_tile ) {
        $tile->set_vp_draw_queue( $tile->owner_queue()->items() );
    }

    foreach my $ship ( $tile->ships()->items() ) {
        $ship->set_retreating( 0 );
    }

    # give each combatant a vp draw for being in the battle.
    # if they later retreat their last ships then we'll take it away

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    foreach my $user_id ( $defender_id, $attacker_id ) {
        if ( $user_id > -1 ) {
            my $user_race = $self->race_of_player_id( $user_id );
            $user_race->set_vp_draws( $user_race->vp_draws() + 1 );
        }
    }

    return $self->start_combat_round( 1 );
}

#############################################################################

sub _queue_up_ships {
    my $self            = shift;
    my $tile_tag        = shift;
    my $flag_missiles   = shift;

    my $tile = $self->tiles()->{ $tile_tag };

    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    my %ships_templates = ();
    my $first_player_id = undef;

    foreach my $ship_tag ( $tile->ships()->items() ) {
        my $ship = $self->ships()->{ $ship_tag };

        if ( $ship->owner_id() == $defender_id || $ship->owner_id() == $attacker_id ) {

            if ( $flag_missiles ) {
                if ( $ship->template()->total_missile_attacks() > 0 ) {
                    $missile_ship_templates{ $ship->template()->tag() } = 1;
                }
            }
            else {
                if ( $ship->template()->total_beam_attacks() > 0 ) {
                    my $initiative = $ship->template()->total_initiative();
                    if ( $ship->owner_id() == $defender_id ) {
                        $initiative += 0.5;
                    }
                    $missile_ship_templates{ $ship->template()->tag() } = $intiative;
                }
            }
        }
    }

    if ( scalar( keys( %ships_templates ) ) > 0 ) {
        my @template_tags = sort { $ships_templates{ $b } <=> $ships_templates{ $a } } keys( %ships_templates );

        $first_player_id = $self->ship_templates()->{ $template_tags[ 0 ] }->owner_id();

        $self->template_combat_order()->add_items( @template_tags );
    }

    return $first_player_id;
}

#############################################################################

sub _give_attack_or_retreat_option {
    my $self            = shift;

    my $player_id = $self->waiting_on_player_id();
    my $first_template = ($self->template_combat_order())[ 0 ];
    my $tile_tag = $self->current_tile();

    my @allowed = ( 'attack' );

    my @retreat_options = $self->board()->player_retreat_options( $tile_tag, $player_id );
    if ( scalar( @retreat_options ) > 0 ) {
        push( @allowed, 'retreat' );
    }

    my $race = $self->race_of_player_id( $player_id );
    $race->set_allowed_actions( @allowed );

    return;
}

#############################################################################
#############################################################################
1