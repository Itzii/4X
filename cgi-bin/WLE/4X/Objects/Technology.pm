package WLE::4X::Objects::Technology;

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

    $args{'type'} = 'shipcomponent';

    $self->WLE::4X::Objects::Element::_init( %args );

    $self->{'CATEGORY'} = '';

    $self->{'BASE_COST'} = 0;
    $self->{'MIN_COST'} = 0;

    $self->{'PROVIDES'} = [];

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

    return $self->{'PROVIDES'};
}

#############################################################################

sub does_provide {
    my $self        = shift;
    my $value       = shift;

    if ( $value eq '' ) {
        return 1;
    }

    return matches_any( $value, @{ $self->provides() } );
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;
    my $flag_m      = shift; $flag_m = 1                unless defined( $flag_m );

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return ();
    }

    print "\nfrom hash ... " . $self->tag();

    if ( defined( $r_hash->{'CATEGORY'} ) ) {
        $self->{'CATEGORY'} = $r_hash->{'CATEGORY'};
    }

    if ( looks_like_number( $r_hash->{'BASE_COST'} ) ) {
        $self->{'BASE_COST'} = $r_hash->{'BASE_COST'};
    }

    if ( looks_like_number( $r_hash->{'MIN_COST'} ) ) {
        $self->{'MIN_COST'} = $r_hash->{'MIN_COST'};
    }

    my $provides = $r_hash->{'PROVIDES'};

    if ( ref( $provides ) eq 'SCALAR') {
        unless ( $provides eq '' ) {
            push( @{ $self->{'PROVIDES'} }, $provides );
        }
    }
    elsif ( ref( $provides ) eq 'ARRAY' ) {
        push( @{ $self->{'PROVIDES'} }, @{ $provides } );
    }

    my @final = ();

    if ( $flag_m && looks_like_number( $r_hash->{'COUNT'} ) ) {
        foreach my $index ( 1 .. $r_hash->{'COUNT'} ) {

            print "\ntag: " . $self->tag() . ' -- ' . $index;

            my $tech = WLE::4X::Objects::Technology->new( 'server' => $self->server(), 'tag' => $self->tag() . '_' . $index );
            $tech->from_hash( $r_hash, 0 );
            push( @final, $tech );
        }
    }
    else {
        @final = ( $self );
    }

    return @final;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'CATEGORY'} = $self->category();

    $r_hash->{'BASE_COST'} = $self->base_cost();
    $r_hash->{'MIN_COST'} = $self->min_cost();

    $r_hash->{'PROVIDES'} = @{ $self->provides() };

    return 1;
}

#############################################################################
#############################################################################
1
