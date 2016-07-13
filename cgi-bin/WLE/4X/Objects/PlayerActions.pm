package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;


#############################################################################

sub action_pass_action {
    my $self            = shift;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    $self->_raw_player_pass_action( $EV_FROM_INTERFACE );
    $self->_raw_next_player( $EV_FROM_INTERFACE );

    if ( $self->waiting_on_player_id() == -1 ) {
        $self->_raw_start_combat_phase( $EV_FROM_INTERFACE );
    }

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_explore {
    my $self            = shift;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }






# spec_descendants





    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_influence {
    my $self            = shift;









    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_research {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_upgrade {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_build {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}


#############################################################################

sub action_move {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_react_upgrade {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_react_build {
    my $self            = shift;





    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }




    $self->_save_state();
    $self->_close_all();

    return 1;
}


#############################################################################

sub action_react_move {
    my $self            = shift;





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
