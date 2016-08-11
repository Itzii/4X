package WLE::Methods::Simple;

use strict;
use warnings;

our @ISA       = qw( Exporter );
our @EXPORT    = qw(

    looks_like_number
    matches_any
    shuffle_in_place
    center_text

);

#############################################################################

sub looks_like_number {
	my $value		= shift;

	# checks from perlfaq4

	unless ( defined( $value ) ) {
		return 1;
	}

	if ( $value =~ m{ ^[+-]?\d+$ }xms ) { # is a +/- integer
		return 1;
	}

	if ( $value =~ m{ ^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$ }xms ) { # a C float
		return 1;
	}

	if ( ( $] >= 5.008 && $value =~ m{ ^(Inf(inity)?|NaN)$ }xmsi ) || ( $] >= 5.006+001 && $value =~ m{ ^Inf$ }xmsi ) ) {
		return 1;
	}

	return 0;
}

#############################################################################

sub matches_any {
	my $value		= shift;
	my @possibles	= @_;

	my $is_number = looks_like_number( $value );

	foreach ( @possibles ) {
		if ( $is_number ) {
			if ( $value == $_ ) {
				return 1;
			}
		}
		else {
			if ( $value eq $_ ) {
				return 1;
			}
		}
	}

	return 0;
}

#############################################################################

sub shuffle_in_place {
    my $r_array     = shift;

    if ( scalar( @{ $r_array } ) < 2 ) {
        return;
    }

    my $index = @{ $r_array };

    while ( --$index ) {
        my $position = int rand( $index + 1 );
        @{ $r_array }[ $index, $position ] = @{ $r_array }[ $position, $index ];
    }

    return;
}

#############################################################################

sub rotate_bits_left {
    my $value       = shift;
    my $bitcount    = shift; $bitcount = 8          unless defined( $bitcount );
    my $places      = shift; $places = 1            unless defined( $places );

    my $limit = ( 2 ** $bitcount ) - 1;

    for ( 1 .. $places ) {

        $value = $value << 1;

        if ( $value > $limit ) {
            $value -= $limit;
            $value |= 1;
        }
    }

    return $value;
}

#############################################################################

sub rotate_bits_right {
    my $value       = shift;
    my $bitcount    = shift; $bitcount = 8          unless defined( $bitcount );
    my $places      = shift; $places = 1            unless defined( $places );

    for ( 1 .. $places ) {
        my $right_bit = $value & 1;
        $right_bit = $right_bit << ( $bitcount - 1 );

        $value = ( $value >> 1 ) | $right_bit;
        $value = $value | $right_bit;
    }

    return $value;
}

#############################################################################

sub center_text {
    my $text        = shift;
    my $width       = shift;

    if ( length( $text ) >= $width ) {
        return $text;
    }

    while ( length( $text ) < $width ) {
        $text .= ' ';
        if ( length( $text ) == $width ) {
            return $text;
        }
        $text = ' ' . $text;
    }

    return $text;
}

#############################################################################
#############################################################################
1
