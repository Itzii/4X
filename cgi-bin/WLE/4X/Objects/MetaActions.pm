package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Objects::Element;
use WLE::4X::Objects::ShipComponent;

#############################################################################
#
# action_create_game - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# user          : required - integer
#
# long_name     : optional - descriptive name
# r_source_tags : list reference of source tags
# r_option_tags : list reference of option tags
#

sub action_create_game {
    my $self        = shift;
    my %args        = @_;

    $self->set_error( '' );

    if ( $self->_does_log_exist( $args{'log_id'} ) ) {
        $self->set_error( "Log with ID '" . $args{'log_id'} . "' already exists." );
        return 0;
    }

    unless ( $self->_set_log_id( $args{'log_id'} ) ) {
        return 0;
    }

    if ( scalar( @{ $args{'r_source_tags'} } ) == 0 ) {
        $self->set_error( 'Must have at least one source tag.' );
        return 0;
    }

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    $self->_raw_create_game(
        1,
        $args{'user'},
        $args{'long_name'},
        $args{'r_source_tags'},
        $args{'r_option_tags'},
    );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################
#
# action_add_source - args
#
# source_tag     : required - [a-zA-Z0-9_]
#

sub action_add_source {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'source_tag'} ) ) {
        $self->set_error( 'Missing Source Tag' );
        return 0;
    }

    unless ( $args{'source_tag'} =~ m{ ^ [a-zA-Z0-9_]+ $ }xs ) {
        $self->set_error( 'Invalid Source Tag' );
        return 0;
    }

    if ( WLE::Methods::Simple::matches_any( $args{'source_tag'}, $self->source_tags() ) ) {
        $self->set_error( 'Source Tag Already Exists' );
        return 0;
    }

    $self->_raw_add_source( 1, $args{'source_tag'} );
    $self->_save_state();

    $self->_close_all();

    return 1;

}

#############################################################################
#
# action_remove_source - args
#
# source_tag     : required - [a-zA-Z0-9_]
#

sub action_remove_source {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'source_tag'} ) ) {
        $self->set_error( 'Missing Source Tag' );
        return 0;
    }

    unless ( $args{'source_tag'} =~ m{ ^ [a-zA-Z0-9_]+ $ }xs ) {
        $self->set_error( 'Invalid Source Tag' );
        return 0;
    }

    unless ( matches_any( $args{'tag'}, $self->source_tags() ) ) {
        $self->set_error( 'Source Tag Doesn\'t Exist' );
        return 0;
    }

    $self->_raw_remove_source( 1, $args{'source_tag'} );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################
#
# action_add_option - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# option_tag    : required - [a-zA-Z0-9_]
#

sub action_add_option {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'option_tag'} ) ) {
        $self->set_error( 'Missing Option Tag' );
        return 0;
    }

    unless ( $args{'option_tag'} =~ m{ ^ [a-zA-Z0-9_]+ $ }xs ) {
        $self->set_error( 'Invalid Option Tag' );
        return 0;
    }

    if ( matches_any( $args{'option_tag'}, $self->option_tags() ) ) {
        $self->set_error( 'Option Tag Already Exists' );
        return 0;
    }

    $self->_raw_add_option( 1, $args{'option_tag'} );

    $self->_save_state();

    $self->_close_all();

    return 1;

}

#############################################################################
#
# action_remove_option - args
#
# option_tag     : required - [a-zA-Z0-9_]
#

sub action_remove_option {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'option_tag'} ) ) {
        $self->set_error( 'Missing Option Tag' );
        return 0;
    }

    unless ( $args{'option_tag'} =~ m{ ^ [a-zA-Z0-9_]+ $ }xs ) {
        $self->set_error( 'Invalid Option Tag' );
        return 0;
    }

    unless ( $self->status() eq '0' ) {
        $self->set_error( 'Unable to remove option tag from game in session.' );
        return 0;
    }

    unless ( matches_any( $args{'tag'}, $self->option_tags() ) ) {
        $self->set_error( 'Option Tag Doesn\'t Exist' );
        return 0;
    }

    $self->_raw_remove_option( 1, $args{'option_tag'} );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################
#
# action_add_player - args
#
# player_id     : required - integer
#

sub action_add_player {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'player_id'} ) ) {
        $self->set_error( 'Missing Player ID' );
        return 0;
    }

    unless ( looks_like_number( $args{'player_id'} ) ) {
        $self->set_error( 'Invalid Player ID' );
        return 0;
    }

    if ( matches_any( $args{'player_id'}, $self->player_ids() ) ) {
        $self->set_error( 'Player ID Already Exists' );
        return 0;
    }

    $self->_raw_add_player( 1, $args{'player_id'} );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################
