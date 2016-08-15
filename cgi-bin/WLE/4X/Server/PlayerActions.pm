package WLE::4X::Server::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;


#############################################################################

sub action_use_colony_ship {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    unless ( defined( $args{'resource_type'} ) ) {
        $self->set_error( 'Missing Resource Type' );
        return 0;
    }

    if ( $self->acting_player()->race()->colony_ships_available() > 0 ) {
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

    if ( $self->acting_player()->race()->resource_track_of( $type )->available_to_spend() < 1 ) {
        $self->set_error( 'No Available Cubes' );
        return 0;
    }

    $self->_raw_use_colony_ship( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tile_tag, $type, $advanced );

    return 1;
}



#############################################################################

sub action_pass_action {
    my $self            = shift;

    $self->_raw_player_pass_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );
    $self->_raw_next_player( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    if ( $self->waiting_on_player_id() == -1 ) {

        my $combat_tile = $self->board()->outermost_combat_tile();

        unless ( $combat_tile eq '' ) {
            $self->_raw_start_combat_phase( $EV_FROM_INTERFACE );
        }




    }

    return 1;
}

#############################################################################

sub action_explore {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'loc_x'} ) && defined( $args{'loc_y'} ) ) {
        $self->set_error( 'Missing Location Information' );
        return 0;
    }

    my $loc_x = $args{'loc_x'};
    my $loc_y = $args{'loc_y'};
    my $loc_tag = $loc_x . ':' . $loc_y;

    my @explorables = $self->board()->explorable_spaces_for_race( $self->acting_player()->race_tag() );

    unless ( matches_any( $loc_tag, @explorables ) ) {
        $self->set_error( 'Invalid Exploration Location' );
        return 0;
    }

    my $stack_id = $self->board()->stack_from_location( $loc_x, $loc_y );

    my $tiles_to_draw = ( $self->acting_player()->race()->provides( 'spec_descendants') ) ? 2 : 1;

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
            $self->_raw_add_item_to_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $loc_tag . ':' . $tile_tag );
        }
    }

    $self->_raw_spend_influence( $EV_FROM_INTERFACE, $self->acting_player()->id() );
    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'place_tile', 'discard_tile' );

    return 1;
}

#############################################################################

