package WLE::4X::Objects::TechTrack;

use strict;
use warnings;

use WLE::Methods::Simple qw( shuffle_in_place matches_any );

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

    $self->{'TECHS'} = [];
    $self->{'CREDITS'} = [ 0, -1, -2, -3, -4, -6, -8 ];
    $self->{'VP'} = [ 0, 0, 0, 0, 1, 2, 3, 5 ];

    return $self;
}

#############################################################################

sub current_credit {
    my $self        = shift;

    my $credit_count = scalar( @{ $self->{'TECHS'} } );

    if ( $credit_count > scalar( $self->{'CREDITS'} - 1 ) ) {
        return $self->{'CREDITS'}->[ -1 ];
    }

    return $self->{'CREDITS'}->[ $credit_count ];
}

#############################################################################

sub vp_total {
    my $self        = shift;

    my $vp_count = scalar( @{ $self->{'TECHS'} } );

    if ( $vp_count > scalar( $self->{'VP'} ) ) {
        return $self->{'VP'}->[ -1 ];
    }

    return $self->{'VP'}->[ $vp_count ];
}

#############################################################################

sub add_techs {
    my $self        = shift;
    my @tech_tags   = @_;

    push( @{ $self->{'TECHS'} }, @tech_tags );

    return;
}

#############################################################################

sub techs {
    my $self        = shift;

    return @{ $self->{'TECHS'} };
}

#############################################################################

sub clear {
    my $self        = shift;

    $self->{'TECHS'} = [];

    return;
}

#############################################################################

sub contains {
    my $self        = shift;
    my $value       = shift;

    return matches_any( $value, @{ $self->{'TECHS'} } );
}

#############################################################################
#############################################################################
1
