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








    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub start_combat_in_tile {
    my $self            = shift;
    my $tile_tag        = shift;

    $self->set_phase( $PH_COMBAT );
    $self->set_current_tile( $tile_tag );

    my $tile = $self->tiles()->{ $tile_tag };
    my ( $defender_id, $attacker_id ) = $tile->current_combatant_ids();

    my $first_player_id = $self->_queue_up_ships( $tile_tag, 1 );

    if ( defined( $first_player_id ) ) {
        $self->set_subphase( $SUB_MISSILE );

        if ( $first_player_id > -1 ) {
            $self->set_waiting_on_player_id( $first_player_id );
            $self->_give_attack_or_retreat_option();
            return 1;
        }
        else { # computer player
            # TODO computer missile attacks

            return 1;
        }
    }

    $first_player_id = $self->_queue_up_ships( $tile_tag, 0 );

    if ( defined( $first_player_id ) ) {
        $self->set_subphase( $SUB_MISSILE );

        if ( $first_player_id > -1 ) {
            $self->set_waiting_on_player_id( $first_player_id );
            $self->_give_attack_or_retreat_option();
            return 1;
        }
        else { # computer player
            # TODO computer beam attacks


            return 1;
        }
    }

    return 0;
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

    if ( $self->board()->player_retreat_options( $tile_tag, $player_id ) ) {
        push( @allowed, 'retreat' );
    }

    my $race = $self->race_of_player_id( $player_id );
    $race->set_allowed_actions( @allowed );

    return;
}


#############################################################################


sub action_ {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

















    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################
#############################################################################
1
