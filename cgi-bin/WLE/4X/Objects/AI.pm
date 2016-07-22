package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;


#############################################################################

sub ai_decision_apply_missile_defense {
    my $self            = shift;
    my $defense_count   = shift;
    my %hits            = @_;

    # TODO I'm sure this can be improved

    my %ships = ();
    foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
        if ( $self->ships()->{ $ship_tag }->owner_id() == -1 ) {
            $ships{ $ship_tag } = $ship;
        }
    }

    my %final_hits = ();
    my @defended_hits = ();

    foreach my $ship_tag ( keys( %hits ) ) {
        my @undefended_hits = ();
        my @ship_hits = split( /,/, $hits{ $ship_tag } );

        foreach my $single_hit ( @ship_hits ) {
            my ( $strength, $roll ) = split( ':', $single_hit );
            # in this current implementation, we don't care about the strength of the hit
            # but the info is here

            if ( $defense_count > 0 ) {
                push( @defended_hits, $single_hit );
                $defense_count--;
            }
            else {
                push( @undefended_hits, $single_hit );
            }
        }

        $final_hits{ $ship_tag } = join( ',', @undefended_hits );
    }

    if ( scalar( @defended_hits ) > 0 ) {
        $final_hits{ 'countered' } = join( ',', @defended_hits );
    }

    return %final_hits;
}


#############################################################################
#############################################################################
1
