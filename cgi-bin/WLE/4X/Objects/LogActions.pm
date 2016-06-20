package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Methods::Simple;

my %actions = (
    'add_source'        => \&_log_add_source,
    'remove_source'     => \&_log_remove_source,
    'add_option'        => \&_log_add_option,
    'remove_option'     => \&_log_remove_option,
    'add_player'        => \&_log_add_player,
    'remove_player'     => \&_log_remove_player,
    'begin'             => \&_log_begin,

);

my $ADD_PLAYER          = 'add_player';


#############################################################################
#
# action_parse_state_from_log - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
#

sub action_parse_state_from_log {
    my $self        = shift;
    my %args        = @_;

    $self->set_error( '' );

    unless ( $self->set_log_id( $args{'log_id'} ) ) {
        $self->set_error( 'Invalid Log ID: ' . $args{'log_id'} );
        return 0;
    }

    my $fh_state;
    my $fh_log;

    unless ( open( $fh_state, '>', $self->_state_file() ) ) {
        $self->set_error( 'Failed to write state file: ' . $self->_state_file() );
        return 0;
    }

    unless( flock( $fh_state, LOCK_EX ) ) {
        $self->set_error( 'Failed to lock state file: ' . $self->_state_file() );
        return 0;
    }

    unless ( open( $fh_log, '<', $self->_log_file() ) ) {
        $self->set_error( 'Unable to open log file: ' . $self->_log_file() );
        return 0;
    }

    flock( $fh_log, LOCK_SH );

    unless ( $self->set_owner_id( <$fh_log> ) ) {
        return 0;
    }

    $self->{'DATA'}->{'PLAYER_IDS'} = [ $self->_owner_id() ];

    $self->{'DATA'}->{'LONG_NAME'} = <$fh_log>;

    $self->{'DATA'}->{'SOURCE_TAGS'} = split( /,/, <$fh_log> );

    if ( scalar( @{ $self->{'DATA'}->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Missing source tags' );
        return 0;
    }

    $self->{'DATA'}->{'OPTION_TAGS'} = split( /,/, <$fh_log> );

    my $line = <$fh_log>;

    while ( defined( $line ) ) {

        my ( $action, $data ) = split( /:/, $line, 2 );

        if ( defined( $actions{ $action } ) ) {
            $actions{ $action }->( $self, 'parse' => 1, $data );
        }
        else {
            $self->set_error( 'Invalid Action In Log: ' . $action );
        }

        $line = <$fh_log>;
    }

    # using Data::Dumper

    print $fh_state Dumper( $self->{'DATA'} );

    # using Storable

#    store_fd( $self->{'DATA'}, $fh_state );

    close( $fh_state );

    close( $fh_log );

    return 1;
}

#############################################################################

sub _log_add_source {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_add_source( $args{'tag'} );
    }
    else {
        $self->_log_data( 'add_source:' . $args{'tag'} );
    }

    return;
}

#############################################################################

sub _log_remove_source {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_remove_source( $args{'tag'} );
    }
    else {
        $self->_log_data( 'remove_source:' . $args{'tag'} );
    }

    return;
}

#############################################################################

sub _log_add_option {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_add_option( $args{'tag'} );
    }
    else {
        $self->_log_data( 'add_option:' . $args{'tag'} );
    }

    return;
}

#############################################################################

sub _log_remove_option {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_remove_option( $args{'tag'} );
    }
    else {
        $self->_log_data( 'remove_option:' . $args{'tag'} );
    }

    return;
}

#############################################################################

sub _log_add_player {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_add_player( $args{'data'} );
    }
    else {
        $self->_log_data( 'add_player:' . $args{'player_id'} );
    }

    return;
}

#############################################################################

sub _log_remove_player {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_remove_player( $args{'data'} );
    }
    else {
        $self->_log_data( 'remove_player:' . $args{'player_id'} );
    }

    return;
}

#############################################################################

sub _log_begin {
    my $self        = shift;
    my %args        = @_;

    if ( defined( $args{'parse'} ) ) {
        $self->_raw_begin();
    }
    else {
        $self->_log_data( 'begin' );
    }

    return;
}

#############################################################################
#############################################################################
1
