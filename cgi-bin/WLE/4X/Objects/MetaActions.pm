package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Methods::Simple;

#############################################################################
#
# action_create_game - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# owner_id      : required - integer
#
# long_name     : optional - descriptive name
# r_source_tags : list reference of source tags
# r_option_tags : list reference of option tags
#

sub action_create_game {
    my $self        = shift;
    my %args        = @_;

    $self->set_error( '' );

    unless ( $self->_set_owner_id( $args{'owner_id'} ) ) {
        return 0;
    }

    unless ( $self->_open_for_writing( $args{'log_id'} ) ) {
        return 0;
    }


    $self->{'DATA'}->{'SOURCE_TAGS'} = [ @{ $args{'r_source_tags'} } ];

    if ( scalar( @{ $self->{'DATA'}->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Must have at least one source tag.' );
        return 0;
    }

    $self->{'DATA'}->{'OPTION_TAGS'} = [ @{ $args{'r_option_tags'} } ];

    $self->{'DATA'}->{'PLAYER_IDS'} = [ $args{'owner_id'} ];


    $self->_log_data( $self->_owner_id() );
    $self->_log_data( $self->long_name() );
    $self->_log_data( join( ',', @{ $self->{'DATA'}->{'SOURCE_TAGS'} } ) );
    $self->_log_data( join( ',', @{ $self->{'DATA'}->{'OPTION_TAGS'} } ) );

    $self->_save_state();

    return 1;
}

#############################################################################
#
# action_add_source - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# source_tag     : required - [a-zA-Z0-9_]
#

sub action_add_source {
    my $self        = shift;
    my %args        = @_;

    print "\naction_add_source called ...";

    unless ( $self->_open_for_writing( $args{'log_id'} ) ) {
        return 0;
    }

    print "\nchecking args ...";

    unless ( defined( $args{'source_tag'} ) ) {
        $self->set_error( 'Missing Source Tag' );
        return 0;
    }

    unless ( $args{'source_tag'} =~ m{ ^ [a-zA-Z0-9_]+ $ }xs ) {
        $self->set_error( 'Invalid Source Tag' );
        return 0;
    }

    unless ( $self->{'DATA'}->{'STATUS'} eq '0' ) {
        $self->set_error( 'Unable to add source tag to game in session.' );
        return 0;
    }

    print "\nChecking for matches ...";

    if ( matches_any( $args{'tag'}, $self->source_tags() ) ) {
        $self->set_error( 'Source Tag Already Exists' );
        return 0;
    }

    print "\nCall _raw_add_source ...";

    $self->_raw_add_source( $args{'tag'} );

    $self->_log_add_source( 'tag' => $args{'tag'} );

    $self->_save_state();

    return 1;

}

#############################################################################
#
# action_remove_source - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# source_tag     : required - [a-zA-Z0-9_]
#

sub action_remove_source {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $args{'log_id'} ) ) {
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

    unless ( $self->{'DATA'}->{'STATUS'} eq '0' ) {
        $self->set_error( 'Unable to remove source tag from game in session.' );
        return 0;
    }

    unless ( matches_any( $args{'tag'}, $self->source_tags() ) ) {
        $self->set_error( 'Source Tag Doesn\'t Exist' );
        return 0;
    }

    $self->_raw_remove_source( $args{'source_tag'} );

    $self->_log_remove_source( 'tag' => $args{'source_tag'} );

    $self->_save_state();

    return 1;
}

#############################################################################
#
# action_add_player - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# player_id     : required - integer
#

sub action_add_player {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $args{'log_id'} ) ) {
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

    unless ( $self->{'DATA'}->{'STATUS'} eq '0' ) {
        $self->set_error( 'Unable to add Players to game in session.' );
        return 0;
    }

    if ( matches_any( $args{'player_id'}, $self->player_ids() ) ) {
        $self->set_error( 'Player ID Already Exists' );
        return 0;
    }

    $self->_raw_add_player( $args{'player_id'} );

    $self->_log_add_player( 'player_id' => $args{'player_id'} );

    $self->_save_state();

    return 1;
}

#############################################################################
#
# action_remove_player - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# player_id     : required - integer
#

sub action_remove_player {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $args{'log_id'} ) ) {
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

    unless ( $self->{'DATA'}->{'STATUS'} eq '0' ) {
        $self->set_error( 'Unable to remove Players from game in session.' );
        return 0;
    }

    unless ( matches_any( $args{'player_id'}, $self->player_ids() ) ) {
        $self->set_error( 'Player ID Doesn\'t Exist' );
        return 0;
    }

    $self->_raw_remove_player( $args{'player_id'} );

    $self->_log_remove_player( 'player_id' => $args{'player_id'} );

    $self->_save_state();

    return 1;
}

#############################################################################
#############################################################################
1
