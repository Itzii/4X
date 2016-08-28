package WLE::4X::Objects::ShipTemplate;

use strict;
use warnings;

use WLE::4X::Enums::Basic;

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

    $args{'type'} = 'shiptemplate';

    unless ( $self->WLE::4X::Objects::Element::_init( %args ) ) {
        return undef;
    }

    $self->{'CLASS'} = '';
    $self->{'INITIATIVE'} = 0;
    $self->{'ENERGY'} = 0;
    $self->{'COMPUTER'} = 0;
    $self->{'SHIELDS'} = 0;
    $self->{'HULL_POINTS'} = 0;

    $self->{'SLOTS'} = 0;

    $self->{'COMPONENTS'} = WLE::Objects::Stack->new();
    $self->{'ORIGINAL_COMPONENTS'} = WLE::Objects::Stack->new();

    $self->{'VP_DRAW'} = 0;

    $self->{'COST'} = 0;

    if ( defined( $args{'hash'} ) ) {
        if ( $self->from_hash( $args{'hash'} ) ) {
            return $self;
        }
        return undef;
    }

    return $self;
}

#############################################################################

sub class {
    my $self        = shift;

    return $self->{'CLASS'};
}

#############################################################################

sub cost {
    my $self        = shift;

    return $self->{'COST'};
}

#############################################################################

sub set_cost {
    my $self        = shift;
    my $value       = shift;

    $self->{'COST'} = $value;

    return;
}

#############################################################################

sub initiative {
    my $self        = shift;

    return $self->{'INITIATIVE'};
}

#############################################################################

sub total_initiative {
    my $self        = shift;

    my $init = $self->initiative();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $init += $component->initiative();
        }
    }

    return $init;
}

#############################################################################

sub energy {
    my $self        = shift;

    return $self->{'ENERGY'};
}

#############################################################################

sub total_energy {
    my $self        = shift;

    my $energy = $self->energy();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $energy += $component->energy();
        }
    }

    return $energy;
}

#############################################################################

sub computer {
    my $self        = shift;

    return $self->{'COMPUTER'};
}

#############################################################################

sub total_computer {
    my $self        = shift;

    my $computer = $self->computer();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $computer += $component->computer();
        }
    }

    return $computer;
}

#############################################################################

sub shields {
    my $self        = shift;

    return $self->{'SHIELDS'};
}

#############################################################################

sub total_shields {
    my $self        = shift;

    my $shields = $self->shields();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $shields += $component->shield();
        }
    }

    return $shields;
}

#############################################################################

sub hull_points {
    my $self        = shift;

    return $self->{'HULL_POINTS'};
}

#############################################################################

sub total_hull_points {
    my $self        = shift;

    my $hull = $self->hull_points();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $hull += $component->hull_points();
        }
    }

    return $hull;
}

#############################################################################

sub total_energy_used {
    my $self       = shift;

    my $energy = 0;

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $energy += $component->energy_used();
        }
    }

    return $energy;
}

#############################################################################

sub total_movement {
    my $self        = shift;

    my $move = 0;

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $move += $component->movement();
        }
    }

    return $move;
}

#############################################################################

sub provides {
    my $self        = shift;

    my %provide_tags = ();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            foreach my $provide_tag ( $component->provides() ) {
                $provide_tags{ $provide_tag } = 1;
            }
        }
    }

    return keys( %provide_tags );
}

#############################################################################

sub add_component {
    my $self            = shift;
    my $new_tag         = shift;
    my $slot_number     = shift;
    my $r_message       = shift;
    my $flag_real       = shift; $flag_real = 1                    unless defined( $flag_real );

    if ( $slot_number < 0 || $slot_number >= $self->components()->count() ) {
        $$r_message = 'Invalid Slot Number';
        return 0;
    }

    my @test_components = $self->components()->items();
    $test_components[ $slot_number ] = $new_tag;

    $$r_message = $self->_problem( @test_components );

    unless ( $$r_message eq '' ) {
        return 0;
    }

    if ( $flag_real ) {
        $self->components()->fill( @test_components );
    }

    return 1;
}

#############################################################################

sub remove_component {
    my $self            = shift;
    my $slot_number     = shift;
    my $r_message       = shift;
    my $flag_real       = shift; $flag_real = 1                    unless defined( $flag_real );

    my @new_components = ();

    if ( $slot_number < 0 || $slot_number >= $self->components()->count() ) {
        $$r_message = 'Invalid Slot Number';
        return 0;
    }

    if ( $self->components()->item_at_index( $slot_number ) eq '' ) {
        $$r_message = 'Unable to locate removable component.';
        return 0;
    }

    my @test_components = $self->merged_components();
    $test_components[ $slot_number ] = $self->original_components()->item_at_index( $slot_number );

    $$r_message = $self->_problem( @test_components );

    unless ( $$r_message eq '' ) {
        return 0;
    }

    if ( $flag_real) {
        my @new_components = $self->components()->items();
        $new_components[ $slot_number ] = '';
        $self->components()->fill( @new_components );
    }

    return 1;
}

#############################################################################

