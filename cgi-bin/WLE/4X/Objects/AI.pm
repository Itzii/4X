package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::Methods::Simple qw( matches_any );

use WLE::4X::Enums::Status;
use WLE::4X::Enums::Basic;

#############################################################################

sub ai_descision_allocate_hits {
    my $self            = shift;
    my $attacking_tag   = shift;
    my @hits            = @_;

    my @allocated_hits = ();

    my $real_player_id = $self->real_player_in_combat();
    my $attacking_template = $self->ship_templates()->{ $attacking_tag };

    my @parsed_hits = ();
    foreach my $hit ( @hits ) {
        my ( $strength, $roll ) = split( /:/, @hits );
        push( @parsed_hits, { 'strength' => $strength, 'roll' => $roll } );
    }

    @parsed_hits = sort { $b->{'strength'} <=> $a->{'strength'} } @parsed_hits;


    # get all potential targets

    my %ships = ();
    foreach my $ship_tag ( $self->tiles()->{ $self->current_tile() }->ships()->items() ) {
        if ( $self->ships()->{ $ship_tag }->owner_id() == $real_player_id ) {
            $ships{ $ship_tag } = $ship;
        }
    }

    # sort the ships by size

    my @ships_sized = sort { $b->template()->cost() <=> $a->template()->cost() } values( %ships );



    my @ships_not_destroyed = @ships_sized;
    my %damage_to_ships = ();

    # distribute damage to destroy the biggest first if possible

    while ( scalar( @parsed_hits ) > 0 && scalar( @ships_not_destroyed ) > 0 ) {
        my $target_ship = $ships_not_destroyed[ 0 ];

        my $to_kill = $target_ship->hits_to_kill();

        foreach my $hit ( @parsed_hits ) {

        }



    }










}

#############################################################################

sub _ai_hits_to_total {
    my $self            = shift;
    my $needed_total    = shift;
    my $min_roll        = shift;
    my @parsed_hits     = @_;

    my $actual_total = 0;

    foreach my $hit ( @parsed_hits ) {
        if ( $hit->{'roll'} >= $min_roll ) {
            $actual_total += $hit->{'strength'};
        }
    }

    if ( $actual_total < $needed_total ) {
        return ();
    }

    


}







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
