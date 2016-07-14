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
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'loc_x'} ) && defined( $args{'loc_y'} ) ) {
        $self->set_error( 'Missing Location Information' );
        return 0;
    }

    my $loc_x = $args{'loc_x'};
    my $loc_y = $args{'loc_y'};
    my $loc_tag = $loc_x . ':' . $loc_y;

    my @explorables = $self->board()->explorable_spaces_for_race( $self->race_tag_of_current_user() );

    unless ( matches_any( $loc_tag, @explorables ) ) {
        $self->set_error( 'Invalid Exploration Location' );
        return 0;
    }

    my $stack_id = $self->board()->stack_from_location( $loc_x, $loc_y );

    my $tiles_to_draw = ( $self->race_of_current_user()->provides( 'spec_descendants') ) ? 2 : 1;

    foreach ( 1 .. $tiles_to_draw ) {
        if ( $self->board()->tile_draw_stack( $stack_id )->count() == 0 ) {
            my @tile_tags = $self->board()->tile_discard_stack( $stack_id )->items();
            shuffle_in_place( \@tile_tags );
            $self->_raw_empty_tile_discard_stack( $EV_FROM_INTERFACE, $stack_id );
            $self->_raw_create_tile_stack( $EV_FROM_INTERFACE, $stack_id, @tile_tags );
        }

        if ( $self->board()->tile_draw_stack( $stack_id )->count() > 0 ) {
            my $tile_tag = $self->board()->tile_draw_stack( $stack_id )->select_random_item();
            $self->_raw_remove_tile_from_stack( $EV_FROM_INTERFACE, $tile_tag );
            $self->_raw_add_item_to_hand( $EV_FROM_INTERFACE, $loc_tag . ':' . $tile_tag );
        }
    }

    $self->_raw_set_allowed_race_actions( $EV_FROM_INTERFACE, 'place_tile', 'discard_tile' );

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_explore_place_tile {
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }












    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_explore_discard_tile {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    my $tile_tag_w_loc = $args{'tile_tag'};
    my $race = $self->race_of_current_user();

    unless ( $race->in_hand()->contains( $tile_tag_w_loc ) ) {
        $self->set_error( 'Invalid Tile Tag' );
        return 0;
    }

    my ( $loc_x, $loc_y, $tile_tag ) = split( /:/, $tile_tag_w_loc, 3 );

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $tile_tag_w_loc );
    $self->_raw_discard_tile( $EV_FROM_INTERFACE, $tile_tag );

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE );

    if ( $race->action_count() < )













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