sub action_explore_place_tile {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    my $tile_tag = $args{'tile_tag'};

    my $flag_tile_in_hand = 0;
    my $tile_tag_w_loc = '';

    foreach my $in_hand ( $self->acting_player()->in_hand()->items() ) {
        if ( $in_hand =~ m { : $tile_tag $ }xs ) {
            $flag_tile_in_hand = 1;
            $tile_tag_w_loc = $in_hand;
            last;
        }
    }

    unless ( $flag_tile_in_hand ) {
        $self->set_error( 'Invalid Tile Tag' );
        return 0;
    }

    unless ( defined( $args{'warp'} ) ) {
        $self->set_error( 'Missing Rotation Information' );
        return 0;
    }

    my $warps = $args{'warp'};

    my ( $loc_x, $loc_y ) = split( /:/, $tile_tag_w_loc );

    my $tile = $self->tiles()->{ $tile_tag };

    if ( length( $warps ) == 6 ) {
#        print STDERR "\nConverting $warps to ";
        $warps = unpack( "N", pack( "B32", substr( "0" x 32 . reverse( $warps ), -32 ) ) );
#        print STDERR $warps;
    }

    unless ( $tile->are_new_warp_gates_valid( $warps ) ) {
        $self->set_error( 'Invalid Rotation Information' );
        return 0;
    }

    my $original_warps = $tile->warps();
    $tile->set_warps( $warps );

    my $valid_rotation = 0;
    my $has_wormhole = $self->acting_player()->race()->has_technology( 'tech_wormhole_generator' );

    foreach my $direction ( 0 .. 5 ) {
#        print STDERR "\nChecking direction $direction ... ";

        my $comp_direction = ( $direction + 3 ) % 6;

        my $adjacent_tile = $self->board()->tile_in_direction( $loc_x, $loc_y, $direction );

        if ( defined( $adjacent_tile ) ) {

#            print STDERR "found tile " . $adjacent_tile->tag() . ' ... ';

            if ( $adjacent_tile->has_explorer( $self->acting_player()->race->tag() ) ) {

#                print STDERR "has explorer ... ";

                my $here_warp = $tile->has_warp_on_side( $direction );
                my $there_warp = $adjacent_tile->has_warp_on_side( $comp_direction );

#                print STDERR 'here: ' . $here_warp . '  there: ' . $there_warp . ' ... ';

                if ( $here_warp && $there_warp ) {
#                    print STDERR 'has matching warps ... ';
                    $valid_rotation = 1;
                    last;
                }
                elsif ( $has_wormhole && ( $here_warp || $there_warp ) ) {
#                    print STDERR "has wormhole and one warp ... ";
                    $valid_rotation = 1;
                    last;
                }
            }
        }
    }

    unless ( $valid_rotation ) {
        $tile->set_warps( $original_warps );
        $self->set_error( 'Invalid Rotation for Location' );
        return 0;
    }

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tile_tag_w_loc );

    $self->_raw_place_tile_on_board( $EV_FROM_INTERFACE, $tile_tag, $loc_x, $loc_y, $warps );

    $tile->add_starting_ships();

    if ( $tile->ships()->count() < 1 || $self->acting_player()->race()->provides( 'spec_descendants') ) {
        if ( defined( $args{'influence'} ) ) {
            if ( $args{'influence'} eq '1' ) {
                $self->_raw_influence_tile( $EV_FROM_INTERFACE, $self->acting_player()->race->tag(), $tile_tag );
            }
        }
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    my @tiles_still_in_hand = $self->acting_player()->in_hand()->items();
    foreach my $tile_tag ( @tiles_still_in_hand ) {
        $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tile_tag );
        $self->_raw_discard_tile( $EV_FROM_INTERFACE, $tile_tag );
    }

    if ( $self->acting_player()->race()->action_count() < $self->acting_player()->race()->maximum_action_count( $ACT_EXPLORE ) ) {
        if ( $self->acting_player()->race()->can_explore() ) {
            $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_explore', 'finish_turn' );
        }
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_explore_discard_tile {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    my $tile_tag_w_loc = $args{'tile_tag'};

    unless ( $self->acting_player()->in_hand()->contains( $tile_tag_w_loc ) ) {
        $self->set_error( 'Invalid Tile Tag' );
        return 0;
    }

    my ( $loc_x, $loc_y, $tile_tag ) = split( /:/, $tile_tag_w_loc, 3 );

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tile_tag_w_loc );
    $self->_raw_discard_tile( $EV_FROM_INTERFACE, $tile_tag );

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    if ( $self->acting_player()->in_hand()->count() > 0 ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'discard_tile', 'place_tile' );
    }
    elsif ( $self->acting_player()->race()->action_count() < $self->acting_player()->race()->maximum_action_count( $ACT_EXPLORE ) ) {
        if ( $self->acting_player()->race()->can_explore() ) {
            $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_explore', 'finish_turn' );
        }
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_influence {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'from'} ) ) {
        $self->set_error( 'Missing From Element' );
        return 0;
    }

    my $influence_from = $args{'from'};

    if ( $influence_from eq 'track' ) {

        if ( $self->acting_player()->race()->resource_track_of( $RES_INFLUENCE )->available_to_spend() < 1 ) {
            $self->set_error( 'No Influence to spend' );
            return 0;
        }
    }
    elsif ( $influence_from ne 'nowhere' ) {

        my $tile = $self->tiles()->{ $influence_from };

        unless ( defined( $tile ) ) {
            $self->set_error( 'Invalid Source Tile' );
            return 0;
        }

        unless ( $tile->owner_id() == $self->acting_player()->id() ) {
            $self->set_error( 'Tile not owned by player' );
            return 0;
        }
    }

    $self->_raw_pick_up_influence( $EV_FROM_INTERFACE, $self->acting_player()->id(), $influence_from );

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    my @allowed = ( 'unflip_colony_ship', 'finish_turn' );

    if ( $self->acting_player()->race()->action_count() < $self->acting_player()->race()->maximum_action_count( $ACT_INFLUENCE ) ) {
        push( @allowed, 'action_influence' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), @allowed );

    return 1;
}

############################################################################

