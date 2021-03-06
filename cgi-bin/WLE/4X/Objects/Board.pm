package WLE::4X::Objects::Board;

use strict;
use warnings;

use WLE::Methods::Simple;

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

    $self->{'TILES'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );

    $self->{'STACKS'} = {};
    $self->{'STACK_LIMITS'} = {};

    $self->{'STACK_TAGS'} = [ '0', '1', '2', '3', 'homeworlds', 'ancient_homeworlds' ];

    $self->clear_all_tile_stacks();

    return $self;
}

#############################################################################

sub tiles {
    my $self        = shift;

    return $self->{'TILES'};
}

#############################################################################

sub tile_stack_ids {
    my $self        = shift;

    return @{ $self->{'STACK_TAGS'} };
}

#############################################################################

sub clear_all_tile_stacks {
    my $self        = shift;

    $self->{'STACKS'} = {};

    foreach ( $self->tile_stack_ids() ) {
        $self->clear_tile_stack( $_ );
    }

    return;
}

#############################################################################

sub tile_stack_limit {
    my $self        = shift;
    my $stack_id    = shift;

    return $self->{'STACK_LIMITS'}->{ $stack_id };
}

#############################################################################

sub set_tile_stack_limit {
    my $self        = shift;
    my $stack_id    = shift;
    my $limit       = shift;

    $self->{'STACK_LIMITS'}->{ $stack_id } = -1;
}

#############################################################################

