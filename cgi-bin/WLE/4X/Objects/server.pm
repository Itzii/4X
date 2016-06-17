package WLE::4X::Objects::Server;

use strict;
use warnings;


#############################################################################
# constructor args
#
# 'resource_file'		- required : path to the core resource file
# 'state_files'         - required : path to folder holding state files
# 'log_files'           - required : path to folder holding log files

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $self->{'FILE_RESOURCES'} = $args{'resource_file'};
    $self->{'DIR_STATE_FILES'} = $args{'state_files'};
    $self->{'DIR_LOG_FILES'} = $args{'log_files'};

    $self->{'DIR_STATE_FILES'} =~ s{ /$ }{}xs;
    $self->{'DIR_LOG_FILES'} =~ s{ /$ }{}xs;

    $self->{'LOG_ID'} = '';
    $self->{'OWNER_ID'} = 0;

    $self->{'SOURCE_TAGS'} = [];
    $self->{'OPTION_TAGS'} = [];

    $self->{'LONG_NAME'} = '';

    $self->{'LAST_ERROR'} = '';

    unless ( -e $self->{'FILE_RESOURCES'} ) {
        $self->{'LAST_ERROR'} = 'Unable to locate core resource file: ' . $self->_file_resources();

        return $self;
    }

    unless ( -d $self->{'DIR_STATE_FILES'} ) {
        $self->{'LAST_ERROR'} = 'Unable to locate state files directory: ' . $self->_dir_state_files();

        return $self;
    }

    unless ( -d $self->{'DIR_LOG_FILES'} ) {
        $self->{'LAST_ERROR'} = 'Unable to locate log files directory: ' . $self->_dir_log_files();

        return $self;
    }


    return $self;
}
#############################################################################
#
# action_start_log - args
#
# log_id        : required - 8-20 character unique indentifier [a-zA-Z0-9]
# owner_id      : required - integer
#
# long_name     : optional - descriptive name
# r_source_tags : list reference of source tags
# r_option_tags : list reference of option tags
#

