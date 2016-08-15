package WLE::4X::Server::Server;

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

    # try killing any ships with single hits

    my @remaining_ships = ();

    foreach my $target_ship ( @ships_not_destroyed ) {
        my ( $flag_killed, @parsed_hits ) = $self->_ai_try_killing_ship_with_single_hit(
            $target_ship,
            $attacking_template,
            \%damage_to_ships,
            @parsed_hits,
        );

        unless ( $flag_killed ) {
            push( @remaining_ships, $target_ship );
        }
    }

    @ships_not_destroyed = @remaining_ships;

    if ( scalar( @parsed_hits ) == 0 ) {
        return $self->_ai_formatted_hits( %damage_to_ships );
    }
    elsif ( scalar( @ships_not_destroyed ) > 0 ) {
        # now see if we can kill any ship with multiple hits

        foreach my $target_ship ( @ships_not_destroyed ) {
            my ( $flag_killed, @parsed_hits ) = $self->_ai_try_killing_ship_with_multiple_hits(
                $target_ship,
                $attacking_template,
                \%damage_to_ships,
                @parsed_hits,
            );

            unless ( $flag_killed ) {
                push( @remaining_ships, $target_ship );
            }
        }
    }

    if ( scalar( @parsed_hits ) == 0 ) {
        return $self->_ai_formatted_hits( %damage_to_ships );
    }
    else {
        # allocate remaining damage to the largest ship
        my $biggest_ship_tag = $ships_sized[ 0 ];
        foreach my $hit ( @parsed_hits ) {
            if ( defined( $damage_to_ships{ $biggest_ship_tag } ) ) {
                push( @{ $damage_to_ships{ $biggest_ship_tag } }, $hit->{'strength'} . ':' . $HIT->{'roll'} );
            }
                else {
                $damage_to_ships{ $biggest_ship_tag } = [ $hit->{'strength'} . ':' . $hit->{'roll'} ];
            }
        }
    }

    return $self->_ai_formatted_hits( %damage_to_ships );
}

#############################################################################

sub _ai_try_killing_ship_with_single_hit {
    my $self                = shift;
    my $defender_ship       = shift;
    my $attacker_template   = shift;
    my $r_damage_to_ships   = shift;
    my @rolls               = shift;

    my $hit_to_ship = $self->_ai_smallest_to_destroy( $defender_ship, $attacker_template, 1, @rolls );

    my @remaining_hits = ();

    unless ( defined( $hit_to_ship ) ) {
        return ( 0, @remaining_hits );
    }

    $r_damage_to_ships->{ $defender_ship->tag() } = [ $hit_to_ship->{'strength'} . ':' . $hit_to_ship->{'roll'} ];
    foreach my $hit ( @rolls ) {
        unless ( $hit == $hit_to_ship ) {
            push( @remaining_hits, $hit );
        }
    }

    return ( 1, @remaining_hits );
}

#############################################################################

sub _ai_try_killing_ship_with_multiple_hits {
    my $self                = shift;
    my $defender_ship       = shift;
    my $attacker_template   = shift;
    my $r_damage_to_ships   = shift;
    my @rolls               = shift;

    my @usable_hits = ();

    foreach my $hit ( @rolls ) {
        if ( $self->does_roll_hit_ship( $hit->{'roll'}, $attacker_template, $defender_ship->template() ) ) {
            push( @usable_hits, $hit );
        }
    }

    @usable_hits = sort { $b->{'strength'} <=> $a->{'strength'} } @usable_hits;

    my $hits_to_kill = $defender_ship->hits_to_kill();

    my @applied_hits = ();
    my $total_damage = 0;

    do {
        push( @applied_hits, shift( @usable_hits ) );
        $total_damage += $applied_hits[ -1 ];

        if ( $total_damage < $hits_to_kill ) {
            foreach my $hit ( reverse( @usable_hits ) ) {
                if ( $total_damage + $hit->{'strength'} >= $hits_to_kill ) {
                    push( @applied_hits, $hit );
                    last;
                }
            }
        }

    } until ( $total_damage >= $hits_to_kill || scalar( @usable_hits ) == 0 );

    foreach my $hit ( @applied_hits ) {
        if ( defined( $r_damage_to_ships->{ $defender_ship->tag() } ) ) {
            push( @{ $r_damage_to_ships->{ $defender_ship->tag() } }, $hit->{'strength'} . ':' . $hit->{'roll'} );
        }
        else {
            $r_damage_to_ships->{ $defender_ship->tag() } = [ $hit->{'strength'} . ':' . $hit->{'roll'} ];
        }
    }

    my @remaining_hits = ();
    foreach my $hit ( @rolls ) {
        unless ( matches_any( $hit, @applied_hits ) ) {
            push( @remaining_hits, $hit );
        }
    }

    return ( ( $total_damage >= $hits_to_kill ) ? 1 : 0, @remaining_hits );
}

#############################################################################

sub _ai_smallest_to_destroy {
    my $self                = shift;
    my $defender_ship       = shift;
    my $attacker_template   = shift;
    my $flag_kill_only      = shift;
    my @rolls               = shift;

    @rolls = sort { $a->{'strength'} <=> $b->{'strength'} } @rolls;

    my $hits_to_kill = $defender_ship->hits_to_kill();

    foreach my $hit ( @rolls ) {
        if ( $self->does_roll_hit_ship( $hit->{'roll'}, $attacker_template, $defender_ship->template() ) ) {
            if ( $hit->{'strength'} >= $hits_to_kill ) {
                return $hit;
            }
        }
    }

    if ( $flag_kill_only ) {
        return undef;
    }

    return $rolls[ -1 ];
}

#############################################################################

sub _ai_formatted_hits {
    my $self            = shift;
    my %damage_to_ships = @_;

    my @hits = ();

    foreach my $ship_tag ( keys( %damage_to_ships ) ) {
        foreach my $hit_on_ship ( @{ $damage_to_ships{ $ship_tag } } ) {
            push( @hits, $ship_tag . ':' . $hit_on_ship );
        }
    }

    return @hits;
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
