package WLE::4X::Objects::ResourceSpace;

use strict;
use warnings;

use WLE::Methods::Simple;

use WLE::4X::Enums::Basic;

#############################################################################

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

    $self->{'RESOURCE_TYPE'} = $RES_UNKNOWN;
    $self->{'FLAG_ADVANCED'} = 0;
    $self->{'OWNER_ID'} = -1;

    return $self;
}

#############################################################################

sub resource_type {
    my $self        = shift;

    return $self->{'RESOURCE_TYPE'};
}

#############################################################################

sub set_resource_type {
    my $self        = shift;
    my $type        = shift;

    $self->{'RESOURCE_TYPE'} = $type;

    return;
}

#############################################################################

sub is_advanced {
    my $self        = shift;

    return $self->{'FLAG_ADVANCED'};
}

#############################################################################

sub set_is_advanced {
    my $self        = shift;
    my $flag        = shift;

    $self->{'FLAG_ADVANCED'} = $flag;

    return;
}

#############################################################################

sub owner_id {
    my $self        = shift;

    return $self->{'OWNER_ID'};
}

#############################################################################

sub set_owner_id {
    my $self        = shift;
    my $owner_id    = shift;

    $self->{'OWNER_ID'} = $owner_id;

    return;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    if ( defined( $r_hash->{'TYPE'} ) ) {
        $self->{'RESOURCE_TYPE'} = enum_from_resource_text( $r_hash->{'TYPE'} );
    }

    if ( defined( $r_hash->{'OWNER_ID'} ) ) {
        $self->{'OWNER_ID'} = $r_hash->{'OWNER_ID'};
    }

    if ( defined( $r_hash->{'ADVANCED'} ) ) {
        $self->{'FLAG_ADVANCED'} = $r_hash->{'ADVANCED'};
    }

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    $r_hash->{'TYPE'} = text_from_resource_enum( $self->{'RESOURCE_TYPE'} );

    $r_hash->{'OWNER_ID'} = $self->{'OWNER_ID'};

    $r_hash->{'ADVANCED'} = $self->{'FLAG_ADVANCED'};

    return 1;
}

#############################################################################
#############################################################################
1