sub clear_tile_stack {
    my $self        = shift;
    my $stack_id    = shift;

    $self->{'STACKS'}->{ $stack_id } = {
        'DRAW' => WLE::Objects::Stack->new( 'flag_exclusive' => 1 ),
        'DISCARD' => WLE::Objects::Stack->new( 'flag_exclusive' => 1 ),
    };

    $self->set_tile_stack_limit( $stack_id, -1 );

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

sub tiles_on_board {
    my $self        = shift;

    return $self->tiles()->items();
}

#############################################################################

sub location_of_tile {
    my $self        = shift;
    my $tile_tag    = shift;

    my $tile = $self->server()->tiles()->{ $tile_tag };

    if ( defined( $tile ) ) {
        return $tile->board_location();
    }

    return '';
}

#############################################################################

sub valid_path_for_player_id {
    my $self                = shift;
    my $player_id           = shift;
    my $ship_can_jump       = shift;
    my $flag_aggressive     = shift;
    my $r_broken_treaties   = shift;
    my $r_path              = shift;

    my $player = $self->server()->player_of_id( $player_id );
    my $race = $player->race();

    my @path = @{ $r_path };

    my $flag_doable = 1;
    my $flag_used_jump_drive = 0;

    my %broken_treaties = ();


    while ( scalar( @path ) >= 2 ) {

        my $start_tile = $self->server()->tiles()->{ $path[ 0 ] };
        my $end_tile = $self->server()->tiles()->{ $path[ 1 ] };

        if ( $start_tile->unpinned_ship_count( $player_id ) < 1 ) {
            $flag_doable = 0;
            last;
        }

        my ( $loc_x1, $loc_y1 ) = split( /:/, $self->location_of_tile( $path[ 0 ] ) );
        my ( $loc_x2, $loc_y2 ) = split( /:/, $self->location_of_tile( $path[ 1 ] ) );

        my $flag_normally_reachable = $self->tile_pair_is_traversable(
            $player_id,
            $loc_x1,
            $loc_y1,
            $loc_x2,
            $loc_y2,
        );

        if ( $flag_normally_reachable ) {
            shift( @path );
            next;
        }

        if ( $flag_used_jump_drive ) {
            $flag_doable = 0;
            last;
        }

        unless ( $ship_can_jump ) {
            $flag_doable = 0;
            last;
        }

        $flag_used_jump_drive = 1;

        unless ( $self->locations_adjacent( $loc_x1, $loc_y1, $loc_x2, $loc_y2 )  ) {
            $flag_doable = 0;
            last;
        }

        foreach my $treaty_id ( $end_tile->treaties_on_tile( $player_id ) ) {
            $broken_treaties{ $treaty_id } = 1;

            unless ( $flag_aggressive ) {
                $flag_doable = 0;
            }
        }

        shift( @path );
    }

    @{ $r_broken_treaties } = keys( %broken_treaties );

    return $flag_doable;
}

#############################################################################

sub tile_is_within_distance {
    my $self            = shift;
    my $player_id       = shift;
    my $origin_tag      = shift;
    my $destination_tag = shift;
    my $max_distance    = shift;
    my $flag_jump_drive = shift;
    my $flag_has_wormhole = shift;

    my $player = $self->server()->player_of_id( $player_id );
    my $race = $player->race();

    my $start = $self->location_of_tile( $origin_tag );
    my ( $loc_x, $loc_y ) = split( /:/, $start );

    my @paths = ( [ '0', $origin_tag ] );

    while ( scalar( @paths ) > 0 ) {

        my @good_paths = ();

        foreach my $path ( @paths ) {

            my $end_point = $path->[ -1 ];
            my ( $loc_x, $loc_y ) = split( /:/, $self->location_of_tile( $end_point ) );

            foreach my $direction ( 0 .. 5 ) {
                my ( $loc_x2, $loc_y2 ) = $self->location_in_direction( $loc_x, $loc_y, $direction );
                my $tile = $self->tile_at_location( $loc_x2, $loc_y2 );

                if ( defined( $tile ) ) {

                    unless ( matches_any( $tile->tag(), @{ $path } ) ) {

                        my $traversable = $self->tile_pair_is_traversable(
                            $player_id,
                            $loc_x,
                            $loc_y,
                            $loc_x2,
                            $loc_y2,
                        );

                        if ( $traversable == 0 && $flag_jump_drive && $path->[ 0 ] == '0' ) {
                            $path->[ 0 ] = '1'; # we've now used the jump drive on this path
                            $traversable = 1;
                        }

                        if ( $traversable ) {

                            if ( $tile->unpinned_ship_count( $player_id, 1 ) > 0 ) {

                                my @new_path = ( @{ $path }, $tile->tag() );

                                if ( scalar( @new_path ) < $max_distance ) {
                                    if ( $tile->tag() eq $destination_tag ) {
                                        return 1;
                                    }

                                    push( @good_paths, \@new_path );
                                }
                            }
                        }
                    }
                }
            }
        }

        @paths = @good_paths;
    }

    return 0;
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

    unless ( looks_like_number( $x_pos ) && looks_like_number( $y_pos ) ) {
        return 0;
    }

    my $location = $x_pos . ':' . $y_pos;

    foreach my $existing_tag ( $self->tiles_on_board() ) {
        if ( $self->location_of_tile( $existing_tag ) eq $location ) {
            # there's already a tile here
            return 0;
        }
    }

    my $tile = $self->server()->tiles()->{ $tile_tag };
    unless ( defined( $tile ) ) {
        return 0;
    }

    $tile->set_board_location( $location );

    $self->tiles()->add_items( $tile_tag );

    return 1;
}

#############################################################################

sub player_owns_any_tile {
    my $self        = shift;
    my $player_id   = shift;

    foreach my $tile_tag ( $self->tiles_on_board() ) {
        if ( $self->server()->tiles()->{ $tile_tag }->owner_id() == $player_id ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub explorable_spaces_for_player {
    my $self        = shift;
    my $player_id   = shift;

    my %explorable = ();

    foreach my $tile_tag ( $self->tiles_on_board() ) {

        my ( $column, $row ) = split( /:/, $self->location_of_tile( $tile_tag ) );

        foreach my $adjacent_location ( $self->_explorable_from_location( $player_id, $column, $row ) ) {
            $explorable{ $adjacent_location } = 1;
        }
    }

    return keys( %explorable );
}

#############################################################################
#
# only takes into account wormholes and wormhole generators
#

sub tile_pair_is_traversable {
    my $self        = shift;
    my $player_id   = shift;
    my $loc_x1      = shift;
    my $loc_y1      = shift;
    my $loc_x2      = shift;
    my $loc_y2      = shift;

    unless ( $self->locations_adjacent( $loc_x1, $loc_y1, $loc_x2, $loc_y2 ) ) {
        return 0;
    }

    my $has_wormhole = $self->server()->player_of_id( $player_id )->race()->has_technology( 'tech_wormhole_generator' );

    my $tile1 = $self->tile_at_location( $loc_x1, $loc_y1 );
    my $tile2 = $self->tile_at_location( $loc_x2, $loc_y2 );

    foreach my $direction ( 0 .. 5 ) {
        my $remote_tile = $self->tile_in_direction( $loc_x1, $loc_y1, $direction );
        if ( $remote_tile == $tile2 ) {
            my $warp_here = $tile1->has_warp_on_side( $direction );
            my $warp_there = $tile2->has_warp_on_side( ( $direction + 3) % 6 );

            if ( $warp_here && $warp_there ) {
                return 1;
            }
            elsif ( $has_wormhole && ( $warp_here || $warp_there ) ) {
                return 1;
            }
        }
    }

    return 0;
}

#############################################################################

sub locations_adjacent {
    my $self        = shift;
    my $loc_x1      = shift;
    my $loc_y1      = shift;
    my $loc_x2      = shift;
    my $loc_y2      = shift;

    foreach my $direction ( 0 .. 5 ) {
        my ( $loc_x3, $loc_y3 ) = $self->location_in_direction( $loc_x1, $loc_y1, $direction );
        if ( $loc_x2 == $loc_x3 && $loc_y2 == $loc_y3 ) {
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub _explorable_from_location {
    my $self        = shift;
    my $player_id   = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    my $tile = $self->tile_at_location( $x_pos, $y_pos );

    unless ( $tile->has_explorer( $player_id ) ) {
        return ();
    }

    my $has_wormhole = $self->server()->player_of_id( $player_id )->race()->has_technology( 'tech_wormhole_generator' );

    my @adjacents = ();

    foreach my $direction ( 0 .. 5 ) {
        if ( $has_wormhole || $tile->has_warp_on_side( $direction ) ) {
            my $remote_tile = $self->tile_in_direction( $x_pos, $y_pos, $direction );
            unless ( defined( $remote_tile ) ) {
                my ( $adj_x, $adj_y ) = $self->location_in_direction( $x_pos, $y_pos, $direction );

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

sub tile_is_influencible {
    my $self        = shift;
    my $tile_tag    = shift;
    my $player_id   = shift;

    my $player = $self->server()->player_of_id( $player_id );
    my $race = $player->race();

    my ( $loc_x, $loc_y ) = split( /:/, $self->location_of_tile( $tile_tag ) );

    my $this_tile = $self->server()->tiles()->{ $tile_tag };

    if ( $this_tile->enemy_ship_count( $player->id() ) > 0 ) {
        return 0;
    }

    foreach my $direction ( 0 .. 5 ) {
        my ( $loc_x2, $loc_y2 ) = $self->location_in_direction( $loc_x, $loc_y, $direction );

        my $tile = $self->tile_at_location( $loc_x2, $loc_y2 );

        if ( defined( $tile ) ) {
            if ( $self->tile_pair_is_traversable( $player->id(), $loc_x, $loc_y, $loc_x2, $loc_y2 ) ) {
                if ( $tile->user_ship_count( $player->id() ) > 0 ) {
                    return 1;
                }
            }
        }
    }

    return 0;
}

#############################################################################

sub tile_at_location {
    my $self        = shift;
    my $x_pos       = shift;
    my $y_pos       = shift;

    my $location = $x_pos . ':' . $y_pos;

    foreach my $tile_tag ( $self->tiles_on_board() ) {
        my $tile = $self->server()->tiles()->{ $tile_tag };
        if ( defined( $tile ) ) {
            if ( $location eq $tile->board_location() ) {
                return $tile;
            }
        }
    }

    return undef;
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

sub player_retreat_options {
    my $self        = shift;
    my $tile_tag    = shift;
    my $player_id   = shift;

    my ( $loc_x, $loc_y ) = split( /:/, $self->location_of_tile( $tile_tag ) );

    my @options = ();

    foreach my $direction ( 0 .. 5 ) {
        my $retreat_tile = $self->tile_in_direction( $loc_x, $loc_y, $direction );

        if ( defined( $retreat_tile ) ) {
            if ( $retreat_tile->owner_id() == $player_id ) {
                push( @options, $retreat_tile->tag() );
            }
        }
    }

    return @options;
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

sub outermost_combat_tile {
    my $self        = shift;

    my @combat_tiles = ();

    foreach my $tile_tag ( $self->tiles_on_board() ) {
        my $tile = $self->server()->tiles()->{ $tile_tag };
        if ( defined( $tile ) ) {
            if ( $tile->has_combat() ) {
                push( @combat_tiles, $tile );
            }
        }
    }

    unless ( scalar( @combat_tiles ) > 0 ) {
        return '';
    }

    @combat_tiles = sort { $a->get_id() <=> $b->get_id() } @combat_tiles;

    return $combat_tiles[ 0 ]->tag();
}

#############################################################################

sub from_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    if ( defined( $r_hash->{'TILES'} ) ) {
        $self->tiles()->fill( @{ $r_hash->{'TILES'} } );
    }

    $self->clear_all_tile_stacks();

    if ( defined( $r_hash->{'TILE_STACKS'} ) ) {

        foreach my $stack_id ( keys( %{ $r_hash->{'TILE_STACKS'} } ) ) {

            my $stack = $self->tile_draw_stack( $stack_id );
            if ( defined( $stack ) ) {
                $stack->add_items( @{ $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} } );
            }

            $stack = $self->tile_discard_stack( $stack_id );
            if ( defined( $stack ) ) {
                $stack->add_items( @{ $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} } );
            }
        }
    }

    $self->{'STACK_LIMITS'} = $r_hash->{'STACK_LIMITS'};

    return 1;
}

#############################################################################

sub to_hash {
    my $self        = shift;
    my $r_hash      = shift;

    unless ( defined( $r_hash ) ) {
        return 0;
    }

    $r_hash->{'TILES'} = [ $self->tiles_on_board() ];

    $r_hash->{'TILE_STACKS'} = {};

    foreach my $stack_id ( $self->tile_stack_ids() ) {
        my @items = $self->tile_draw_stack( $stack_id )->items();
        $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DRAW'} = [ @items ];
#        print STDERR "\nsaving $stack_id draw : " . join( ',', @items );

        @items = $self->tile_discard_stack( $stack_id )->items();
        $r_hash->{'TILE_STACKS'}->{ $stack_id }->{'DISCARD'} = [ @items ];
#        print STDERR "\nsaving $stack_id discard : " . join( ',', @items );

    }

    $r_hash->{'STACK_LIMITS'} = $self->{'STACK_LIMITS'};

    return 1;
}

#############################################################################
#############################################################################
1
