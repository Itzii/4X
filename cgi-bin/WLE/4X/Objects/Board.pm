package WLE::4X::Objects::Board;

use strict;
use warnings;


use WLE::4X::Methods::Simple;

use WLE::4X::Objects::Tile;

#############################################################################
# constructor args
#
# 'server'		- required
#

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    $args{'type'} = 'board';

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    unless ( defined( $args{'server'} ) ) {
        return undef;
    }

    $self->{'SERVER'} = $args{'server'};

    $self->{'SPACES'} = {};


    return $self;
}

#############################################################################

sub place_tile {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $tile_tag    = shift;

    if ( $tile_tag eq '' ) {
        return 0;
    }

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) ) {
        return 0;
    }

    unless ( defined( $self->{'SPACES'}->{ $x_pos } ) ) {
        $self->{'SPACES'}->{ $x_pos } = {};
    }

    if ( defined( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } ) ) {
        unless ( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } eq '' ) {
            return 0;
        }
    }

    $self->{'SPACES'}->{ $x_pos }->{ $y_pos } = $tile_tag;

    return 1;
}

#############################################################################

sub tile_at_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    unless ( defined( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } ) ) {
        return undef;
    }

    return $self->server()->tile_from_tag( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } );
}

#############################################################################

sub tile_in_direction {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $direction   = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) && looks_like_number( $direction ) ) {
        return undef;
    }

    return $self->tile_at_location( $self->location_in_direction( $x_pos, $y_pos, $direction ) );
}

#############################################################################

sub location_in_direction {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $direction   = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) && looks_like_number( $direction ) ) {
        return undef;
    }

    while ( $direction < 0 ) {
        $direction += 6;
    }

    while ( $direction > 5 ) {
        $direction -= 6;
    }

    if ( $direction == 0 ) {
        return ( $x_pos, $y_pos - 1 );
    }
    elsif ( $direction == 1 ) {
        return ( $x_pos + 1, $y_pos - 1 );
    }
    elsif ( $direction == 2 ) {
        return ( $x_pos + 1, $y_pos );
    }
    elsif ( $direction == 3 ) {
        return ( $x_pos, $y_pos + 1 );
    }
    elsif ( $direction == 4 ) {
        return ( $x_pos - 1, $y_pos + 1 );
    }
    elsif ( $direction == 5 ) {
        return ( $x_pos - 1, $y_pos );
    }

    return undef;
}

#############################################################################

sub stack_from_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) ) {
        return -1;
    }

    if ( $x_pos == 0 && $y_pos == 0 ) {
        return 0;
    }

    if (
        ( $x_pos == 1 && $y_pos > -2 && $y_pos < 1 )
        || ( $x_pos == 0 && $y_pos > -2 && $y_pos < 2 )
        || ( $x_pos == -1 && $y_pos > -1 && $y_pos < 2 )
    ) {
        return 1;
    }

    if (
        ( $x_pos == 2 && $y_pos > -3 && $y_pos < 1 )
        || ( $x_pos == 1 && ( $y_pos == -2 || $y_pos == 1 ) )
        || ( $x_pos == 0 && ( $y_pos == -2 || $y_pos == 2 ) )
        || ( $x_pos == -1 && ( $y_pos == -1 || $y_pos == 2 ) )
        || ( $x_pos == 2 && $y_pos > -1 && $y_pos < 3 )
    ) {
        return 2;
    }

    return 3;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'SPACES'} ) ) {
        return 0;
    }

    $self->{'SPACES'} = $r_hash->{'SPACES'};

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'SPACES'} = $self->{'SPACES'};

    return 1;
}

#############################################################################
#############################################################################
1
