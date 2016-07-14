package WLE::4X::Objects::ResourceTrack;

use strict;
use warnings;

use WLE::Methods::Simple;

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

    $self->{'TRACK_VALUES'} = [];
    $self->{'ON_TRACK_COUNT'} = 0;
    $self->{'SPENT_COUNT'} = 0;


    return $self;
}

#############################################################################

sub values {
    my $self        = shift;

    return @{ $self->{'TRACK_VALUES'} };
}

#############################################################################

sub set_values {
    my $self        = shift;
    my @values      = @_;

    @{ $self->{'TRACK_VALUES'} } = @values;

    $self->{'ON_TRACK_COUNT'} = 0;
    $self->{'SPENT_COUNT'} = 0;

    return;
}

#############################################################################

sub add_to_track {
    my $self        = shift;
    my $add_value   = shift; $add_value = 1             unless defined( $add_value );

    for ( 1 .. $add_value ) {
        if ( $self->{'ON_TRACK_COUNT'} < scalar( @{ $self->{'TRACK_VALUES'} } ) ) {
            $self->{'ON_TRACK_COUNT'}++;
        }
    }

    return;
}

#############################################################################

sub set_track_count {
    my $self        = shift;
    my $value       = shift;

    if ( $value < scalar( $self->values() ) ) {
        $self->{'ON_TRACK_COUNT'} = $value;
    }
    else {
        $self->{'ON_TRACK_COUNT'} = scalar( $self->values() );
    }

    return;
}

#############################################################################

sub available_to_spend {
    my $self        = shift;

    return $self->{'ON_TRACK_COUNT'};
}

#############################################################################

sub spend {
    my $self        = shift;

    $self->{'ON_TRACK_COUNT'}--;

    return;
}

#############################################################################

sub spend_but_keep {
    my $self        = shift;

    $self->{'ON_TRACK_COUNT'}--;
    $self->{'SPENT_COUNT'}++;

    return;
}

#############################################################################

sub track_value {
    my $self        = shift;

    return $self->{'TRACK_VALUES'}->[ $self->{'ON_TRACK_COUNT'} ];
}

#############################################################################

sub available_spaces {
    my $self        = shift;

    return scalar( @{ $self->{'TRACK_VALUES'} } ) - $self->{'ON_TRACK_COUNT'};
}

#############################################################################

sub spent_count {
    my $self        = shift;

    return $self->{'SPENT_COUNT'};
}

#############################################################################

sub set_spent_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'SPENT_COUNT'} = $value;
    return;
}

#############################################################################

sub reset_spent {
    my $self        = shift;

    $self->add_to_track( $self->spent_count() );
    $self->set_spent_count( 0 );

    return;
}

#############################################################################
#############################################################################
1