sub _problem {
    my $self        = shift;
    my @components  = @_;

    my $flag_contains_drive = 0;

    foreach my $component_tag ( @components ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            if ( matches_any( 'ship_drive', $component->provides() ) ) {
                $flag_contains_drive = 1;
            }
        }
    }

    if ( $self->class() eq 'class_starbase' ) {
        if ( $flag_contains_drive ) {
            return 'A ship of this class may not contain a drive.';
        }
    }
    else {
        unless ( $flag_contains_drive ) {
            return 'A ship of this class must contain a drive.';
        }
    }

    my $energy_used = 0;

    foreach my $component_tag ( @components ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $energy_used += $component->energy_used();
        }
    }

    my $energy_provided = $self->energy();

    foreach my $component_tag ( @components ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {
            $energy_provided += $component->energy();
        }
    }


    if ( $energy_used > $energy_provided ) {
        return 'Energy requirements not met.'
    }

    return '';
}


#############################################################################

sub total_missile_attacks {
    my $self        = shift;

    return $self->_total_attacks( 1 );
}

#############################################################################

sub total_beam_attacks {
    my $self        = shift;

    return $self->_total_attacks( 0 );
}

#############################################################################

sub _total_attacks {
    my $self            = shift;
    my $flag_missile    = shift;

    my %attacks = ();

    foreach my $component_tag ( $self->merged_components() ) {
        my $component = $self->server()->ship_components()->{ $component_tag };

        if ( defined( $component ) ) {

            if ( $component->is_missile() == $flag_missile ) {
                if ( $component->attack_count() > 0 ) {

                    unless ( defined( $attacks{ $component->attack_damage() } ) ) {
                        $attacks{ $component->attack_damage() } = 0;
                    }

                    $attacks{ $component->attack_damage() } += $component->attack_count();
                }
            }
        }
    }

    return %attacks;
}


#############################################################################

sub slots {
    my $self        = shift;

    return $self->{'SLOTS'};
}

#############################################################################

sub components {
    my $self        = shift;

    return $self->{'COMPONENTS'};
}

#############################################################################

sub original_components {
    my $self        = shift;

    return $self->{'ORIGINAL_COMPONENTS'};
}

#############################################################################

sub merged_components {
    my $self            = shift;

    my @components = $self->components()->items();
    my @orig_components = $self->original_components()->items();

    foreach my $index ( 0 .. scalar( @orig_components ) - 1 ) {
        unless ( $components[ $index ] eq '' ) {
            $orig_components[ $index ] = $components[ $index ];
        }
    }

    return @orig_components;
}

#############################################################################

sub vp_draw {
    my $self        = shift;

    return $self->{'VP_DRAW'};
}

#############################################################################

sub copy_of {
    my $self        = shift;
    my $new_tag     = shift;

    my $copy = $self->WLE::4X::Objects::Element::copy_of( $new_tag );

    bless( $copy, 'WLE::4X::Objects::ShipTemplate' );

    $copy->{'CLASS'} = $self->{'CLASS'};
    $copy->{'COST'} = $self->{'COST'};

    $copy->{'INITIATIVE'} = $self->{'INITIATIVE'};
    $copy->{'ENERGY'} = $self->{'ENERGY'};
    $copy->{'COMPUTER'} = $self->{'COMPUTER'};
    $copy->{'SHIELDS'} = $self->{'SHIELDS'};
    $copy->{'HULL_POINTS'} = $self->{'HULL_POINTS'};

    $copy->{'SLOTS'} = $self->{'SLOTS'};

    $copy->{'COMPONENTS'} = WLE::Objects::Stack->new();
    $copy->{'ORIGINAL_COMPONENTS'} = WLE::Objects::Stack->new();

    $copy->{'ORIGINAL_COMPONENTS'}->fill( $self->{'COMPONENTS'}->items() );


    foreach ( $self->original_components()->items() ) {
        $self->components()->add_items( '' );
    }

    $copy->{'VP_DRAW'} = $self->{'VP_DRAW'};

    return $copy;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless( $self->WLE::4X::Objects::Element::from_hash( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'CLASS'} ) ) {
        return 0;
    }

    $self->{ 'CLASS' } = $r_hash->{'CLASS'};

    foreach my $tag ( 'VP_DRAW', 'INITIATIVE', 'ENERGY', 'COMPUTER', 'SHIELDS', 'SLOTS', 'HULL_POINTS', 'COST' ) {
        if ( defined( $r_hash->{ $tag } ) ) {
            if ( WLE::Methods::Simple::looks_like_number( $r_hash->{ $tag } ) ) {
                $self->{ $tag } = $r_hash->{ $tag };
            }
        }
    }

    if ( defined( $r_hash->{'COMPONENTS'} ) ) {
        $self->components()->fill( @{ $r_hash->{'COMPONENTS'} } );
    }
    while ( $self->components()->count() < $self->slots() ) {
        $self->components()->add_items( '' );
    }

    if ( defined( $r_hash->{'ORIGINAL_COMPONENTS'} ) ) {
        $self->original_components()->fill( @{ $r_hash->{'ORIGINAL_COMPONENTS'} } );
    }
    while ( $self->original_components()->count() < $self->slots() ) {
        $self->original_components()->add_items( '' );
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

    foreach my $tag ( 'VP_DRAW', 'INITIATIVE', 'CLASS', 'ENERGY', 'COMPUTER', 'SHIELDS', 'SLOTS', 'HULL_POINTS', 'COST' ) {
        $r_hash->{ $tag } = $self->{ $tag };
    }

    $r_hash->{'COMPONENTS'} = [ $self->components()->items() ];
    $r_hash->{'ORIGINAL_COMPONENTS'} = [ $self->original_components()->items() ];

    return 1;
}

#############################################################################
#############################################################################
1
