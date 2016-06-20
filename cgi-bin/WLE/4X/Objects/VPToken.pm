package WLE::4X::Objects::VPToken;

use strict;
use warnings;


use WLE::4X::Methods::Simple;

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

    $args{'type'} = 'vptoken';

    $self->WLE::4X::Objects::Element::_init( %args );

    $self->set_vp( 0 );

    return $self;
}

#############################################################################

sub vp {
    my $self        = shift;

    return $self->{'VP'};
}

#############################################################################

sub set_vp {
    my $self        = shift;
    my $value       = shift;

    if ( looks_like_number( $value ) ) {
        $self->{'VP'} = $value;
    }

    return;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'VP'} ) ) {
        return 0;
    }

    $self->set_vp( $r_hash->{'VP'} );

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'VP'} = $self->vp();

    return 1;
}

#############################################################################
#############################################################################
1
