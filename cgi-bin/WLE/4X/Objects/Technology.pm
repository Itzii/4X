package WLE::4X::Objects::Technology;

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

    $args{'type'} = 'shipcomponent';

    $self->WLE::4X::Objects::Element::_init( %args );

    $self->{'CATEGORY'} = '';

    $self->{'BASE_COST'} = 0;
    $self->{'MIN_COST'} = 0;

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub category {
    my $self        = shift;

    return $self->{'CATEGORY'};
}

#############################################################################

sub base_cost {
    my $self        = shift;

    return $self->{'BASE_COST'};
}

#############################################################################

sub min_cost {
    my $self        = shift;

    return $self->{'MIN_COST'};
}

#############################################################################

sub provides {
    my $self        = shift;

    my @items = $self->WLE::4X::Objects::Element::provides();

    if ( scalar( @items ) > 0 ) {
        return $items[ 0 ];
    }

    return '';
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    if ( defined( $r_hash->{'CATEGORY'} ) ) {
        $self->{'CATEGORY'} = enum_from_tech_text( $r_hash->{'CATEGORY'} );
    }

    if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'BASE_COST'} ) ) {
        $self->{'BASE_COST'} = $r_hash->{'BASE_COST'};
    }

    if ( WLE::Methods::Simple::looks_like_number( $r_hash->{'MIN_COST'} ) ) {
        $self->{'MIN_COST'} = $r_hash->{'MIN_COST'};
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

    $r_hash->{'CATEGORY'} = text_from_tech_enum( $self->category() );

    $r_hash->{'BASE_COST'} = $self->base_cost();
    $r_hash->{'MIN_COST'} = $self->min_cost();

    return 1;
}

#############################################################################
#############################################################################
1
