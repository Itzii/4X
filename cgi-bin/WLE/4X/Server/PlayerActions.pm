package WLE::4X::Server::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;


#############################################################################

sub action_pass_action {
    my $self            = shift;

    my $player = $self->acting_player();
    my $race = $player->race();

    $self->_raw_player_pass_action( $EV_FROM_INTERFACE, $player->id() );
    $self->_raw_next_player( $EV_FROM_INTERFACE, $player->id() );

#    print STDERR "\nWaiting On Player: " . $self->waiting_on_player_id();

    if ( $self->waiting_on_player_id() == -1 ) {

        $self->_raw_clear_pass_flags( $EV_FROM_INTERFACE );

        my $combat_tile = $self->board()->outermost_combat_tile();

#        print STDERR " combat tile: " . $combat_tile;

        if ( $combat_tile eq '' ) {
            $self->_raw_start_upkeep( $EV_FROM_INTERFACE );
        }
        else {
            $self->_raw_start_combat_phase( $EV_FROM_INTERFACE );
        }
    }

    return 1;
}


#############################################################################

sub action_use_colony_ship {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    unless ( defined( $args{'resource_type'} ) ) {
        $self->set_error( 'Missing Resource Type' );
        return 0;
    }

    if ( $race->colony_ships_available() < 1 ) {
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

    if ( $race->resource_track_of( $type )->available_to_spend() < 1 ) {
        $self->set_error( 'No Available Cubes' );
        return 0;
    }

    $self->_raw_use_colony_ship( $EV_FROM_INTERFACE, $player->id(), $tile_tag, $type, $advanced );

    if ( $player->race()->colony_ships_available() < 1 ) {
        $self->_raw_remove_allowed_player_action( $EV_FROM_INTERFACE, $player->id(), 'use_colony_ship' );
    }

    return 1;
}

#############################################################################

sub action_explore {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    my $loc_tag = '';
    my $loc_x = 0;
    my $loc_y = 0;

    if ( defined( $args{'location'} ) ) {
        $loc_tag = $args{'location'};
        ( $loc_x, $loc_y ) = split( /:/, $loc_tag );
    }
    elsif ( defined( $args{'loc_x'} && defined( $args{'loc_y'} ) ) ) {
        $loc_x = $args{'loc_x'};
        $loc_y = $args{'loc_y'};
        $loc_tag = $loc_x . ':' . $loc_y;
    }
    else {
        $self->set_error( 'Missing Location Information' );
        return 0;
    }

    my @explorables = $self->board()->explorable_spaces_for_player( $player->id() );

    unless ( matches_any( $loc_tag, @explorables ) ) {
        $self->set_error( 'Invalid Exploration Location' );
        return 0;
    }

    my $stack_id = $self->board()->stack_from_location( $loc_x, $loc_y );

    my $tiles_to_draw = ( $race->provides( 'spec_descendants') ) ? 2 : 1;

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
            $self->_raw_add_item_to_hand( $EV_FROM_INTERFACE, $player->id(), $loc_tag . ':' . $tile_tag );
        }
    }

    $self->_raw_spend_influence( $EV_FROM_INTERFACE, $player->id() );

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), 'place_tile', 'discard_tile' );

    return 1;
}

#############################################################################

