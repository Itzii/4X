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

sub info_race {
    my $self            = shift;
    my %args            = @_;

    my $player_id = $args{'player_id'};

    if ( $player_id > $self->user_ids()->count() - 1 ) {
        $self->set_error( 'Invalid Player ID' );
        return 0;
    }

    my @ids = ( 0 .. $self->user_ids()->count() - 1 );

    if ( $player_id > -1 ) {
        @ids = ( $player_id );
    }

    if ( defined( $args{'flag_ascii'} ) ) {

        my @ascii_final = ();

        foreach my $player_id ( @ids ) {
            my $race = $self->race_of_player_id( $player_id );

            if ( defined( $race ) ) {
                push( @ascii_final, join( "\n", $race->as_ascii() ) );
            }
        }

        $self->set_returned_data( join( "\n\n", @ascii_final ) );
    }

    return 1;
}

















#############################################################################
#############################################################################
1