#
# action_remove_player - args
#
# player_id     : required - integer
#

sub action_remove_player {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'player_id'} ) ) {
        $self->set_error( 'Missing Player ID' );
        return 0;
    }

    unless ( looks_like_number( $args{'player_id'} ) ) {
        $self->set_error( 'Invalid Player ID' );
        return 0;
    }

    unless ( matches_any( $args{'player_id'}, $self->player_ids() ) ) {
        $self->set_error( 'Player ID Doesn\'t Exist' );
        return 0;
    }

    $self->_raw_remove_player( 1, $args{'player_id'} );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################

sub action_begin {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    # create the base item set

    $self->_raw_begin( 1 );

    # randomize player order

    my @new_player_order = ( 0 .. scalar( $self->player_ids() ) - 1 );
    WLE::Methods::Simple::shuffle_in_place( \@new_player_order );

    $self->_raw_set_player_order( 1, @new_player_order );

    # fill tile stacks with random tiles

    foreach my $stack_tag ( keys( %{ $self->{'TILE_STACKS'} } ) ) {

        my @stack = @{ $self->{'TILE_STACKS'}->{ $stack_tag } };

        WLE::Methods::Simple::shuffle_in_place( \@stack );

        if ( defined( $self->{'SETTINGS'}->{'TILE_STACK_LIMIT_' . $stack_tag } ) ) {
            while ( scalar( @stack ) > $self->{'SETTINGS'}->{'TILE_STACK_LIMIT_' . $stack_tag } ) {
                my $tag = shift( @stack );
                delete( $self->{'TILES'}->{ $tag } );
            }
        }

        delete( $self->{'TILE_STACKS'}->{ $stack_tag } );

        $self->_raw_create_tile_stack( 1, $stack_tag, @stack );
    }

    # place galactic center

    my @stack = @{ $self->{'TILE_STACKS'}->{ 0 }->{'DRAW'} };
    WLE::Methods::Simple::shuffle_in_place( \@stack );

    $self->_raw_remove_tile_from_stack( 0, $stack[ 0 ] );
    $self->_raw_place_tile_on_board( 0, $stack[ 0 ], 0, 0 );


    # add discoveries to tiles

    my @discovery_tags = @{ $self->{'DISCOVERY_BAG'} };
    WLE::Methods::Simple::shuffle_in_place( \@discovery_tags );

    foreach my $tile ( values( %{ $self->tiles() } ) ) {
        foreach ( 1 .. $tile->discovery_count() ) {
            $self->_raw_add_discovery_to_tile( 1, $tile->tag(), shift( @discovery_tags ) );
        }
    }
    $self->{'DISCOVERY_BAG'} = \@discovery_tags;

    # draw random developments

    my @developments = keys( %{ $self->{'DEVELOPMENTS'} } );

    WLE::Methods::Simple::shuffle_in_place( \@developments );

    if ( $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} > -1 ) {
        while ( scalar( @developments ) > $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} ) {
            shift( @developments );
        }
    }

    $self->_raw_create_development_stack( 1, @developments );

    # draw beginning tech tiles

    my @tech_bag = @{ $self->{'TECH_BAG'} };
    my @available_tech = ();
    WLE::Methods::Simple::shuffle_in_place( \@tech_bag );

    foreach ( 1 .. $self->{'START_TECH_COUNT'} ) {
        push( @available_tech, shift( @tech_bag ) );
    }

    $self->_raw_remove_from_tech_bag( 1, @available_tech );
    $self->_raw_add_to_available_tech( 1, @available_tech );



    $self->set_state( $ST_RACESELECTION );
    $self->set_phase( $PH_PREPARING );
    $self->set_waiting_on_player_id( $self->{'SETTINGS'}->{'PLAYERS_PENDING'}->[ 0 ] );

    $self->_log_status( { 'status' => $self->status() } );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################

