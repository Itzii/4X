package WLE::4X::Objects::Tile;

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

    $args{'type'} = 'tile';

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

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

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

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

    return $self->{'ANCIENTS'};
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

sub has_warp_on_side {
    my $self        = shift;
    my $direction   = shift;

    unless ( looks_like_number( $direction ) ) {
        return 0;
    }

    while ( $direction < 0 ) {
        $direction += 6;
    }

    while ( $direction > 5 ) {
        $direction -= 6;
    }

    my $bitmask = 2 ** $direction;

    return ( ( $self->{'WARPS'} & $bitmask ) > 0 ) ? 1 : 0;
}


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
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
                $self->{ $tag } = $r_hash->{ $tag };
            }
        }
    }

    if ( defined( $r_hash->{'RESOURCES'} ) ) {
        if ( ref( $r_hash->{'RESOURCES'} ) eq 'ARRAY' ) {
            my @resources = ();

            foreach my $slot ( @{ $r_hash->{'RESOURCES'} } ) {
                if ( ref( $slot ) eq 'HASH' ) {
                    my %local_slot = ( 'TYPE' => 'wild', 'FILLED' => 0, 'ADVANCED' => 0 );
                    if ( defined( $slot->{'TYPE'} ) ) {
                        $local_slot{'TYPE'} = $slot->{'TYPE'};
                    }
                    if ( WLE::Methods::Simple::looks_like_number( $slot->{'FILLED'} ) ) {
                        $local_slot{'FILLED'} = $slot->{'FILLED'};
                    }
                    else {
                        $local_slot{'FILLED'} = 0;
                    }
                    if ( WLE::Methods::Simple::looks_like_number( $slot->{'ADVANCED'} ) ) {
                        $local_slot{'ADVANCED'} = $slot->{'ADVANCED'};
                    }
                    else {
                        $local_slot{'ADVANCED'} = 0;
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

    $r_hash->{'ID'} = sprintf( '%03i', $self->tile_id() );

    $r_hash->{'WARPS'} = $self->{'WARPS'};

    $r_hash->{'STACK'} = $self->{'STACK'};

    foreach my $tag ( 'VP', 'ANCIENT_LINK', 'HIVE', 'DISCOVERY', 'ORBITAL', 'MONOLITH', 'ANCIENTS', 'GCDS', 'DESTROYER' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    $r_hash->{'RESOURCES'} = $self->{'RESOURCE_SLOTS'};

    return 1;
}

#############################################################################

sub as_ascii {
    my $self        = shift;

    my @display = (
        '     -------------',
        '    / XXX  0 HIVE \\',
        '   / MON WORM ORB  \\',
        '  /5               1\\',
        ' /                   \\',
        '/ s   m   c   w       \\',
        '\ s+  m+  c+  W       /',
        ' \                   /',
        '  \4  ANC    DISC  2/',
        '   \xxxxxxxxxxxxxxx/',
        '    \      3      /',
        '     -------------',
    );

    my $id = sprintf( '%03i', $self->tile_id() );
    my $name = substr( sprintf( '%-15s', $self->long_name() ), 0, 15 );
    my $ancient_count = $self->ancient_count();
    my $disc_count = $self->discovery_count();

    foreach $_ ( @display ) {

        foreach my $direction ( 0 .. 5 ) {
            if ( $self->has_warp_on_side( $direction ) ) {
                $_ =~ s{ $direction }{O}xs;
            }
            else {
                $_ =~ s{ $direction }{ }xs;
            }
        }

        $_ =~ s{ XXX }{$id}xsm;

        $_ =~ s{ xxxxxxxxxxxxxxx }{$name}xs;

        unless ( $self->monolith_count() > 0 ) {
            $_ =~ s{MON}{   }xs;
        }

        unless ( $self->orbital_count() > 0 ) {
            $_ =~ s{ORB}{   }xs;
        }

        if ( $ancient_count > 0 ) {
            $_ =~ s{ANC\s}{ANC$ancient_count}xs;
        }
        else {
            $_ =~ s{ANC\s}{    }xs;
        }

        unless ( $disc_count > 0 ) {
            $_ =~ s{DISC}{    }xs;
        }

        unless ( $self->has_wormhole() ) {
            $_ =~ s{WORM}{    }xs;
        }

        unless ( $self->is_hive() ) {
            $_ =~ s{HIVE}{    }xs;
        }
    }












    return join( "\n", @display );
}

#############################################################################
#############################################################################
1
