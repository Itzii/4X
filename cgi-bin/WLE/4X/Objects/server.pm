package WLE::4X::Objects::Server;

use strict;
use warnings;


################################################
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

################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    $self->{'RESOURCE_FILE'} = $args{'resource_file'};
    $self->{'STATE_FILES'} = $args{'state_files'};
    $self-.{'LOG_FILES'} = $args{'log_files'};

    return $self;
}
