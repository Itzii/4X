package WLE::4X::Objects::Board;

use strict;
use warnings;

use WLE::Objects::Stack;

use WLE::4X::Objects::Tile;

#############################################################################
# constructor args
#
# 'server'		- required
#

sub new {
    my $class		= shift;
    my %args		= @_;

    my $self = bless {}, $class;

    $args{'type'} = 'board';

    return $self->_init( %args );
}

#############################################################################

sub _init {
    my $self		= shift;
    my %args		= @_;

    unless ( defined( $args{'server'} ) ) {
        return undef;
    }

    $self->{'SERVER'} = $args{'server'};

    $self->{'SPACES'} = {};

    $self->clear_all_tile_stacks();

    return $self;
}

#############################################################################

sub tile_stack_ids {
    my $self        = shift;

    return keys( %{ $self->{'STACKS'} } );
}

#############################################################################

sub clear_all_tile_stacks {
    my $self        = shift;

    $self->{'STACKS'} = {};

    foreach ( '0', '1', '2', '3', 'homeworlds', 'ancient_homeworlds' ) {
        $self->clear_tile_stack( $_ );
    }

    return;
}

#############################################################################

sub clear_tile_stack {
    my $self        = shift;
    my $stack_id    = shift;

    $self->{'STACKS'}->{ $stack_id } = {
        'DRAW' => WLE::Objects::Stack->new( 'flag_exclusive' => 1 ),
        'DISCARD' => WLE::Objects::Stack->new( 'flag_exclusive' => 1 ),
    };

    return;
}

#############################################################################

sub add_to_draw_stack {
    my $self        = shift;
    my $stack_id    = shift;
    my @tile_tags   = @_;

    unless ( defined( $self->{'STACKS'}->{ $stack_id } ) ) {
        return;
    }

    $self->{'STACKS'}->{ $stack_id }->{'DRAW'}->add_items( @tile_tags );

    return;
}

#############################################################################

sub tile_draw_stack {
    my $self        = shift;
    my $stack_id    = shift;

    unless ( defined( $self->{'STACKS'}->{ $stack_id } ) ) {
        return undef;
    }

    return $self->{'STACKS'}->{ $stack_id }->{'DRAW'};
}

#############################################################################

sub tile_discard_stack {
    my $self        = shift;
    my $stack_id    = shift;

    unless ( defined( $self->{'STACKS'}->{ $stack_id } ) ) {
        return undef;
    }

    return $self->{'STACKS'}->{ $stack_id }->{'DISCARD'};
}

#############################################################################

sub server {
    my $self        = shift;

    return $self->{'SERVER'};
}

#############################################################################

sub place_tile {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $tile_tag    = shift;

    if ( $tile_tag eq '' ) {
        return 0;
    }

    unless ( WLE::Methods::Simple::looks_like_number( $x_pos ) && WLE::Methods::Simple::looks_like_number( $y_pos ) ) {
        return 0;
    }

    unless ( defined( $self->{'SPACES'}->{ $x_pos } ) ) {
        $self->{'SPACES'}->{ $x_pos } = {};
    }

    if ( defined( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } ) ) {
        unless ( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } eq '' ) {
            return 0;
        }
    }

    $self->{'SPACES'}->{ $x_pos }->{ $y_pos } = $tile_tag;

    return 1;
}

#############################################################################

sub explorable_spaces_for_race {
    my $self        = shift;

    my %explorable = ();

    foreach my $column ( keys( %{ $self->{'SPACES'} } ) ) {
        foreach my $row ( keys( %{ $self->{'SPACES'}->{ $column } } ) ) {

            foreach my $adjacent_location ( $self->_explorable_from_location( $column, $row ) ) {
                $explorable{ $adjacent_location } = 1;
            }
        }
    }

    return keys( %explorable );
}

#############################################################################

sub _explorable_from_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    my $tile = $self->tile_at_location( $x_pos, $y_pos );

    my $flag_explorer_available = 0;

    if ( $tile->owner_id() == $self->server()->current_user() ) {
        $flag_explorer_available = 1;
    }
    elsif ( $tile->unpinned_ship_count() > 0 ) {
        $flag_explorer_available = 1;
    }

    unless ( $flag_explorer_available ) {
        return ();
    }

    my @adjacents = ();

    my $has_wormhole = $self->server()->race_of_current_user()->has_technology( 'tech_wormhole_generator' );

    foreach my $direction ( 0 .. 5 ) {
        if ( $has_wormhole || $tile->has_warp_on_side( $direction ) ) {
            my $remote_tile = $self->tile_in_direction( $x_pos, $y_pos, $direction );
            unless ( defined( $remote_tile ) ) {
                my ( $adj_x, $adj_y ) = $self->location_in_direction( $direction );

                my $stack_id = $self->stack_from_location( $adj_x, $adj_y );

                if ( $self->tile_draw_stack( $stack_id )->count() > 0 ) {
                    push( @adjacents, $adj_x . ':' . $adj_y );
                }
                elsif ( $self->tile_discard_stack( $stack_id )->count() > 0 ) {
                    push( @adjacents, $adj_x . ':' . $adj_y );
                }
            }
        }

    }

    return @adjacents;
}