sub action_select_race_and_location {
    my $self            = shift;
    my %args            = @_;

    unless ( $self->round() == 0 ) {

    }

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'race_tag'} ) ) {
        $self->set_error( 'Missing Race Tag' );
        return 0;
    }

    unless ( defined( $self->races()->{ $args{'race_tag'} } ) ) {
        $self->set_error( 'Invalid Race Tag' );
        return 0;
    }

    if ( $self->races()->{ $args{'race_tag'} }->owner_id() ne '' ) {
        if ( $self->races()->{ $args{'race_tag'} }->owner_id() > -1 ) {
            $self->set_error( 'Race has already been selected.' );
            return 0;
        }
    }

    unless (
        WLE::Methods::Simple::looks_like_number( $args{'location_x'} )
        && WLE::Methods::Simple::looks_like_number( $args{'location_y'} )
    ) {
        $self->set_error( 'Invalid location data.' );
        return 0;
    }

    my $valid_location = 0;
    my $location_warps = undef;

    foreach my $location ( @{ $self->{'STARTING_LOCATIONS'} } ) {
        my ( $x, $y ) = split( ',', $location->{'SPACE'} );

        if ( $args{'location_x'} == $x && $args{'location_y'} == $y ) {
            unless ( defined( $location->{'NPC'} ) ) {
                $valid_location = 1;
                if ( defined( $location->{'WARPS'} ) ) {
                    $location_warps = $location->{'WARPS'};
                }
            }
        }
    }

    unless ( $valid_location ) {
        $self->set_error( 'Location is not available for starting.' );
        return 0;
    }

    unless ( defined( $location_warps ) ) {
        $location_warps = $args{'warps'};
    }

    unless ( WLE::Methods::Simple::looks_like_number( $location_warps ) ) {
        $self->set_error( "Invalid 'warps' argument." );
        return 0;
    }

    $self->_raw_select_race_and_location( 1, $args{'race_tag'}, $args{'location_x'}, $args{'location_y'}, $location_warps );

    unless ( $self->tick_player() ) {

        $self->_raw_remove_non_playing_races( 1 );

        my $index = 1;

        # place galactic defense

        my $tile = $self->board()->tile_at_location( 0, 0 );

        foreach my $ship_class ( $tile->starting_ships() ) {

            my @templates_of_class = ();
            foreach my $template ( values( %{ $self->templates() } ) ) {
                if ( $template->class() eq $ship_class ) {
                    if ( $template->count() > 0 || $template->count() == -1 ) {
                        push( @templates_of_class, $template->tag() );
                    }
                }
            }

            WLE::Methods::Simple::shuffle_in_place( \@templates_of_class );
            my $template_tag = shift( @templates_of_class );

            $self->_raw_create_ship_on_tile(
                1,
                $tile->tag(),
                $template_tag,
                -1,
                'ship_' . $template_tag . '_npc_' . $index,
            );

            $index++;

            my $template = $self->templates()->{ $template_tag };

            if ( $template->count() > 0 ) {
                $template->set_count( $template->count() - 1 );
            }
        }

        if ( $self->has_option( 'ancient_homeworlds' ) ) {

            # get templates for defenders

            my @defenders = ();
            foreach my $ship_template ( values( %{ $self->templates() } ) ) {
                if ( $ship_template->class() eq 'class_ancient_destroyer' ) {
                    push( @defenders, $ship_template->tag() );
                }
            }

            # place ancient homeworld tiles

            my @homeworlds = @{ $self->{'TILE_STACKS'}->{ 'ancient_homeworlds' }->{'DRAW'} };
            WLE::Methods::Simple::shuffle_in_place( \@homeworlds );

            foreach my $location ( @{ $self->{'STARTING_LOCATIONS'} } ) {
                if ( defined( $location->{'NPC'} ) ) {
                    my ( $x, $y ) = split( ',', $location->{'SPACE'} );
                    my $location_warps = $location->{'WARPS'};
                    my $tile_tag = shift( @homeworlds );

                    $self->_raw_remove_tile_from_stack( 1, $tile_tag );
                    $self->_raw_place_tile_on_board( 1, $tile_tag, $x, $y );

                    foreach my $ship_class ( $self->tiles()->{ $tile_tag }->starting_ships() ) {

                        my @templates_of_class = ();
                        foreach my $template ( values( %{ $self->templates() } ) ) {
                            if ( $template->class() eq $ship_class ) {
                                if ( $template->count() > 0 || $template->count() == -1 ) {
                                    push( @templates_of_class, $template->tag() );
                                }
                            }
                        }

                        WLE::Methods::Simple::shuffle_in_place( \@templates_of_class );
                        my $template_tag = shift( @templates_of_class );

                        $self->_raw_create_ship_on_tile(
                            1,
                            $tile_tag,
                            $template_tag,
                            -1,
                            'ship_' . $template_tag . '_npc_' . $index,
                        );

                        $index++;

                        my $template = $self->templates()->{ $template_tag };

                        if ( $template->count() > 0 ) {
                            $template->set_count( $template->count() - 1 );
                        }
                    }
                }
            }
        }


        $self->start_next_round();
    }

    $self->_save_state();

    $self->_close_all();

    return 1;
}


#############################################################################
#############################################################################
1
