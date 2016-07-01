package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple;

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

    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [ @{ $args{'r_source_tags'} } ];

    if ( scalar( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Must have at least one source tag.' );
        return 0;
    }

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [ @{ $args{'r_option_tags'} } ];

    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [ $args{'user'} ];


    $self->_log_data( $self->long_name() );
    $self->_log_data( join( ',', @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} } ) );
    $self->_log_data( join( ',', @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} } ) );

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

    if ( matches_any( $args{'source_tag'}, $self->source_tags() ) ) {
        $self->set_error( 'Source Tag Already Exists' );
        return 0;
    }

    $self->_raw_add_source( $args{'source_tag'} );

    $self->_log_add_source( { 'tag' => $args{'source_tag'} } );

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

    $self->_raw_remove_source( $args{'source_tag'} );

    $self->_log_remove_source( { 'tag' => $args{'source_tag'} } );

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

    $self->_raw_add_option( $args{'option_tag'} );

    $self->_log_add_option( { 'tag' => $args{'option_tag'} } );

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

    $self->_raw_remove_option( $args{'option_tag'} );

    $self->_log_remove_option( { 'tag' => $args{'option_tag'} } );

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

    $self->_raw_add_player( $args{'player_id'} );

    $self->_log_add_player( { 'player_id' => $args{'player_id'} } );

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

    $self->_raw_remove_player( $args{'player_id'} );

    $self->_log_remove_player( { 'player_id' => $args{'player_id'} } );

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

    $self->_raw_begin();
    $self->_log_begin();

    # randomize player order

    my @new_player_order = ( 0 .. scalar( $self->player_ids() ) - 1 );
    shuffle_in_place( \@new_player_order );

    $self->_raw_set_player_order( @new_player_order );
    $self->_log_player_order( { 'player_order' => [ @new_player_order ] } );

    # fill tile stacks with rrandom tiles

    foreach my $count ( 1 .. 3 ) {

        my @stack = @{ $self->{'TILE_STACK_' . $count } };

        shuffle_in_place( \@stack );

        if ( defined( $self->{'SETTINGS'}->{'TILE_STACK_LIMIT_' . $count } ) ) {
            while ( scalar( @stack ) > $self->{'SETTINGS'}->{'TILE_STACK_LIMIT_' . $count } ) {
                my $tag = shift( @stack );
                delete( $self->{'TILES'}->{ $tag } );
            }
        }

        $self->_raw_create_tile_stack( $count, @stack );
        $self->_log_tile_stack( { 'stack_id' => $count, 'values' => \@stack } );

        delete( $self->{'TILE_STACK_' . $count } );
    }

    # draw random developments

    my @developments = keys( %{ $self->{'DEVELOPMENTS'} } );

    shuffle_in_place( \@developments );

    if ( $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} > -1 ) {
        while ( scalar( @developments ) > $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} ) {
            shift( @developments );
        }
    }

    $self->_raw_create_development_stack( @developments );
    $self->_log_development_stack( 'values' => \@developments );


    $self->{'SETTINGS'}->{'STATUS'} = '0:' . $self->{'PLAYERS_PENDING'}->[ 0 ];

    $self->_save_state();

    $self->_close_all();

    return 1;
}



#############################################################################
#############################################################################
1