sub action_explore_place_tile {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    my $tile_tag = '';
    my $tile_tag_w_loc = '';

    if ( $player->in_hand()->count() > 1 ) {

        unless ( defined( $args{'tile_tag'} ) ) {
            $self->set_error( 'Missing Tile Tag' );
            return 0;
        }

        $tile_tag = $args{'tile_tag'};

        unless ( matches_any( $tile_tag, $player->bare_in_hand() ) ) {
            $self->set_error( 'Invalid Tile Tag' );
            return 0;
        }

        foreach my $item ( $player->in_hand()->items() ) {
            my @parts = split( /:/, $item );
            if ( $parts[ -1 ] eq $tile_tag ) {
                $tile_tag_w_loc = $item;
            }
        }
    }
    elsif ( $player->has_tile_in_hand() ) {
        $tile_tag_w_loc = ( $player->in_hand()->items() )[ 0 ];
        my @parts = split( /:/, $tile_tag_w_loc );
        $tile_tag = $parts[ -1 ];
    }
    else {
        $self->set_error( 'No Tile In Hand' );
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
    my $has_wormhole = $race->has_technology( 'tech_wormhole_generator' );

    foreach my $direction ( 0 .. 5 ) {
#        print STDERR "\nChecking direction $direction ... ";

        my $comp_direction = ( $direction + 3 ) % 6;

        my $adjacent_tile = $self->board()->tile_in_direction( $loc_x, $loc_y, $direction );

        if ( defined( $adjacent_tile ) ) {

#            print STDERR "found tile " . $adjacent_tile->tag() . ' ... ';

            if ( $adjacent_tile->has_explorer( $player->id() ) ) {

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

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $player->id(), $tile_tag_w_loc );

    $self->_raw_place_tile_on_board( $EV_FROM_INTERFACE, $tile_tag, $loc_x, $loc_y, $warps );

    if ( $tile->ships()->count() < 1 || $race->provides( 'spec_descendants') ) {
#        print STDERR "\nChecking to influence ... ";
        if ( defined( $args{'influence'} ) ) {
#            print STDERR "influencing defined ... ";
            if ( $args{'influence'} eq '1' ) {
#                print STDERR "calling raw method.";
                $self->_raw_influence_tile( $EV_FROM_INTERFACE, $player->id(), $tile_tag, 1 );
            }
        }
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    my @tiles_still_in_hand = $player->in_hand()->items();
    foreach my $tile_tag ( @tiles_still_in_hand ) {
        $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $player->id(), $tile_tag );
        $self->_raw_discard_tile( $EV_FROM_INTERFACE, $tile_tag );
    }

    my @actions = ();

    if ( $tile->discovery_count() > 0 && $tile->owner_id() == $player->id() ) {
        $self->_raw_add_tile_discoveries_to_hand( $EV_FROM_INTERFACE, $player->id(), $tile->tag() );

    }

    @actions = ( 'finish_turn' );

    if ( $race->action_count() < $race->maximum_action_count( $ACT_EXPLORE ) ) {
        if ( $race->can_explore() ) {
            push( @actions, 'action_explore' );
        }
    }

    if ( $race->colony_ships_available() > 0 ) {
        push( @actions, 'use_colony_ship' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

    return 1;
}

#############################################################################

sub action_explore_discard_tile {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    my $tile_tag = '';
    my $tile_tag_w_loc = '';

    if ( $player->in_hand()->count > 1 ) {

        unless ( defined( $args{'tile_tag'} ) ) {
            $self->set_error( 'Missing Tile Tag' );
            return 0;
        }

        $tile_tag = $args{'tile_tag'};

        unless ( matches_any( $tile_tag, $player->bare_in_hand() ) ) {
            $self->set_error( 'Invalid Tile Tag' );
            return 0;
        }

        foreach my $item ( $player->in_hand()->items() ) {
            my @parts = split( /:/, $item );
            if ( $parts[ -1 ] eq $tile_tag ) {
                $tile_tag_w_loc = $item;
            }
        }
    }
    elsif ( $player->has_tile_in_hand() ) {
        $tile_tag_w_loc = ( $player->in_hand()->items() )[ 0 ];
        my @parts = split( /:/, $tile_tag_w_loc );
        $tile_tag = $parts[ -1 ];
    }
    else {
        $self->set_error( 'No Tile In Hand' );
        return 0;
    }

    $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $player->id(), $tile_tag_w_loc );
    $self->_raw_discard_tile( $EV_FROM_INTERFACE, $tile_tag );

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    my @actions = ();

    if ( $player->in_hand()->count() > 0 ) {
        push( @actions, 'discard_tile', 'place_tile' );
    }
    else {
        push( @actions, 'finish_turn' );

        if (
            $race->action_count() < $race->maximum_action_count( $ACT_EXPLORE )
            && $race->can_explore()
        ) {
            push( @actions, 'action_explore' );
        }

        if ( $race->colony_ships_available() > 0 ) {
            push( @actions, 'use_colony_ship' );
        }
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

    return 1;
}

#############################################################################

sub action_influence {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'from'} ) ) {
        $self->set_error( 'Missing From Element' );
        return 0;
    }

    my $influence_from = $args{'from'};

    if ( $influence_from eq 'track' ) {

        if ( $race->resource_track_of( $RES_INFLUENCE )->available_to_spend() < 1 ) {
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

        unless ( $tile->owner_id() == $player->id() ) {
            $self->set_error( 'Tile not owned by player' );
            return 0;
        }
    }

    $self->_raw_spend_influence( $EV_FROM_INTERFACE, $player->id() );

    unless ( $influence_from eq 'nowhere' ) {
        $self->_raw_pick_up_influence( $EV_FROM_INTERFACE, $player->id(), $influence_from );
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    my @allowed = ( 'finish_turn' );

    if ( $race->colony_ships_available() > 0 ) {
        push( @allowed, 'use_colony_ship' );
    }

    if ( $race->colony_flip_available() > 0 ) {
        push( @allowed, 'unflip_colony_ship' );
    }

    if ( $race->action_count() < $race->maximum_action_count( $ACT_INFLUENCE ) ) {
        push( @allowed, 'action_influence' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @allowed );

    return 1;
}

############################################################################

sub action_influence_unflip_colony_ship {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    if ( $race->colony_ships_used() < 1 ) {
        $self->set_error( 'No Colony Ships to flip' );
        return 0;
    }

    $self->_raw_unuse_colony_ship( $EV_FROM_INTERFACE, $player->id() );

    my @allowed = ( 'finish_turn' );

    if ( $race->colony_ships_available() > 0 ) {
        push( @allowed, 'use_colony_ship' );
    }

    if ( $race->colony_flip_available() > 0 ) {
        push( @allowed, 'unflip_colony_ship' );
    }

    if ( $race->action_count() < $race->maximum_action_count( $ACT_INFLUENCE ) ) {
        push( @allowed, 'action_influence' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @allowed );

    return 1;
}

#############################################################################

sub action_research {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'tech_tag'} ) ) {
        $self->set_error( 'Missing Tech Item' );
        return 0;
    }

    my $flag_tech_is_valid = 0;
    my $tech = undef;

    foreach my $tag ( $self->tech_bag()->items() ) {
        $tech = $self->technology()->{ $tag };
        if ( $tech->provides() eq $args{'tech_tag'} ) {
            $flag_tech_is_valid = 1;
            last;
        }
    }

    unless ( $flag_tech_is_valid ) {
        $self->set_error( 'Tech is unavailable' );
        return 0;
    }

    if ( $race->has_technology( $tech->provides() ) ) {
        $self->set_error( 'Race already has technology' );
        return 0;
    }

    my $dest_type = $tech->category();

    if ( $tech->category() == $TECH_WILD ) {
        unless ( defined( $args{'destination_type'} ) ) {
            $self->set_error( 'Missing destination track' );
            return 0;
        }

        $dest_type = enum_from_tech_text( $args{'destination_type'} );
        if ( $dest_type == $TECH_UNKNOWN ) {
            $self->set_error( 'Invalid destination type' );
            return 0;
        }
    }

    if ( $race->tech_track_of( $dest_type )->available_spaces() < 1 ) {
        $self->set_error( 'No spaces left on tech track' );
        return 0;
    }

    my $credits = $race->tech_track_of( $dest_type )->current_credit();

    my $cost = $tech->base_cost();

    if ( $cost < $tech->min_cost() ) {
        $cost = $tech->min_cost();
    }

    if ( $race->resource_count( $RES_SCIENCE ) < $cost ) {
        $self->set_error( 'Not enough science to purchase resource' );
        return 0;
    }

    $self->_raw_spend_influence( $EV_FROM_INTERFACE, $player->id() );

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    $self->_raw_buy_technology( $EV_FROM_INTERFACE, $player->id(), $tech->tag(), $dest_type );

    my @actions = ( 'finish_turn' );

    if ( $race->action_count() < $race->maximum_action_count( $ACT_RESEARCH ) ) {
        push( @actions, 'action_research' );
    }

    if ( $race->colony_ships_available() > 0 ) {
        push( @actions, 'use_colony_ship' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

    return 1;
}

#############################################################################

sub action_upgrade {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'class'} ) ) {
        $self->set_error( 'Missing Ship Class' );
        return 0;
    }

    my $template = $race->template_of_class( $args{'class'} );

    unless ( defined( $template ) ) {
        $self->set_error( 'Invalid Ship Template' );
        return 0;
    }

    unless ( defined( $args{'component'} ) ) {
        $self->set_error( 'Missing Component' );
        return 0;
    }

    my $component_tag = $args{'component'};

    unless ( $component_tag eq 'none' ) {

        my $component = $self->ship_components()->{ $component_tag };

        unless ( defined( $component ) ) {
            $self->set_error( 'Invalid Component' );
            return 0;
        }

        unless ( $race->component_overflow()->contains( $component_tag ) ) {
            if ( $component->tech_required() ne '' ) {
                unless ( $race->has_technology( $component->tech_required() ) ) {
                    $self->set_error( 'Missing Technology Requirement' );
                    return 0;
                }
            }
        }

        unless ( defined( $args{'slot_number'} ) ) {
            $self->set_error( 'Invalid Component Slot' );
            return 0;
        }

        my $slot_number = $args{'slot_number'};

        my $error = '';
        unless ( $template->add_component( $component->tag(), $slot_number, \$error, 0 ) ) {
            $self->set_error( $error );
            return 0;
        }

        $self->_raw_upgrade_ship_component( $EV_FROM_INTERFACE, $player->id(), $template->tag(), $component->tag(), $slot_number );
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    my @actions = ( 'downgrade_template', 'finish_turn' );

    unless ( defined( $args{'as_react'} ) ) {
        if ( $race->action_count() < $race->maximum_action_count( $ACT_UPGRADE ) ) {
            push( @actions, 'action_upgrade' );
        }
    }

    if ( $race->colony_ships_available() > 0 ) {
        push( @actions, 'use_colony_ship' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

    return 1;
}

#############################################################################

sub action_upgrade_downgrade {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'class'} ) ) {
        $self->set_error( 'Missing Ship Class' );
        return 0;
    }

    my $template = $race->template_of_class( $args{'class'} );

    unless ( defined( $template ) ) {
        $self->set_error( 'Invalid Ship Template' );
        return 0;
    }

    unless ( defined( $args{'slot_number'} ) ) {
        $self->set_error( 'Invalid Component Slot' );
        return 0;
    }

    my $slot_number = $args{'slot_number'};

    my $error = '';
    unless ( $template->remove_component( $slot_number, \$error, 0 ) ) {
        $self->set_error( $error );
        return 0;
    }

    $self->_raw_downgrade_ship_component( $EV_FROM_INTERFACE, $player->id(), $template->tag(), $slot_number );

    return 1;
}

#############################################################################

sub action_build {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

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

    unless ( $tile->owner_id() == $player->id() ) {
        $self->set_error( 'Invalid Tile' );
        return 0;
    }

    my $template = $race->template_of_class( $class );

    unless ( $self->has_option( 'option_unlimited_ships' ) ) {
        if ( $template->count() == 0 ) {
            $self->set_error( 'Unable to build another ship of that class' );
            return 0;
        }
    }

    my $cost = $template->cost();

    if ( $cost > $race->resource_count( $RES_MINERALS ) ) {
        $self->set_error( 'Unable to afford ship of type' );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    $self->_raw_spend_resource( $EV_FROM_INTERFACE, $player->id(), $RES_MINERALS, $template->cost() );
    $self->_raw_create_ship_on_tile( $EV_FROM_INTERFACE, $tile_tag, $template->tag(), $player->id() );

    my @actions = ( 'finish_turn' );

    unless ( defined( $args{'as_react'} ) ) {
        if ( $race->action_count() < $race->maximum_action_count( $ACT_BUILD ) ) {
            push( @actions, 'action_build' );
        }
    }

    if ( $race->colony_ships_available() > 0 ) {
        push( @actions, 'use_colony_ship' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

    return 1;
}

#############################################################################

sub action_move {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();


    unless ( defined( $args{'path'} ) ) {
        $self->set_error( 'Missing Path' );
        return 0;
    }

    my @path = split( ',', $args{'path'} );

    foreach my $tile_tag ( @path ) {
        my $location = $self->board()->location_of_tile( $tile_tag );
        if ( $location eq '' ) {
            $self->set_error( 'Invalid Path Element' );
            return 0;
        }
    }

    my $origin_tile = $self->tiles()->{ $path[ 0 ] };

    unless ( defined( $args{'class'} ) ) {
        $self->set_error( 'Missing Ship Class' );
        return 0;
    }

    my $ship = undef;

    foreach my $tile_ship_tag ( $origin_tile->ships()->items() ) {
        $ship = $self->ships()->{ $tile_ship_tag };
        if ( defined( $ship ) ) {
            if ( $ship->owner_id() == $player->id() && $ship->class() eq $args{'class'}  ) {
                last;
            }
        }
        $ship = undef;
    }

    unless ( defined( $ship ) ) {
        $self->set_error( 'No Ships Of Class In Origin' );
        return 0;
    }

    if ( scalar( @path ) - 1 > $ship->total_movement() ) {
        $self->set_error( 'Distance Too Great' );
        return 0;
    }

    my $reachable = $self->board()->valid_path_for_player_id(
        $player->id(),
        $ship->template()->does_provide( 'jump_drive' ),
        @path,
    );




    unless ( $reachable ) {
        $self->set_error( 'Tile Not Reachable' );
        return 0;
    }

    $self->_raw_increment_race_action( $EV_FROM_INTERFACE, $player->id() );

    $self->_raw_remove_ship_from_tile( $EV_FROM_INTERFACE, $origin_tag, $ship->tag() );
    $self->_raw_add_ship_to_tile( $EV_FROM_INTERFACE, $destination_tag, $ship->tag() );

    my @actions = ( 'finish_turn' );

    unless ( defined( $args{'as_react'} ) ) {
        if ( $race->action_count() < $race->maximum_action_count( $ACT_MOVE ) ) {
            push( @actions, 'action_move' );
        }
    }

    if ( $race->colony_ships_available() > 0 ) {
        push( @actions, 'use_colony_ship' );
    }

    $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), @actions );

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

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'to'} ) ) {
        $self->set_error( 'Missing To Element' );
        return 0;
    }

    my $influence_to = $args{'to'};

    if ( $influence_to eq 'track' ) {
        $self->_raw_return_influence_to_track( $EV_FROM_INTERFACE, $player->id() );
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

        unless ( $self->board()->tile_is_influencible( $influence_to, $player->id() ) ) {
            $self->set_error( 'No Path Available' );
            return 0;
        }

        $self->_raw_influence_tile( $EV_FROM_INTERFACE, $player->id(), $influence_to );
        $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $player->id(), 'influence_token' );

        unless ( $tile->has_ancient_cruiser() ) {
            foreach my $discovery_tag ( $tile->discoveries()->items() ) {
                $self->_raw_remove_discovery_from_tile( $EV_FROM_INTERFACE, $influence_to, $discovery_tag );
                $self->_raw_add_item_to_hand( $EV_FROM_INTERFACE, $player->id(), $tile->tag() . ':' . $discovery_tag );
            }
        }

    }

    return 1;
}

