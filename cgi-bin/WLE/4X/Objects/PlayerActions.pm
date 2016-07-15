package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;


#############################################################################

sub action_use_colony_ship {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    unless ( defined( $args{'resource_type'} ) ) {
        $self->set_error( 'Missing Resource Type' );
        return 0;
    }

    if ( $self->race_of_current_user()->colony_ships_available() > 0 ) {
        $self->set_error( 'No Available Colony Ships' );
        return 0;
    }

    my $tile_tag = $args{'tile_tag'};
    my $type = enum_from_resource_text( $args{'resource_type'} );
    my $advanced = 0;

    if ( defined( $args{'advanced'} ) ) {
        $advanced = $args{'advanced'};
    }

    my $tile = $self->tiles()->{ $tile_tag };

    unless ( defined( $tile ) ) {
        $self->set_error( 'Invalid Tile Tag' );
        return 0;
    }

    my $available = $tile->available_resource_spots( $type, $advanced );

    unless ( $available > 0 ) {
        $self->set_error( 'No Available Spots' );
        return 0;
    }

    if ( $race->track_of( $type )->available_to_spend() < 1 ) {
        $self->set_error( 'No Available Cubes' );
        return 0;
    }

    $self->_raw_use_colony_ship( $EV_FROM_INTERFACE, $tile_tag, $type, $advanced );

    $self->_save_state();
    $self->_close_all();

    return 1;
}



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

    unless ( defined( $args{'warp'} ) ) {
        $self->set_error( 'Missing Rotation Information' );
        return 0;
    }

    my ( $loc_x, $loc_y, $tile_tag ) = split( /:/, $tile_tag_w_loc, 3 );

    my $tile = $self->server()->tiles()->{ $tile_tag };

    unless ( $tile->are_new_warp_gates_valid( $args{'warp'} ) ) {
        $self->set_error( 'Invalid Rotation Information' );
        return 0;
    }

    my $valid_rotation = 0;
    my $has_wormhole = $race->has_technology( 'tech_wormhole_generator' );

    foreach my $direction ( 0 .. 5 ) {
        my $comp_direction = ( $direction + 3 ) % 6;

        my $adjacent_tile = $self->board()->tile_in_direction( $loc_x, $loc_y, $direction );

        if ( defined( $adjacent_tile ) ) {
            if ( $adjacent_tile->has_explorer( $race->tag() ) ) {

                my $here_warp = $tile->has_warp_on_side( $direction );
                my $there_warp = $adjacent_tile->has_warp_on_side( $comp_direction );

                if ( $here_warp && $there_warp ) {
                    $valid_rotation = 1;
                    last;
                }
                elsif ( $has_wormhole && ( $here_warp || $there_warp ) ) {
                    $valid_rotation = 1;
                    last;
                }
            }
        }
    }

    unless ( $valid_rotation ) {
        $self->set_error( 'Invalid Rotation for Location' );
        return 0;
    }

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $tile_tag_w_loc );

    $self->_raw_place_tile_on_board( $tile_tag, $loc_x, $loc_y, $args{'warp'} );

    $tile->add_starting_ships();

    if ( scalar( $tile->ships() ) < 1 || $race->provides( 'spec_descendants') ) {
        if ( $args{'influence'} eq '1' ) {
            $self->_raw_influence_tile( $race->tag(), $tile_tag );
        }
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE );

    my @tiles_still_in_hand = $race->in_hand()->items();
    foreach my $tile_tag ( @tiles_still_in_hand ) {
        $self->_raw_remove_item_from_hand( $tile_tag );
        $self->_raw_discard_tile( $tile_tag );
    }

    if ( $race->action_count() < $race->maximum_action_count( 'EXPLORE' ) ) {
        if ( $race->can_explore() ) {
            $self->_raw_set_allowed_race_actions( 'action_explore', 'finish_turn' );
        }
    }
    else {
        $self->_raw_set_allowed_race_actions( 'finish_turn' );
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

    if ( $race->in_hand()->count() > 0 ) {
        $self->_raw_set_allowed_race_actions( 'discard_tile', 'place_tile' );
    }
    elsif ( $race->action_count() < $race->maximum_action_count( 'EXPLORE' ) ) {
        if ( $race->can_explore() ) {
            $self->_raw_set_allowed_race_actions( 'action_explore', 'use_colony_ship', 'finish_turn' );
        }
    }
    else {
        $self->_raw_set_allowed_race_actions( 'finish_turn' );
    }

    $self->_save_state();
    $self->_close_all();

    return 1;
}

#############################################################################

sub action_influence {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'from'} ) ) {
        $self->set_error( 'Missing From Element' );
        return 0;
    }

    unless ( defined( $args{'to'} ) ) {
        $self->set_error( 'Missing To Element' );
        return 0;
    }

    my $race = $self->race_of_current_user();

    my $influence_from = $args{'from'};
    my $influence_to = $args{'to'};

    if ( $influence_from eq 'track' ) {
        my $tile = $self->tiles()->{ $influence_to };
        unless ( defined( $tile ) ) {
            $self->set_error( 'Invalid Destination' );
            return 0;
        }

        if ( $tile->owner_id() > -1 ) {
            $self->set_error( 'Tile Already Owned' );
            return;
        }

        if ( $race->track_of( $RES_INFLUENCE )->available_to_spend() < 1 ) {
            $self->set_error( 'No Influence to spend' );
            return 0;
        }

        my $location_of_tile = $self->board()->location_of_tile( $influence_to );

        if ( $location_of_tile eq '' ) {
            $self->set_error( 'Invalid Tile' );
            return 0;
        }

        my ( $loc_x, $loc_y ) = split( /:/, $self->board()->location_of_tile( $influence_to ) );



        my $tile_reachable = 0;

        foreach my $direction ( 0 .. 5 ) {
            my ( $loc_x2, $loc_y2 ) = $self->board()->location_in_direction( $loc_x, $loc_y, $direction );

            my $tile = $self->board()->tile_at_location( $loc_x2, $loc_y2 );

            if ( defined( $tile ) ) {
                if ( $self->board()->tile_pair_is_traversable( $race->tag(), $loc_x, $loc_y, $loc_x2, $loc_y2 ) ) {
                    if ( $tile->user_ship_count( $self->current_user() ) > 0 ) {
                        $tile_reachable = 1;
                    }
                }
            }
        }

        unless ( $tile_reachable ) {
            $self->set_error( 'No Path Available' );
            return 0;
        }

        # TODO all good - now influence








    }
    else {



    }







    $self->_raw_increment_race_action( $EV_FROM_INTERFACE );



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
