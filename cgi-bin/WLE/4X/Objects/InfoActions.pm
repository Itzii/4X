package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );


#############################################################################

sub info_board {
    my $self            = shift;
    my %args            = @_;

    if ( defined( $args{'flag_ascii'} ) ) {
        my @grid = $self->board()->as_ascii();

        $self->set_returned_data( join( "\n", @grid ) );
    }

    return 1;
}



















#############################################################################
#############################################################################
1
