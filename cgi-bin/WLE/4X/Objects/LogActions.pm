package WLE::4X::Objects::Server;

use strict;
use warnings;

my %actions = (
    'add_source'        => \&_log_add_source,
    'remove_source'     => \&_log_remove_source,
    'add_option'        => \&_log_add_option,
    'remove_option'     => \&_log_remove_option,
    'add_player'        => \&_log_add_player,
    'remove_player'     => \&_log_remove_player,
    'begin'             => \&_log_begin,
    'player_order'      => \&_log_player_order,
    'tile_stack'        => \&_log_tile_stack,
    'development_stack' => \&_log_development_stack,

);


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
        my $VAR1;

        eval $data; warn $@ if $@;

        $data->{'parse'} = 1;

        if ( defined( $actions{ $action } ) ) {
            $actions{ $action }->( $self, $data );
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
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_add_source( $r_args->{'tag'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'add_source:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_remove_source {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_remove_source( $r_args->{'tag'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'remove_source:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_add_option {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_add_option( $r_args->{'tag'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'add_option:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_remove_option {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_remove_option( $r_args->{'tag'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'remove_option:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_add_player {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_add_player( $r_args->{'player_id'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'add_player:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_remove_player {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_remove_player( $r_args->{'player_id'} );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'remove_player:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_begin {
    my $self        = shift;
    my $r_args      = shift; $r_args = {}                       unless defined( $r_args );

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_begin();
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'begin' );
    }

    return;
}

#############################################################################

sub _log_player_order {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_set_player_order( @{ $r_args->{'player_order'} } );
    }
    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'player_order:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_tile_stack {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_create_tile_stack( $r_args->{'stack_id'}, @{ $r_args->{'values'} } );
    }

    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'tile_stack:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################

sub _log_development_stack {
    my $self        = shift;
    my $r_args      = shift;

    if ( defined( $r_args->{'parse'} ) ) {
        $self->_raw_create_development_stack( @{ $r_args->{'values'} } );
    }

    else {
        $Data::Dumper::Indent = 0;
        $self->_log_data( 'development_stack:' . Dumper( $r_args ) );
    }

    return;
}

#############################################################################
#############################################################################
1