#############################################################################

sub tile_at_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    unless ( defined( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } ) ) {
        return undef;
    }

    return $self->server()->tile_from_tag( $self->{'SPACES'}->{ $x_pos }->{ $y_pos } );
}

#############################################################################

sub tile_in_direction {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $direction   = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) && looks_like_number( $direction ) ) {
        return undef;
    }

    return $self->tile_at_location( $self->location_in_direction( $x_pos, $y_pos, $direction ) );
}

#############################################################################

sub location_in_direction {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;
    my $direction   = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) && looks_like_number( $direction ) ) {
        return undef;
    }

    while ( $direction < 0 ) {
        $direction += 6;
    }

    while ( $direction > 5 ) {
        $direction -= 6;
    }

    if ( $direction == 0 ) {
        return ( $x_pos, $y_pos - 1 );
    }
    elsif ( $direction == 1 ) {
        return ( $x_pos + 1, $y_pos - 1 );
    }
    elsif ( $direction == 2 ) {
        return ( $x_pos + 1, $y_pos );
    }
    elsif ( $direction == 3 ) {
        return ( $x_pos, $y_pos + 1 );
    }
    elsif ( $direction == 4 ) {
        return ( $x_pos - 1, $y_pos + 1 );
    }
    elsif ( $direction == 5 ) {
        return ( $x_pos - 1, $y_pos );
    }

    return undef;
}

#############################################################################

sub stack_from_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) ) {
        return -1;
    }

    if ( $x_pos == 0 && $y_pos == 0 ) {
        return 0;
    }

    if (
        ( $x_pos == 1 && $y_pos > -2 && $y_pos < 1 )
        || ( $x_pos == 0 && $y_pos > -2 && $y_pos < 2 )
        || ( $x_pos == -1 && $y_pos > -1 && $y_pos < 2 )
    ) {
        return 1;
    }

    if (
        ( $x_pos == 2 && $y_pos > -3 && $y_pos < 1 )
        || ( $x_pos == 1 && ( $y_pos == -2 || $y_pos == 1 ) )
        || ( $x_pos == 0 && ( $y_pos == -2 || $y_pos == 2 ) )
        || ( $x_pos == -1 && ( $y_pos == -1 || $y_pos == 2 ) )
        || ( $x_pos == 2 && $y_pos > -1 && $y_pos < 3 )
    ) {
        return 2;
    }

    return 3;
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    unless ( defined( $r_hash->{'SPACES'} ) ) {
        return 0;
    }

    $self->{'SPACES'} = $r_hash->{'SPACES'};

    $self->clear_all_tile_stacks();

    if ( defined( $r_hash->{'STACKS'} ) ) {

        foreach my $stack_id ( keys( %{ $r_hash->{'STACKS'} } ) ) {

            my $stack = $self->tile_draw_stack( $stack_id );
            if ( defined( $stack ) ) {
                $stack->add_items( @{ $r_hash->{'STACKS'}->{ $stack_id }->{'DRAW'} } );
            }

            $stack = $self->tile_discard_stack( $stack_id );
            if ( defined( $stack ) ) {
                $stack->add_items( @{ $r_hash->{'STACKS'}->{ $stack_id }->{'DISCARD'} } );
            }
        }
    }

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'SPACES'} = $self->{'SPACES'};
    $r_hash->{'TILE_STACKS'} = {};

    foreach my $stack_id ( $self->tile_stack_ids() ) {
        my @items = $self->tile_draw_stack( $stack_id )->items();
        $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} = [ @items ];
#        print STDERR "\nsaving $stack_id draw : " . join( ',', @items );

        @items = $self->tile_discard_stack( $stack_id )->items();
        $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} = [ @items ];
#        print STDERR "\nsaving $stack_id discard : " . join( ',', @items );

    }

    return 1;
}

#############################################################################
#############################################################################
1
