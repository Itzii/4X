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

    return 1;
}

#############################################################################

sub action_roll_npc {
    my $self            = shift;
    my %args            = @_;

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

    return 1;
}

#############################################################################

sub action_allocate_hits {
    my $self            = shift;
    my %args            = @_;

    my ( $defender_id, $attacker_id ) = $self->tiles()->{ $self->current_tile() }->current_combatant_ids();

    my $self_id = $attacker_id;
    my $enemy_id = $defender_id;
    if ( $enemy_id = $self->acting_player()->id() ) {
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

    return 1;
}

#############################################################################

sub action_allocate_defense_hits {
    my $self            = shift;
    my %args            = @_;

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

    if ( $enemy_id = $self->acting_player()->id() ) {
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

    return 1;
}

#############################################################################

sub action_acknowledge_hits {
    my $self            = shift;
    my %args            = @_;


    $self->_raw_apply_combat_hits( $EV_FROM_INTERFACE );



    $self->_raw_next_combat_ships( $EV_FROM_INTERFACE );

    return 1;
}

#############################################################################

sub action_retreat {
    my $self            = shift;
    my %args            = @_;

    my $tile_tag = $self->current_tile();
    my $template_tag = ($self->template_combat_order())[ 0 ];

    $self->_raw_prepare_to_retreat_ships( $EV_FROM_INTERFACE, $tile_tag, $template_tag );

    return 1;
}

#############################################################################

sub action_attack_populace {
    my $self            = shift;
    my %args            = @_;

    my $tile = $self->tiles()->{ $self->current_tile() };

    my @hits = ();

    foreach my $ship ( $tile->ships()->items() ) {
        if ( $ship->owner_id() == $self->acting_player->id() ) {
            foreach my $attack ( $ship->roll_beam_attacks() ) {
                if ( $self->does_roll_hit_ship( $attack->{'roll'}, $ship->template(), undef ) ) {
                    push( @hits, 'hit:' . $attack->{'strength'} . ':' . $attack->{'roll'} );
                }
                else {
                    push( @hits, 'miss:' . $attack->{'strength'} . ':' . $attack->{'roll'} );
                }
            }
        }
    }

    my $race = $self->race_of_player_id( $tile->owner_id() );

    $self->_raw_allocate_population_hits( $EV_FROM_INTERFACE, @hits );
    $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, $race->tag(), 'apply_population_hits' );

    return 1;
}

#############################################################################

sub action_apply_population_hits {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'applied_hits'} ) ) {
        $self->set_error( 'Missing Applied Hits' );
        return 0;
    }

    my $total_allowed_hits = 0;

    foreach my $attack ( $self->combat_rolls()->items() ) {
        my ( $result, $strength, $roll ) = split( /:/, $attack );
        if ( $result eq 'hit' ) {
            $total_allowed_hits += $stength;
        }
    }

    my @applied_hits = split( /,/, $args{'applied_hits'} );
    if ( scalar( @applied_hits ) > $total_allowed_hits ) {
        $self->set_error( 'Invalid Number Of Applied Hits' );
        return 0;
    }

    my @types_to_kill = ();

    foreach my $hit ( @applied_hits ) {
        my $type = enum_from_resource_text( $hit );
        push( @types_to_kill, $type );
    }

    $self->_raw_kill_population( $EV_FROM_INTERFACE, @types_to_kill );

    return 1;
}

#############################################################################

sub action_dont_attack_populace {
    my $self            = shift;
    my %args            = @_;

    $self->_raw_dont_kill_population( $EV_FROM_INTERFACE );

    return 1;
}

#############################################################################

sub action_draw_vp {
    my $self            = shift;
    my %args            = @_;

    my $vp_draws = $self->acting_player()->race()->vp_draws();

    if ( $vp_draws > 5 ) {
        $vp_draws = 5;
    }

    my @all_vp_tokens = $server->vp_bag()->items();
    shuffle_in_place( \@all_vp_tokens );

    if ( scalar( @all_vp_tokens ) < $vp_draws ) {
        $vp_draws = scalar( @all_vp_tokens );
    }

    my $player_vp_tokens = ();
    for ( 1 .. $vp_draws ) {
        push( @player_vp_tokens, shift( @all_vp_tokens ) );
    }

    $self->_raw_add_vp_to_hand( $EV_FROM_INTERFACE, $self->acting_player()->race_tag, @player_vp_tokens );

    return 1;
}

#############################################################################

sub action_select_vp_token {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'token'} ) ) {
        $self->set_error( 'Missing Token Argument' );
        return 0;
    }

    my $new_token = $args{'token'};

    unless ( $self->acting_player()->in_hand()->contains( $new_token ) ) {
        $self->set_error( 'Invalid Token Argument' );
        return 0;
    }

    my $old_token = '';
    if ( defined( $args{'replaces'} ) ) {
        $old_token = $args{'replaces'};
        unless ( looks_like_number( $old_token ) ) {
            $self->set_error( 'May Not Replace Ambassadors' );
            return 0;
        }
    }

    if ( $self->acting_player()->race()->can_add_vp_item( $new_token, $old_token ) ) {
        $self->set_error( 'Invalid VP Type Count' );
        return 0;
    }

    $self->_raw_select_vp_token( $EV_FROM_INTERFACE, $self->acting_player()->race_tag(), $new_token, $old_token );

    $self->_raw_next_vp_draw_player( $EV_FROM_INTERFACE, $self->current_tile() );

    return 1;
}