sub action_influence_unflip_colony_ship {
    my $self            = shift;
    my %args            = @_;

    if ( $self->acting_player()->race()->colony_ships_used() < 1 ) {
        $self->set_error( 'No Colony Ships to flip' );
        return 0;
    }

    $self->_raw_unuse_colony_ship( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    if (
        $self->acting_player()->race()->colony_ships_used() == 0
        || $self->acting_player()->race()->colony_flip_count() >= $self->acting_player()->race()->maximum_colony_flip_count()
    ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_influence', 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_research {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'tech_tag'} ) ) {
        $self->set_error( 'Missing Tech Item' );
        return 0;
    }

    my $tech_tag = $args{'tech_tag'};

    unless ( $self->tech_bag()->contains( $tech_tag ) ) {
        $self->set_error( 'Tech is unavailable' );
        return 0;
    }

    my $provides = $self->techs()->{ $tech_tag }->provides();

    if ( $self->acting_player()->race()->has_technology( $provides ) ) {
        $self->set_error( 'Race already has technology' );
        return 0;
    }

    my $tech = $self->techs()->{ $tech_tag };

    unless ( defined( $args{'destination_type'} ) ) {
        $self->set_error( 'Missing destination track' );
        return 0;
    }

    my $dest_type = enum_from_tech_text( $args{'destination_type'} );
    if ( $dest_type == $TECH_UNKNOWN ) {
        $self->set_error( 'Invalid destination type' );
        return 0;
    }

    unless ( $tech->category() == $TECH_WILD || $tech->category() == $dest_type ) {
        $self->set_error( 'Tech may not be placed there' );
        return 0;
    }

    if ( $self->acting_player()->race()->tech_track_of( $dest_type )->available_spaces() < 1 ) {
        $self->set_error( 'No spaces left on tech track' );
        return 0;
    }

    my $credits = $self->acting_player()->race()->tech_track_of( $dest_type )->current_credit();

    my $cost = $tech->base_cost();

    if ( $cost < $tech->min_cost() ) {
        $cost = $tech->min_cost();
    }

    if ( $self->acting_player()->race()->resource_count( $RES_SCIENCE ) < $cost ) {
        $self->set_error( 'Not enough science to purchase resource' );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    $self->_raw_buy_technology( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tech->tag(), $dest_type );

    if ( $self->acting_player()->race()->action_count() < $self->acting_player()->race()->maximum_action_count( $ACT_RESEARCH ) ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_research', 'finish_turn' );
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_upgrade {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'class'} ) ) {
        $self->set_error( 'Missing Ship Class' );
        return 0;
    }

    my $template = $self->acting_player()->race()->template_of_class( $args{'class'} );

    unless ( defined( $template ) ) {
        $self->set_error( 'Invalid Ship Template' );
        return 0;
    }

    unless ( defined( $args{'component'} ) ) {
        $self->set_error( 'Missing Component' );
        return 0;
    }

    my $component = $self->ship_components( $args{'component'} );

    unless ( defined( $component ) ) {
        $self->set_error( 'Invalid Component' );
        return 0;
    }

    unless ( $self->acting_player()->race()->component_overflow()->contains( $component->tag() ) ) {
        if ( $component->tech_required() ne '' ) {
            unless ( $self->acting_player()->race()->has_technology( $component->tech_required() ) ) {
                $self->set_error( 'Missing Technology Requirement' );
                return 0;
            }
        }
    }

    my $replaces_component = '';

    if ( defined( $args{'replaces_component'} ) ) {
        $replaces_component = $args{'replaces_component'};
    }

    my $template_copy = $template->copy_of( 'copy_tag' );

    my $error = '';
    unless ( $template_copy->add_component( $component->tag(), $replaces_component, \$error ) ) {
        $self->set_error( $error );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    $self->_raw_upgrade_ship_component( $EV_FROM_INTERFACE, $self->acting_player()->id(), $template->tag(), $component->tag(), $replaces_component );

    if (
        defined( $args{'as_react'} )
        || $self->acting_player()->race()->action_count() >= $self->acting_player()->race()->maximum_action_count( $ACT_UPGRADE )
    ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id_tag(), 'action_upgrade', 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_build {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Location' );
        return 0;
    }

    my $tile_tag = $args{'tile_tag'};

    unless ( defined( $args{'class'} ) ) {
        $self->set_error( 'Missing Ship Class' );
        return 0;
    }

    my $class = $args{'class'};

    my $tile = $self->tiles()->{ $tile_tag };

    unless ( $tile->owner_id() == $self->acting_player() ) {
        $self->set_error( 'Invalid Tile' );
        return 0;
    }

    my $template = $self->acting_player()->race()->template_of_class( $class );

    unless ( $self->has_option( 'option_unlimited_ships' ) ) {
        if ( $template->count() == 0 ) {
            $self->set_error( 'Unable to build another ship of that class' );
            return 0;
        }
    }

    my $cost = $template->cost();

    if ( $cost > $self->acting_player()->race()->resource_count( $RES_MINERALS ) ) {
        $self->set_error( 'Unable to afford ship of type' );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    $self->_raw_spend_resource( $EV_FROM_INTERFACE, $self->acting_player->id(), $RES_MINERALS, $template->cost() );
    $self->_raw_create_ship_on_tile( $EV_FROM_INTERFACE, $tile_tag, $template->tag(), $self->acting_player()->id() );

    if (
        defined( $args{'as_react'} )
        || $self->acting_player()->race()->action_count() >= $self->acting_player()->race()->maximum_action_count( $ACT_BUILD )
    ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_build', 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_move {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'ship_tag'} ) ) {
        $self->set_error( 'Missing Ship Tag' );
        return 0;
    }

    my $ship = $self->ships()->{ $args{'ship_tag'} };

    unless ( defined( $ship ) ) {
        $self->set_error( 'Invalid Ship Tag' );
        return 0;
    }

    unless ( $ship->owner_id() == $self->acting_player()->id() ) {
        $self->set_error( 'Ship not owned by user' );
        return 0;
    }

    unless ( defined( $args{'origin'} ) ) {
        $self->set_error( 'Missing Origin Tag' );
        return 0;
    }

    my $origin_tag = $args{'origin'};

    my $location = $self->board()->location_of_tile( $origin_tag );

    if ( $location eq '' ) {
        $self->set_error( 'Invalid Origin Tag' );
        return 0;
    }

    unless ( defined( $args{'destination'} ) ) {
        $self->set_error( 'Missing Destination Tag' );
        return 0;
    }

    my $destination_tag = $args{'destination'};

    $location = $self->board()->location_of_tile( $destination_tag );

    if ( $location eq '' ) {
        $self->set_error( 'Invalid Destination Tag' );
        return 0;
    }

    my $reachable = $self->board()->tile_is_within_distance(
        $self->acting_player()->id(),
        $origin_tag,
        $destination_tag,
        $ship->total_movement(),
        $ship->template()->provides( 'jump_drive' ),
        $self->acting_player()->race()->has_technology( 'tech_wormhole_generator' ),
    );

    unless ( $reachable ) {
        $self->set_error( 'Tile Not Reachable' );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    $self->_raw_remove_ship_from_tile( $EV_FROM_INTERFACE, $origin_tag, $ship->tag() );
    $self->_raw_add_ship_to_tile( $EV_FROM_INTERFACE, $destination_tag, $ship->tag() );

    if (
        defined( $args{'as_react'} )
        || $self->acting_player()->race()->action_count() >= $self->acting_player()->race()->maximum_action_count( $ACT_MOVE )
    ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'finish_turn' );
    }
    else {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), 'action_move', 'finish_turn' );
    }

    return 1;
}

#############################################################################

sub action_finish_turn {
    my $self            = shift;
    my %args            = @_;

    $self->_raw_next_player( $EV_FROM_INTERFACE, $self->acting_player()->id() );

    return 1;
}


#############################################################################

sub action_react_upgrade {
    my $self            = shift;
    my %args            = @_;

    return $self->action_upgrade( %args, 'as_react' => 1 );
}

#############################################################################

sub action_react_build {
    my $self            = shift;
    my %args            = @_;

    return $self->action_build( %args, 'as_react' => 1 );
}


#############################################################################

sub action_react_move {
    my $self            = shift;
    my %args            = @_;

    return $self->action_move( %args, 'as_react' => 1 );
}

#############################################################################

sub action_interrupt_place_influence_token {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'to'} ) ) {
        $self->set_error( 'Missing To Element' );
        return 0;
    }

    my $influence_to = $args{'to'};

    if ( $influence_to eq 'track' ) {
        $self->_raw_return_influence_to_track( $EV_FROM_INTERFACE, $self->acting_player()->id() );
    }
    else {
        my $tile = $self->tiles()->{ $influence_to };
        unless ( defined( $tile ) ) {
            $self->set_error( 'Invalid Destination' );
            return 0;
        }

        if ( $tile->owner_id() > -1 ) {
            $self->set_error( 'Tile Already Owned' );
            return;
        }

        my $location_of_tile = $self->board()->location_of_tile( $influence_to );

        if ( $location_of_tile eq '' ) {
            $self->set_error( 'Invalid Tile' );
            return 0;
        }

        unless ( $self->board()->tile_is_influencible( $influence_to ) ) {
            $self->set_error( 'No Path Available' );
            return 0;
        }

        $self->_raw_influence_tile( $EV_FROM_INTERFACE, $self->acting_player()->race_tag(), $influence_to );

        unless ( $tile->has_ancient_cruiser() ) {
            foreach my $discovery_tag ( $tile->discoveries() ) {
                $self->_raw_remove_discovery_from_tile( $EV_FROM_INTERFACE, $influence_to, $discovery_tag );
                $self->_raw_add_item_to_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tile->tag() . ':' . $discovery_tag );
            }
        }

    }

    return 1;
}

