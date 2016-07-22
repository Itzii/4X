package WLE::4X::Objects::Ship;

use strict;
use warnings;

use parent 'WLE::4X::Objects::Element';

#############################################################################
# constructor args
#
# 'server'		- required
#

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

    $args{'type'} = 'ship';

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    unless ( defined( $args{'template'} ) ) {
        return undef;
    }

    $self->set_owner_id( $args{'owner_id'} );

    $self->{'TEMPLATE_TAG'} = $args{'template'}->tag();

    $self->{'DAMAGE'} = 0;
    $self->{'FLAG_RETREAT'} = 0;

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub create_from_template {
    my $self        = shift;
    my $owner_id    = shift;
    my $template    = shift;

    $self->set_owner_id( $owner_id );

    $self->{'TEMPLATE_TAG'} = $template->tag();
}

#############################################################################

sub template {
    my $self        = shift;

    return $self->server()->templates( $self->{'TEMPLATE_TAG'} );
}

#############################################################################

sub class {
    my $self        = shift;

    return $self->template()->class();
}

#############################################################################

sub total_initiative {
    my $self        = shift;

    return $self->template()->total_initiative();
}

#############################################################################

sub total_energy {
    my $self        = shift;

    return $self->template()->total_energy();
}

#############################################################################

sub total_computer {
    my $self        = shift;

    return $self->template()->total_computer();
}

#############################################################################

sub total_shields {
    my $self        = shift;

    return $self->template()->total_shields();
}

#############################################################################

sub total_hull_points {
    my $self        = shift;

    return $self->template()->total_hull_points();
}

#############################################################################

sub total_movement {
    my $self        = shift;

    return $self->template()->total_movement();
}

#############################################################################

sub provides {
    my $self        = shift;

    return $self->template()->provides();
}

#############################################################################

sub does_provide {
    my $self        = shift;
    my $tag         = shift;

    foreach my $provide_tag ( $self->provides() ) {
        if ( $tag eq $provide_tag ) {
            return 1;
        }
    }

    if ( $self->owner_id() ) {
        my $race = $self->server()->race_of_player_id( $self->owner_id() );
        if ( $race->has_technology( $tag ) ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub total_missile_attacks {
    my $self        = shift;

    return $self->template()->total_missile_attacks();
}

#############################################################################

sub roll_missile_attacks {
    my $self        = shift;

    return $self->_roll_attacks( 1 );
}

#############################################################################

sub total_beam_attacks {
    my $self        = shift;

    return $self->template()->total_beam_attacks();
}

#############################################################################

sub roll_beam_attacks {
    my $self        = shift;

    return $self->_roll_attacks( 0 );
}

#############################################################################

sub _roll_attacks {
    my $self            = shift;
    my $flag_missile    = shift;

    my %total_attacks = ();

    if ( $flag_missile ) {
        %total_attacks = $self->total_missile_attacks();
    }
    else {
        %total_attacks = $self->total_beam_attacks();
    }

    my @attack_rolls = ();

    foreach my $strength ( keys( %total_attacks ) ) {
        for ( 1 .. $total_attacks{ $strength } ) {
            push( @attack_rolls, { 'strength' => $strength, 'roll' => $self->server()->roll_die() } );
        }
    }

    return @attack_rolls;
}

#############################################################################

sub roll_missile_defense {
    my $self            = shift;

    my $missile_defense_hits = 0;

    if ( $self->does_provide( 'tech_missile_defense' ) ) {
        my @attacks = $self->roll_beam_attacks();

        foreach my $attack ( @attacks ) {
            if ( $attack->{'roll'} + $self->total_computer() >= 6 ) {
                if ( $ship->does_provide( 'tech_beam_splitter' ) ) {
                    $missile_defense_hits += $attack->{'strength'};
                }
                else {
                    $missile_defense_hits += 1;
                }
            }
        }
    }

    return $missile_defense_hits;
}

#############################################################################

sub vp_draw {
    my $self        = shift;

    return $self->template()->vp_draw();
}

#############################################################################

sub components {
    my $self        = shift;

    return $self->template()->components();
}

#############################################################################

sub damage {
    my $self        = shift;

    return $self->{'DAMAGE'};
}

#############################################################################

sub add_damage {
    my $self        = shift;
    my $value       = shift;

    if ( looks_like_number( $value ) ) {
        $self->{'DAMAGE'} += $value;
    }

    return;
}

#############################################################################

sub clear_damage {
    my $self        = shift;

    $self->{'DAMAGE'} = 0;

    return;
}

#############################################################################

sub hits_to_kill {
    my $self        = shift;

    return $self->template()->total_hull_points() + 1 - $self->damage();
}

#############################################################################

sub is_destroyed {
    my $self        = shift;

    return ( $self->hits_to_kill() < 1 );
}

#############################################################################

sub is_retreating {
    my $self        = shift;

    return $self->{'FLAG_RETREAT'};
}

#############################################################################

sub set_retreating {
    my $self        = shift;
    my $value       = shift;

    $self->{'FLAG_RETREAT'} = $value;

    return;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;
    my $flag_m      = shift; $flag_m = 1                unless defined( $flag_m );

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'TEMPLATE_TAG'} ) ) {
        return 0;
    }

    $self->{'TEMPLATE_TAG'} = $r_hash->{'TEMPLATE_TAG'};

    if ( looks_like_number( $r_hash->{ 'DAMAGE' } ) ) {
        $self->{ 'DAMAGE' } = $r_hash->{ 'DAMAGE' };
    }

    if ( looks_like_number( $r_hash->{ 'FLAG_RETREAT' } ) ) {
        $self->{ 'FLAG_RETREAT' } = $r_hash->{ 'FLAG_RETREAT' };
    }

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( $self->WLE::4X::Objects::Element::to_hash( $r_hash ) ) {
        return 0;
    }

    foreach my $tag ( 'TEMPLATE_TAG', 'DAMAGE', 'FLAG_RETREAT' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    return 1;
}

#############################################################################
#############################################################################
1