sub action_start_log {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_set_log_id( $args{'log_id'} ) ) {
        return 0;
    }

    unless ( $self->_set_owner_id( $args{'owner_id'} ) ) {
        return 0;
    }

    $self->{'DIR_LOG_FILES'} .= '/' . $self->log_id();

    $self->{'SOURCE_TAGS'} = [ @{ $args{'r_source_tags'} } ];

    if ( scalar( @{ $self->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Must have at least one source tag.' );
        return 0;
    }

    $self->{'OPTION_TAGS'} = [ @{ $args{'r_option_tags'} } ];

    unless ( open( LOGFILE, '>', $self->_log_file() ) ) {
        $self->set_error( 'Failed to open log: ' . $self->_log_File() );
        return 0;
    }

    print LOGFILE $self->owner_id() . "\n";
    print LOGFILE $self->long_name() . "\n";
    print LOGFILE join( ',', @{ $self->{'SOURCE_TAGS'} } ) . "\n";
    print LOGFILE join( ',', @{ $self->{'OPTION_TAGS'} } ) . "\n";

    close( LOGFILE );

    unless( $self->_save_state_file() ) {
        return 0;
    }
    return 1;
}

#############################################################################

sub action_parse_state_from_log {
    my $self        = shift;
    my $log_id      = shift;

    unless ( $self->set_log_id( $log_id ) ) {
        $self->set_error( 'Invalid Log ID: ' . $log_id );
        return 0;
    }

    unless ( open( LOG_FILE, '<', $self->_log_file() ) ) {
        $self->set_error( 'Unable to open log file: ' . $self->_log_file() );
        return 0;
    }

    unless ( $self->set_owner_id( <LOG_FILE> ) ) {
        return 0;
    }

    $self->{'LONG_NAME'} = <LOG_FILE>;

    $self->{'SOURCE_TAGS'} = split( /,/, <LOG_FILE> );

    if ( scalar( @{ $self->{'SOURCE_TAGS'} } ) == 0 ) {
        $self->set_error( 'Missing source tags' );
        return 0;
    }

    $self->{'OPTION_TAGS'} = split( /,/, <LOG_FILE> );

    my $line = <LOG_FILE>;

    while ( defined( $line ) ) {









        $line = <LOG_FILE>;
    }

    close( LOG_FILE );

    unless ( $self->_save_state_file() ) {
        return 0;
    }

    return 1;
}

#############################################################################

sub has_option {
    my $self        = shift;
    my $option      = shift;

    if ( $option eq '' ) {
        return 1;
    }

    return matches_any( $option, @{ $self->{'OPTION_TAGS'} } );
}

#############################################################################

sub last_error {
    my $self        = shift;

    return $self->{'LAST_ERROR'};
}

#############################################################################

sub set_error {
    my $self        = shift
    my $value       = shift;

    $self->{'LAST_ERROR'} = $value;
}

#############################################################################

sub log_id {
    my $self        = shift;

    return $self->{'LOG_ID'};
}

#############################################################################

sub _set_log_id {
    my $self        = shift;
    my $value       = shift;

    if ( $value =~ m{ ^ [0-9a-zA-Z]{8,20} $ } ) {
        $self->{'LOG_ID'} = $value;
        return 1;
    }

    $self->set_error( 'Invalid Log ID: ' . $value );

    return 0;
}

#############################################################################

sub _owner_id {
    my $self        = shift;

    return $self->{'OWNER_ID'};
}

#############################################################################

sub _set_owner_id {
    my $self        = shift;
    my $value       = shift;

    unless ( looks_like_number( $value ) ) {
        $self->set_error( 'Invalid Owner ID: ' . $value );
        return 0;
    }

    $self->{'OWNER_ID'} = $value;
}

#############################################################################

sub _save_state_file {
    my $self        = shift;

    unless ( open( STATEFILE, '>', $self->_state_file() ) ) {
        $self->set_error( 'Failed to write state file: ' . $self->_state_file() );
        return 0;
    }

    print STATEFILE Dumper( $self );

    close( STATEFILE );

    return 1;
}


#############################################################################

sub _file_resources {
    my $self        = shift;

    return $self->{'FILE_RESOURCES'};
}

#############################################################################

sub _dir_state_files {
    my $self        = shift;

    return $self->{'DIR_STATE_FILES'};
}

#############################################################################

sub _dir_log_files {
    my $self        = shift;

    return $self->{'DIR_LOG_FILES'};
}

#############################################################################

sub _log_file {
    my $self        = shift;

    return $self->_dir_log_files() . '/' . $self->log_id() . 'log';
}

#############################################################################

sub _state_file {
    my $self        = shift;

    return $self->_dir_state_files() . '/' . $self->log_id() . '.state';
}

#############################################################################
#############################################################################





#############################################################################

sub looks_like_number {
	my $value		= shift;

	# checks from perlfaq4

	unless ( defined( $value ) ) {
		return 1;
	}

	if ( $value =~ m{ ^[+-]?\d+$ }xms ) { # is a +/- integer
		return 1;
	}

	if ( $value =~ m{ ^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$ }xms ) { # a C float
		return 1;
	}

	if ( ( $] >= 5.008 && $value =~ m{ ^(Inf(inity)?|NaN)$ }xmsi ) || ( $] >= 5.006+001 && $value =~ m{ ^Inf$ }xmsi ) ) {
		return 1;
	}

	return 0;
}

#############################################################################

sub matches_any {
	my $value		= shift;
	my @possibles	= @_;

	my $is_number = looks_like_number( $value );

	foreach ( @possibles ) {
		if ( $is_number ) {
			if ( $value == $_ ) {
				return 1;
			}
		}
		else {
			if ( $value eq $_ ) {
				return 1;
			}
		}
	}

	return 0;
}

#############################################################################
#############################################################################
1