#############################################################################

sub action_interrupt_replace_cube {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->acting_player()->in_hand()->count() > 0 ) {
        $self->set_error( 'Nothing in hand' );
        return 0;
    }

    unless ( defined( $args{'destination'} ) ) {
        $self->set_error( 'Missing destination information' );
        return 0;
    }

    my $dest_type = $args{'destination'};

    unless ( matches_any( $dest_type, $RES_MONEY, $RES_SCIENCE, $RES_MINERALS ) ) {
        $self->set_error( 'Invalid destination track' );
        return 0;
    }

    unless ( defined( $args{'cube_type'} ) ) {
        $self->set_error( 'Missing cube type' );
        return 0;
    }

    my $cube_type = $args{'cube_type'};

    unless ( $self->acting_player()->in_hand()->contains( 'cube:' . $cube_type ) ) {
        $self->set_error( 'Not holding cube of that type' );
        return 0;
    }

    unless ( $self->acting_player()->race()->resource_track_of( $dest_type )->available_spaces() > 0 ) {
        $self->set_error( 'No spaces available of that type' );
        return 0;
    }

    unless ( $cube_type == $dest_type || $cube_type == $RES_WILD ) {
        if ( $self->acting_player()->race()->resource_track_of( $cube_type )->available_spaces() > 0 ) {
            $self->set_error( 'Invalid track for cube' );
            return 0;
        }
    }

    $self->_raw_place_cube_on_track( $EV_FROM_INTERFACE, $self->acting_player()->id(), $dest_type );

    my @allowed = ( 'unflip_colony_ship', 'finish_turn' );

    if ( $self->acting_player()->race()->action_count() < $self->acting_player()->race()->maximum_action_count( $ACT_INFLUENCE ) ) {
        push( @allowed, 'action_influence' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $self->acting_player()->id(), @allowed );

    return 1;
}

