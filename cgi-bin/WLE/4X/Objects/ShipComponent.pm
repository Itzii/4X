package WLE::4X::Objects::ShipComponent;

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

    $args{'type'} = 'shipcomponent';

    $self->WLE::4X::Objects::Element::_init( %args );

    $self->{'TECH_REQUIRED'} = '';

    $self->{'ENERGY_USE'} = 0;

    $self->{'INITIATIVE'} = 0;
    $self->{'ENERGY'} = 0;
    $self->{'HULL_POINTS'} = 0;
    $self->{'COMPUTER'} = 0;
    $self->{'MOVEMENT'} = 0;
    $self->{'SHIELD'} = 0;

    $self->{'ATTACK_COUNT'} = 0;
    $self->{'ATTACK_DAMAGE'} = 0;

    $self->{'IS_MISSILE'} = 0;

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub tech_required {
    my $self        = shift;

    return $self->{'TECH_REQUIRED'};
}

#############################################################################

sub initiative {
    my $self        = shift;

    return $self->{'INITIATIVE'};
}

#############################################################################

sub energy {
    my $self        = shift;

    return $self->{'ENERGY'};
}

#############################################################################

sub energy_used {
    my $self        = shift;

    return $self->{'ENERGY_USE'};
}

#############################################################################

sub hull_points {
    my $self        = shift;

    return $self->{'HULL_POINTS'};
}

#############################################################################

sub computer {
    my $self        = shift;

    return $self->{'COMPUTER'};
}

#############################################################################

sub movement {
    my $self        = shift;

    return $self->{'MOVEMENT'};
}

#############################################################################

sub shield {
    my $self        = shift;

    return $self->{'SHIELD'};
}

#############################################################################

sub attack_count {
    my $self        = shift;

    return $self->{'ATTACK_COUNT'};
}

#############################################################################

sub attack_damage {
    my $self        = shift;

    return $self->{'ATTACK_DAMAGE'};
}

#############################################################################

sub is_missile {
    my $self        = shift;

    return $self->{'IS_MISSILE'};
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    if ( defined( $r_hash->{'REQUIRES'} ) ) {
        $self->{'TECH_REQUIRED'} = $r_hash->{'REQUIRES'};
    }

    foreach my $tag ( 'INITIATIVE', 'ENERGY', 'ENERGY_USE', 'HULL_POINTS', 'COMPUTER', 'MOVEMENT', 'SHIELD', 'ATTACK_COUNT', 'ATTACK_DAMAGE', 'IS_MISSILE' ) {
        if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
            $self->{ $tag } = $r_hash->{ $tag };
        }
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

    $r_hash->{'REQUIRES'} = $self->tech_required();

    $r_hash->{'INITIATIVE'} = $self->initiative();
    $r_hash->{'ENERGY'} = $self->energy();
    $r_hash->{'ENERGY_USE'} = $self->energy_used();
    $r_hash->{'HULL_POINTS'} = $self->hull_points();
    $r_hash->{'COMPUTER'} = $self->computer();
    $r_hash->{'MOVEMENT'} = $self->movement();
    $r_hash->{'SHIELD'} = $self->shield();
    $r_hash->{'ATTACK_COUNT'} = $self->attack_count();
    $r_hash->{'ATTACK_DAMAGE'} = $self->attack_damage();
    $r_hash->{'IS_MISSILE'} = $self->is_missile();

    return 1;
}

#############################################################################
#############################################################################
1
