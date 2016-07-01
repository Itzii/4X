package WLE::4X::Methods::Simple;

use strict;
use warnings;

our @ISA       = qw( Exporter );
our @EXPORT    = qw(

    looks_like_number
    matches_any
    shuffle_in_place

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
#############################################################################
1