############################################################################

sub action_interrupt_choose_discovery {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'discovery_tag'} ) ) {
        $self->set_error( 'Missing Discovery tag' );
        return 0;
    }

    my $discovery_tag = $args{'discovery_tag'};
    my $flag_as_vp = 0;

    if ( defined( $args{'as_vp'} ) ) {
        $flag_as_vp = $args{'as_vp'};
    }

    my $full_tag = '';
    my $tile_tag = '';

    foreach my $item ( $self->active_player()->in_hand()->items() ) {
        my ( $tile_tag, $tag ) = split( /:/, $item );
        if ( defined( $tag ) ) {
            if ( $tag eq $discovery_tag ) {
                $full_tag = $item;
            }
        }
    }

    if ( $full_tag eq '' ) {
        $self->set_error( 'Not holding Discovery' );
        return 0;
    }

    ( $tile_tag, $discovery_tag ) = split( /:/, $full_tag );

    $self->_raw_use_discovery( $EV_FROM_INTERFACE, $self->active_player()->id(), $discovery_tag, $tile_tag, $flag_as_vp );

    return 1;
}

############################################################################

sub action_interrupt_select_technology {
    my $self            = shift;
    my %args            = @_;

    unless ( defined( $args{'chosen_tech'} ) ) {
        $self->set_error( 'Missing Tech Choice' );
        return 0;
    }

    my $tech_tag = $args{'chosen_tech'};

    unless ( $self->acting_player()->in_hand()->contains( $tech_tag ) ) {
        $self->set_error( 'Invalid Tech Choice' );
        return 0;
    }

    my $tech_type = $self->technologies()->{ $tech_tag }->category();

    if ( $tech_type == $TECH_WILD ) {

        unless ( defined( $args{'tech_type'} ) ) {
            $self->set_error( 'No Track Chosen' );
            return 0;
        }

        if ( $args{'tech_type'} == $TECH_WILD || $args{'tech_type'} == $TECH_UNKNOWN ) {
            $self->set_error( 'Invalid Tech Track' );
            return 0;
        }
    }

    foreach my $item ( $self->acting_player()->in_hand()->items() ) {
        if ( defined( $self->technologies()->{ $item } ) ) {
            $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $self->acting_player()->id(), $item );
        }
    }

    $self->_raw_add_to_tech_track( $EV_FROM_INTERFACE, $self->acting_player()->id(), $tech_tag, $tech_type );
    $self->_raw_remove_from_available_tech( $EV_FROM_INTERFACE, $tech_tag );

    return 1;
}



#############################################################################
#############################################################################
1