#############################################################################
# general combat methods
#
# These should only call from _raw_action wrappers or from each other
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

    if ( defined( $defending_template ) ) {
        $roll -= $defending_template->total_shields();
    }

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
        $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
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
                $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
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
            $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $self->race_of_player_id( $real_player_id )->tag(), 'roll_npc' );
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub attack_population {
    my $self            = shift;
    my $tile_tag        = shift;

    $self->set_subphase( $SUB_PLANETARY );


    my $tile = $self->tiles()->{ $tile_tag };

    my %all_ship_owners = ();

    foreach my $ship_tag ( $tile->ships()->items() ) {
        my $ship = $self->ships()->{ $ship_tag };

        if ( $ship->total_beam_attacks() > 0 ) {
            $all_ship_owners{ $ship->owner_id() } = 1;
        }
    }

    my @ship_owners = sort{ $a <=> $b } keys( %all_ship_owners );

    # check for alliances

    if ( $ship_owners[ 0 ] == -1 ) {

        my $total_hits = 0;

        foreach my $ship ( $tile->ships()->items() ) {
            if ( $ship->owner_id() == -1 ) {
                my @attacks = $ship->roll_beam_attacks();
                foreach my $attack ( @attacks ) {
                    if ( $self->does_roll_hit_ship( $attack->{'roll'}, $ship->template(), undef ) ) {
                        $total_hits += $attack->{'strength'};
                    }
                }
            }
        }

        if ( $total_hits > 0 ) {
            foreach my $slot ( $tile->resource_slots() ) {
                if ( $total_hits > 0 && $slot->owner_id() > -1 ) {
                    $total_hits--;
                    $self->_raw_kill_population_cube( $EV_SUB_ACTION, $tile_tag, $slot->resource_type() );
                }
            }
        }

        shift( @ship_owners );
    }

    if ( scalar( @ship_owners ) > 0 ) {
        $tile->attack_population_queue()->add_items( @ship_owners );

        my $next_player = $ship_owners[ 0 ];
        $self->_raw_set_pending_player( $EV_SUB_ACTION, $next_player );

        my $race = $self->race_of_player_id( $next_player );

        $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $race->tag(), 'attack_populace', 'dont_attack_populace' );
        return;
    }

    $self->_raw_start_vp_draws( $EV_SUB_ACTION, $tile->tag() );

    return;
}

#############################################################################

sub kill_population {
    my $self            = shift;
    my @cubes_to_kill   = @_;

    foreach my $type ( @cubes_to_kill ) {
        $self->_raw_kill_population_cube( $EV_SUB_ACTION, $self->current_tile(), $type );
    }

    $self->next_population_attacker();

    return;
}

#############################################################################

sub kill_population_cube {
    my $self            = shift;
    my $tile_tag        = shift;
    my $type            = shift;

    my $tile = $self->tiles()->{ $tile_tag };
    my $flag_found_cube = 0;

    $flag_found_cube = ( $tile->remove_cube( $type, 1 ) ); # first we attempt to remove a cube of the advanced type

    unless ( $flag_found_cube ) {
        $tile->remove_cube( $type, 0 ) ); # next we try a basic cube
    }

    my $race = $self->race_of_player_id( $tile->owner_id() );

    $race->graveyard()->add_items( $type );

    return;
}

#############################################################################

sub next_population_attacker {
    my $self            = shift;

    my $tile = $self->tiles()->{ $self->current_tile() };

    my @pending = $tile->attack_population_queue()->items();
    shift( @pending );
    $tile->attack_population_queue()->fill( @pending );

    if ( $tile->attack_population_queue()->count() > 0 ) {
        $self->_raw_set_pending_player( $pending[ 0 ] );

        my $race = $self->race_of_player_id( $pending[ 0 ] );
        $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $race->tag(), 'attack_populace', 'dont_attack_populace' );

        return;
    }

    $self->_raw_start_vp_draws( $EV_SUB_ACTION, $tile->tag() );

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

    if ( $tile->has_population_cubes() ) {

        my $tile_race = $self->race_of_player_id( $tile->owner_id() );

        # check for bombs

        unless ( $tile_race->does_provide( 'tech_bomb_shield' ) ) {
            foreach my $ship ( $tile->ships()->items() ) {
                if ( $ship->owner_id() > -1 && $ship->owner_id() != $tile->owner_id() ) { # need to check for alliances here
                    if ( $ship->does_provide( 'tech_bombs' ) ) {
                        $self->bomb_all_cubes( $tile->tag() );
                        last;
                    }
                }
                elsif ( $ship->owner_id() == -1 ) {
                    unless ( $tile_race->does_provide( 'spec_descendants' ) ) {
                        $self->bomb_all_cubes( $tile->tag() );
                        last;
                    }
                }
            }
        }

        # did population survive bombs ?

        if ( $tile->has_population_cubes() ) {
            $self->_raw_attack_population( $EV_SUB_ACTION, $tile->tag() );
            return;
        }

    }

    # no population to attack - we now go to vp draws

    $self->_raw_start_vp_draws( $EV_SUB_ACTION, $tile->tag() );

    return;
}

#############################################################################

sub bomb_all_cubes {
    my $self            = shift;
    my $tile_tag        = shift;

    foreach my $slot ( $tile->resource_slots() ) {
        if ( $slot->owner_id() > -1 ) {
            $self->_raw_kill_population_cube( $EV_SUB_ACTION, $tile->tag(), $slot->resource_type() );
        }
    }

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
    $self->pending_players()->fill( $tile->vp_draw_queue() );

    $self->_raw_next_vp_draw_player( $EV_SUB_ACTION, $tile_tag );

    return;
}

#############################################################################

sub next_vp_draw {
    my $self            = shift;
    my $tile_tag        = shift;

    my $tile = $self->tiles()->{ $tile_tag };

    my $race = $self->race_of_player_id( $self->waiting_on_player_id() );

    $self->_raw_set_allowed_race_actions( $EV_SUB_ACTION, $race->tag(), 'draw_vp' );

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