#############################################################################

sub action_interrupt_replace_cube {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( $player->in_hand()->count() > 0 ) {
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

    unless ( $player->in_hand()->contains( 'cube:' . $cube_type ) ) {
        $self->set_error( 'Not holding cube of that type' );
        return 0;
    }

    unless ( $race->resource_track_of( $dest_type )->available_spaces() > 0 ) {
        $self->set_error( 'No spaces available of that type' );
        return 0;
    }

    unless ( $cube_type == $dest_type || $cube_type == $RES_WILD ) {
        if ( $race->resource_track_of( $cube_type )->available_spaces() > 0 ) {
            $self->set_error( 'Invalid track for cube' );
            return 0;
        }
    }

    $self->_raw_place_cube_on_track( $EV_FROM_INTERFACE, $player->id(), $dest_type );

    return 1;
}

############################################################################

sub action_interrupt_choose_discovery {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

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

    foreach my $item ( $player->in_hand()->items() ) {
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

    $self->_raw_use_discovery( $EV_FROM_INTERFACE, $player->id(), $discovery_tag, $tile_tag, $flag_as_vp );

    return 1;
}

############################################################################

sub action_interrupt_select_technology {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'chosen_tech'} ) ) {
        $self->set_error( 'Missing Tech Choice' );
        return 0;
    }

    my $tech_tag = $args{'chosen_tech'};

    unless ( $player->in_hand()->contains( $tech_tag ) ) {
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

    foreach my $item ( $player->in_hand()->items() ) {
        if ( defined( $self->technologies()->{ $item } ) ) {
            $self->_raw_remove_item_from_hand( $EV_FROM_INTERFACE, $player->id(), $item );
        }
    }

    $self->_raw_add_to_tech_track( $EV_FROM_INTERFACE, $player->id(), $tech_tag, $tech_type );
    $self->_raw_remove_from_available_tech( $EV_FROM_INTERFACE, $tech_tag );

    return 1;
}

