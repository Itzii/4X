package WLE::4X::Objects::Discovery;

use strict;
use warnings;


use parent 'WLE::4X::Objects::Element';

#############################################################################
# constructor args
#
# 'server'		- required
#

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

    $args{'type'} = 'discovery';

    unless( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    $self->{'RESOURCES'} = {
        'SCIENCE'       => 0,
        'MINERALS'      => 0,
        'MONEY'         => 0,
    };

    $self->{'COMPONENT'} = '';

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub component {
    my $self        = shift;

    return $self->{'COMPONENT'};
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    if ( defined( $r_hash->{'COMPONENT'} ) ) {
        $self->{'COMPONENT'} = $r_hash->{'COMPONENT'};
    }

    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        foreach my $type ( 'SCIENCE', 'MINERALS', 'MONEY' ) {
            if ( defined( $r_hash->{'RESOURCES'}->{ $type } ) ) {
                $self->{'RESOURCES'}->{ $type } = $r_hash->{'RESOURCES'}->{ $type };
            }
        }
    }

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'COMPONENT'} = $self->{'COMPONENT'};

    $r_hash->{'RESOURCES'} = $self->{'RESOURCES'};

    return 1;
}

#############################################################################
#############################################################################
1
