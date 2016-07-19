package WLE::4X::Objects::Discovery;

use strict;
use warnings;

use WLE::4X::Enums::Basic;

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
        $RES_SCIENCE    => 0,
        $RES_MINERALS   => 0,
        $RES_MONEY      => 0,
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

sub adds_component {
    my $self        = shift;

    return ( $self->component() ne '' );
}

#############################################################################

sub adds_resource {
    my $self        = shift;

    foreach my $resource ( $self->{'RESOURCES'} ) {
        if ( $self->{'RESOURCES'}->{ $resource } > 0 ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub resources {
    my $self        = shift;

    return $self->{'RESOURCES'};
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
        foreach my $type ( keys( %{ $self->{'RESOURCES'} } ) ) {
            my $type_text = text_from_resource_enum( $type );
            if ( defined( $r_hash->{'RESOURCES'}->{ $type_text } ) ) {
                $self->{'RESOURCES'}->{ $type } = $r_hash->{'RESOURCES'}->{ $type_text };
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
    $r_hash->{'RESOURCES'} = {};

    foreach my $type ( keys( %{ $self->{'RESOURCES'} } ) ) {
        my $type_text = text_from_resource_enum( $type );
        $r_hash->{'RESOURCES'}->{ $type_text } = $self->{'RESOURCES'}->{ $type };
    }

    return 1;
}

#############################################################################
#############################################################################
1
