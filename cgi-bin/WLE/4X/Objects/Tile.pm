package WLE::4X::Objects::Tile;

use strict;
use warnings;


use WLE::4X::Methods::Simple;

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

    $args{'type'} = 'tile';

    $self->WLE::4X::Objects::Element::_init( %args );

    $self->{'ID'} = 0;
    $self->{'STACK'} = 0;
    $self->{'VP'} = 0;

    $self->{'WARPS'} = 0;

    $self->{'ANCIENT_LINK'} = 0;
    $self->{'WORMHOLE'} = 0;
    $self->{'HIVE'} = 0;
    $self->{'DISCOVERY'} = 0;
    $self->{'ORBITAL'} = 0;
    $self->{'MONOLITH'} = 0;

    $self->{'ANCIENTS'} = 0;
    $self->{'GCDS'} = 0;
    $self->{'DESTROYER'} = 0;


    $self->{'RESOURCE_SLOTS'} = [];

    return $self;
}

#############################################################################

sub tile_id {
    my $self        = shift;

    return $self->{'ID'};
}

#############################################################################

sub which_stack {
    my $self        = shift;

    return $self->{'STACK'};
}

#############################################################################

sub base_vp {
    my $self        = shift;

    return $self->{'VP'};
}

#############################################################################

sub total_vp {
    my $self        = shift;

    return $self->vp() + ( $self->monolith() * 3 );
}

#############################################################################

sub has_ancient_link {
    my $self        = shift;

    return $self->{'ANCIENT_LINK'};
}

#############################################################################

sub has_wormhole {
    my $self        = shift;

    return $self->{'WORMHOLE'};
}

#############################################################################

sub is_hive {
    my $self        = shift;

    return $self->{'HIVE'};
}

#############################################################################

sub discovery_count {
    my $self        = shift;

    return $self->{'DISCOVERY'};
}

#############################################################################

sub orbital_count {
    my $self        = shift;

    return $self->{'ORBITAL'};
}

#############################################################################

sub monolith_count {
    my $self        = shift;

    return $self->{'MONOLITH'};
}

#############################################################################

sub ancient_count {
    my $self        = shift;

    return $self->{'ANCIENT'};
}

#############################################################################

sub gcds_count {
    my $self        = shift;

    return $self->{'GCDS'};
}

#############################################################################

sub destroyer_count {
    my $self        = shift;

    return $self->{'DESTROYER'};
}

#############################################################################




#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;
    my $flag_m      = shift; $flag_m = 1                unless defined( $flag_m );

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'ID'} ) ) {
        return 0;
    }

    $self->{'ID'} = $r_hash->{'ID'};

    unless ( defined( $r_hash->{'WARPS'} ) ) {
        return 0;
    }

    $self->{'WARPS'} = $r_hash->{'WARPS'};

    unless ( defined( $r_hash->{'STACK'} ) ) {
        return 0;
    }

    $self->{'STACK'} = $r_hash->{'STACK'};

    foreach my $tag ( 'VP', 'ANCIENT_LINK', 'HIVE', 'DISCOVERY', 'ORBITAL', 'MONOLITH', 'ANCIENTS', 'GCDS', 'DESTROYER' ) {
        if ( defined( $r_hash->{ $tag } ) ) {
            if ( looks_like_number( $r_hash->{ $tag } ) ) {
                $self->{ $tag } = $r_hash->{ $tag };
            }
        }
    }

    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        if ( ref( $r_hash->{'RESOURCES'} ) eq 'ARRAY' ) {
            my @resources;

            foreach my $slot ( @{ $r_hash->{'RESOURCES'} } ) {
                if ( ref( $slot ) eq 'HASH' ) {
                    my %local_slot = ( 'TYPE' => 'wild', 'FILLED' => 0, 'ADVANCED' => 0 );
                    if ( defined( $slot->{'TYPE'} ) ) {
                        $local_slot{'TYPE'} = $slot->{'TYPE'};
                    }
                    if ( looks_like_number( $slot->{'FILLED'} ) ) {
                        $local_slot{'FILLED'} = $slot->{'FILLED'};
                    }
                    if ( looks_like_number( $slot->{'ADVANCED'} ) ) {
                        $local_slot{'ADVANCED'} = $slot->{'ADVANCED'};
                    }

                    push( @resources, \%local_slot );
                }
            }

            $self->{'RESOURCE_SLOTS'} = \@resources;
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

    $r_hash->{'CATEGORY'} = $self->category();

    $r_hash->{'BASE_COST'} = $self->base_cost();
    $r_hash->{'MIN_COST'} = $self->min_cost();

    $r_hash->{'PROVIDES'} = @{ $self->provides() };

    return 1;
}

#############################################################################
#############################################################################
1