#############################################################################

sub action_pay_upkeep {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    my $income = $race->resource_track_of( $RES_MONEY )->track_value();
    my $upkeep_cost = - $race->resource_track_of( $RES_INFLUENCE )->track_value();

    if ( $upkeep_cost > $race->resource_count( $RES_MONEY ) + $income ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), 'pay_upkeep', 'pull_influence' );
        return 1;
    }

    $self->_raw_pay_upkeep( $EV_FROM_INTERFACE, $player->id() );
    $self->_raw_next_upkeep_player( $EV_FROM_INTERFACE, $player->id() );

    if ( $self->waiting_on_player_id() == -1 ) {
        $self->_pull_next_technologies();
        $self->_raw_start_cleanup( $EV_FROM_INTERFACE );
    }

    return 1;
}

#############################################################################

sub action_pull_influence {
    my $self            = shift;
    my %args            = @_;

    my $player = $self->acting_player();
    my $race = $player->race();

    unless ( defined( $args{'tile_tag'} ) ) {
        $self->set_error( 'Missing Tile Tag' );
        return 0;
    }

    my $tile = $self->tiles()->{ $args{'tile_tag'} };

    unless ( defined( $tile ) ) {
        $self->set_error( 'Invalid Tile Tag' );
        return 0;
    }

    unless ( $tile->owner_id() == $player->id() ) {
        $self->set_error( 'Not Tile Owner' );
        return 0;
    }

    $self->_raw_pick_up_influence( $EV_FROM_INTERFACE, $player->id(), $tile->tag() );
    $self->_raw_return_influence_to_track( $EV_FROM_INTERFACE, $player->id() );

    if ( $self->board()->player_owns_any_tile( $player->id() ) ) {
        $self->_raw_set_allowed_player_actions( $EV_FROM_INTERFACE, $player->id(), 'pay_upkeep', 'pull_influence' );
        return 1;
    }

    $self->_raw_eliminate_player( $EV_FROM_INTERFACE, $player->id() );
    $self->_raw_next_upkeep_player( $EV_FROM_INTERFACE );

    if ( $self->waiting_on_player_id() == -1 ) {
        $self->_pull_next_technologies();
        $self->_raw_start_cleanup( $EV_FROM_INTERFACE );
    }

    return 1;
}

#############################################################################

sub _pull_next_technologies {
    my $self            = shift;

    my @available_tech = ();

    my $tech_count = 0;
    while ( $tech_count < $self->tech_draw_count() && $self->tech_bag()->count() > 0 ) {
        my $tech_tag = $self->tech_bag()->select_random_item();

        $self->_raw_remove_from_tech_bag( $EV_FROM_INTERFACE, $tech_tag );
        $self->_raw_add_to_available_tech( $EV_FROM_INTERFACE, $tech_tag );

        unless ( $self->technology()->{ $tech_tag }->category() == $TECH_WILD ) {
            $tech_count++;
        }
    }

    return;
}

#############################################################################
#############################################################################
1
