package WLE::4X::Objects::Server;

use strict;
use warnings;

use Data::Dumper;
use Fcntl ':flock';
#use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
#use XML::Bare;

use WLE::4X::Methods::Simple;

use WLE::4X::Objects::MetaActions;
use WLE::4X::Objects::RawActions;
use WLE::4X::Objects::LogActions;

# state breakdown

# d1:dd2:dd3:dd4

# d1 -
# 0 - pre-game
#
# shouldn't be any more digits
#
# 1 - game has started - selecting races and positions
#
# dd2 -
#  00 -
#
# 2 - normal turn
# 3 - game has finished



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

    $self->{'FH_STATE'} = undef;
    $self->{'FH_LOG'} = undef;

    $self->{'FILE_RESOURCES'} = $args{'resource_file'};
    $self->{'DIR_STATE_FILES'} = $args{'state_files'};
    $self->{'DIR_LOG_FILES'} = $args{'log_files'};

    $self->{'DIR_STATE_FILES'} =~ s{ /$ }{}xs;
    $self->{'DIR_LOG_FILES'} =~ s{ /$ }{}xs;

    $self->{'LAST_ERROR'} = '';

    unless ( -e $self->_file_resources() ) {
        $self->set_error( 'Unable to locate core resource file: ' . $self->_file_resources() );

        return $self;
    }

    unless ( -d $self->_dir_state_files() ) {
        $self->set_error( 'Unable to locate state files directory: ' . $self->_dir_state_files() );

        return $self;
    }

    unless ( -d $self->_dir_log_files() ) {
        $self->set_error( 'Unable to locate log files directory: ' . $self->_dir_log_files() );

        return $self;
    }

    $self->{'DATA'} = {};

    $self->{'DATA'}->{'LOG_ID'} = '';
    $self->{'DATA'}->{'OWNER_ID'} = 0;

    $self->{'DATA'}->{'SOURCE_TAGS'} = [];
    $self->{'DATA'}->{'OPTION_TAGS'} = [];

    $self->{'DATA'}->{'LONG_NAME'} = '';

    $self->{'DATA'}->{'STATE'} = '0';

    $self->{'DATA'}->{'PLAYER_IDS'} = [];


    return $self;
}

#############################################################################

sub has_option {
    my $self        = shift;
    my $option      = shift;

    if ( $option eq '' ) {
        return 1;
    }

    return matches_any( $option, @{ $self->{'DATA'}->{'OPTION_TAGS'} } );
}

#############################################################################

sub source_tags {
    my $self        = shift;

    return @{ $self->{'DATA'}->{'SOURCE_TAGS'} };
}

#############################################################################

sub option_tags {
    my $self        = shift;

    return @{ $self->{'DATA'}->{'OPTION_TAGS'} };
}

#############################################################################

sub player_ids {
    my $self        = shift;

    return @{ $self->{'DATA'}->{'PLAYER_IDS'} };
}


#############################################################################

sub last_error {
    my $self        = shift;

    my $error = $self->{'LAST_ERROR'};

    $self->{'LAST_ERROR'} = '';

    return $error;
}

#############################################################################

sub set_error {
    my $self        = shift;
    my $value       = shift;

    $self->{'LAST_ERROR'} = $value;
}

#############################################################################

sub long_name {
    my $self        = shift;

    return $self->{'DATA'}->{'LONG_NAME'};
}

#############################################################################

sub log_id {
    my $self        = shift;

    return $self->{'DATA'}->{'LOG_ID'};
}

#############################################################################

sub _set_log_id {
    my $self        = shift;
    my $value       = shift;

    if ( defined( $value ) ) {
        if ( $value =~ m{ ^ [0-9a-zA-Z]{8,20} $ }xs ) {
            $self->{'DATA'}->{'LOG_ID'} = $value;
            return 1;
        }
    }
    else {
        $self->set_error( 'Missing Log ID' );
        return 0;
    }

    $self->set_error( 'Invalid Log ID: ' . $value );

    return 0;
}

#############################################################################

sub _owner_id {
    my $self        = shift;

    return $self->{'DATA'}->{'OWNER_ID'};
}

#############################################################################

sub _set_owner_id {
    my $self        = shift;
    my $value       = shift;

    if ( defined( $value ) ) {
        if ( looks_like_number( $value ) ) {
            $self->{'DATA'}->{'OWNER_ID'} = $value;
            return 1;
        }
    }
    else {
        $self->set_error( 'Missing Owner ID' );
        return 0;
    }

    $self->set_error( 'Invalid Owner ID: ' . $value );
    return 0;
}

#############################################################################

sub _log_data {
    my $self        = shift;
    my $data        = shift;

    print { $self->{'FH_LOG'} } $data . "\n";

    return;
}

#############################################################################

sub _open_for_writing {
    my $self        = shift;
    my $log_id      = shift;

    $self->set_error( '' );

    unless ( $self->_set_log_id( $log_id ) ) {
        $self->set_error( 'Invalid Log ID: ' . $log_id );
        return 0;
    }

    $self->{'FH_LOG'} = $self->_open_file_with_lock( $self->_log_file() );

    $self->{'FH_STATE'} = $self->_open_file_with_lock( $self->_state_file() );

    if ( defined( $self->{'FH_LOG'} ) && defined( $self->{'FH_STATE'} ) ) {
        return 1;
    }

    return 0;
}

#############################################################################

sub _close_all {
    my $self        = shift;

    if ( defined( $self->{'FH_LOG'} ) ) {
        close( $self->{'FH_LOG'} );
    }

    if ( defined( $self->{'FH_STATE'} ) ) {
        close( $self->{'FH_STATE'} );
    }

}

#############################################################################

sub _read_state {
    my $self        = shift;
    my $log_id      = shift;

    my $fh;

    unless ( open( $fh, '<', $self->_state_file() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_state_file() );
        return 0;
    }

    flock( $fh, LOCK_SH );

    # using Data::Dumper

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line;

    $self->{'DATA'} = $VAR1;


    # using Storable

#    $self->{'DATA'} = fd_retrieve( $fh );

    close( $fh );

    return 1;
}

#############################################################################

sub _save_state {
    my $self        = shift;

    # using Data::Dumper

    print { $self->{'FH_STATE'} } Dumper( $self->{'DATA'} );

    # using Storable

#    store_fd( $self->{'DATA'}, $self->{'FH_STATE'} );

    return;
}

#############################################################################

sub _open_file_with_lock {
    my $self        = shift;
    my $file_path   = shift;

    my $fh;

    unless ( -e $file_path ) {

    }

    unless ( open( $fh, '+>>', $file_path ) ) {
        $self->set_error( 'Failed to open file for writing: ' . $file_path );
        return undef;
    }

    unless( flock( $fh, LOCK_EX ) ) {
        $self->set_error( 'Failed to lock file: ' . $file_path );
        return undef;
    }

    return $fh;
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

    return $self->_dir_log_files() . '/' . $self->log_id() . '.log';
}

#############################################################################

sub _state_file {
    my $self        = shift;

    return $self->_dir_state_files() . '/' . $self->log_id() . '.state';
}

#############################################################################
#############################################################################
1