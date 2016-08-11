package WLE::4X::Objects::ASCII_Server;

use strict;
use warnings;

use WLE::Methods::Simple;

use WLE::4X::Enums::Basic;

use parent 'WLE::4X::Objects::Server';

#############################################################################

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

    $self->WLE::4X::Objects::Server::_init( %args );

    return $self;
}

#############################################################################

sub do {
    my $self        = shift;
    my %args        = @_;

    unless ( defined( $args{'action'} ) ) {
        return ( 'success' => 0, 'message' => "Missing 'action' element." );
    }

    unless ( defined( $args{'log_id'} ) ) {
        return ( 'success' => 0, 'message' => "Missing 'log_id' element.")
    }

    unless ( defined( $args{'user'} ) ) {
        return ( 'success' => 0, 'message' => "Missing 'user' element." );
    }

    my $action = $args{'action'};

    if ( $action eq 'info' ) {
        $args{'action'} = 'status';

        my %response = $self->do( %args );

        $self->_fill_text_data();

        $response{'success'} = $self->_fill_text_data();
        $response{'message'} = $self->last_error();
        $response{'data'} = $self->returned_data();
        $response{'allowed'} = [];

        return %response;
    }

    return $self->WLE::4X::Objects::Server::do( %args );
}

#############################################################################

sub _fill_text_data {
    my $self        = shift;

    my @lines = $self->_info_board();

    push( @lines, $self->_info_available_tech() );

    push( @lines, $self->_info_races() );






    $self->set_returned_data( join( "\n", @lines ) );

    return 1;
}

#############################################################################

sub _info_board {
    my $self            = shift;

    my @tile_0 = $self->_empty_tile_ascii( 0, 0 );

    my $hex_height = scalar( @tile_0 );
    my $hex_width = length( $tile_0[ $hex_height / 2 ] );

    my $hex_height_offset = ( ( $hex_height - 1 ) / 2 );
    my $hex_width_offset = $hex_height_offset - 1;

    my $default_w_h = 60;

    my @grid = ();

    my $line_height = $hex_height * $default_w_h;
    my $line_width = $default_w_h * ( $hex_width - $hex_width_offset );
    foreach ( 1 .. $line_height ) {
        push( @grid, ' ' x $line_width );
    }

    my $center_x = int( $line_width / 2 );
    my $center_y = int( $line_height / 2 );

    # first we draw empty hexes around the spaces the tiles occupy

    foreach my $tile_tag ( $self->board()->tiles_on_board() ) {
        my $tile = $self->tiles()->{ $tile_tag };
        my ( $column, $row ) = split( /:/, $self->board()->location_of_tile( $tile_tag ) );

        foreach my $direction ( 0 .. 5 ) {
            my ( $hex_column, $hex_row ) = $self->board()->location_in_direction( $column, $row, $direction );

            my @empty_hex_text = $self->_empty_tile_ascii( $hex_column, $hex_row );

            my $x = $hex_column * ( $hex_width - $hex_width_offset );
            my $y = ( $hex_row * ( $hex_height - 1 ) ) + ( $hex_column * $hex_height_offset );

            $self->_overlay_text( \@grid, \@empty_hex_text, $center_x + $x - 1, $center_y + $y );
        }
    }

    # now we draw the actual tiles

    foreach my $tile_tag ( $self->board()->tiles_on_board() ) {
        my $tile = $self->tiles()->{ $tile_tag };
        my ( $column, $row ) = split( /:/, $self->board()->location_of_tile( $tile_tag ) );

        my @hex_text = $self->_tile_ascii( $tile );

        my $x = $column * ( $hex_width - $hex_width_offset );
        my $y = ( $row * ( $hex_height - 1 ) ) + ( $column * $hex_height_offset );

        $self->_overlay_text( \@grid, \@hex_text, $center_x + $x, $center_y + $y );
    }

    # now we the top empty rows
    while ( $grid[ 0 ] =~ m{ ^ \s+ $ }xs ) {
        shift( @grid );
    }

    # remove the bottom empty rows
    while ( $grid[ -1 ] =~ m{ ^\s+ $ }xs ) {
        pop( @grid );
    }


    # remove the left empty columns
    my @widths = ();
    foreach ( @grid ) {
        $_ =~ m{ ^ ( \s* ) }xs;
        push( @widths, $1 );
    }
    @widths = sort { length( $a ) <=> length( $b ) } @widths;
    my $trim_string = $widths[ 0 ];
    @grid = map { $_ =~ s{^\Q$trim_string}{}x; $_ } @grid;

    # remove trailing spaces
    @grid = map { $_ =~ s{ \s+$}{}x; $_ } @grid;

    return @grid;

}

#############################################################################

sub _overlay_text {
    my $self        = shift;
    my $r_grid      = shift;
    my $r_text      = shift;
    my $x           = shift;
    my $y           = shift;

    foreach my $hex_line ( @{ $r_text } ) {

        #count and remove the '?' placeholder characters at the beginning of the line
        my @c = $hex_line =~ m{ \? }xsg;
        my $short_offset = @c;
        $hex_line =~ s{ ^\?+ }{}xsg;

        substr( $r_grid->[ $y ], $x + $short_offset, length( $hex_line ) ) = $hex_line;

        $y++;
    }

}

#############################################################################

sub _empty_tile_ascii {
    my $self        = shift;
    my $x           = shift;
    my $y           = shift;

    my @display = (
        '??????.           .',
        '?????               ',
        '????                 ',
        '???                   ',
        '??                     ',
        '?                       ',
        '.        xxx,yyy          .',
        '?                       ',
        '??                     ',
        '???                   ',
        '????                 ',
        '?????               ',
        '??????.           .',
    );

    my $x_text = sprintf( '%+02i', $x);
    my $y_text = sprintf( '%+02i', $y);

    foreach $_ ( @display ) {
        $_ =~ s{xxx}{$x_text}xs;
        $_ =~ s{yyy}{$y_text}xs;
    }

    return @display;
}

#############################################################################

sub _tile_ascii {
    my $self        = shift;
    my $tile        = shift;

    my @display = (
        '?????-------------',
        '????/ XXX  0  OOO \\',
        '???/ MON HIVE WORM \\',
        '??/5               1\\',
        '?/ SSSSSSSSSSSSSSSSS \\',
        '/  SSSSSSSSSSSSSSSSS  \\',
        '   SSSSSSSSSSSSSSSSS   ',
        '\  SSSSSSSSSSSSSSSSS  /',
        '?\      DDDDDDDD     /',
        '??\4 CCCCCCCCCCCCC 2/',
        '???\xxxxxxxxxxxxxxx/',
        '????\ ANC  3 DISC /',
        '?????-------------',
    );

    my $id = sprintf( '%03i', $tile->tile_id() );
    my $disc_count = $tile->discovery_count();

    my $colony_text = '';
    foreach my $slot ( $tile->resource_slots() ) {
        my $text = lc( text_from_resource_enum( $slot->resource_type(), 1 ) );

        if ( $slot->is_advanced() ) {
            $text = uc( $text );
        }

        if ( $slot->owner_id() > -1 ) {
            $text .= '*';
        }
        else {
            $text .= ' ';
        }

        $colony_text .= $text;
    }

    my $defender_text = $self->_get_ship_text_of_owner_id( $tile, $tile->owner_id() );

    my @other_ship_texts = ();

    foreach my $ship_owner_id ( reverse( $tile->owner_queue()->items() ) ) {
        unless ( $ship_owner_id == $tile->owner_id() ) {
            my $ship_text = $self->_get_ship_text_of_owner_id( $tile, $ship_owner_id );

            unless ( $ship_text eq '' ) {
                push( @other_ship_texts, $ship_owner_id . ':' . $ship_text );
            }
        }
    }
    my $other_ship_text = join( ' ', @other_ship_texts );
    @other_ship_texts = ();


    foreach $_ ( @display ) {

        my $buffer = '';

        foreach my $direction ( 0 .. 5 ) {
            if ( $tile->has_warp_on_side( $direction ) ) {
                $_ =~ s{ $direction }{O}xs;
            }
            else {
                $_ =~ s{ $direction }{ }xs;
            }
        }

        $_ =~ s{ XXX }{$id}xsm;

        if ( $_ =~ m{ (O{2,}) }xs ) {
            $buffer = $1;
            my $owner = '';
            if ( $tile->owner_id() > -1 ) {
                $owner = $tile->owner_id();
            }
            $owner = center_text( $owner, length( $buffer ) );
            $_ =~ s{ O{2,} }{$owner}xs;
        }

        if ( $_ =~ m{ (x{2,}) }xs ) {
            $buffer = $1;
            my $name = center_text( $tile->long_name(), length( $buffer ), 1 );
            $_ =~ s{ x{2,} }{$name}xs;
        }

        if ( $_ =~ m{ (D{2,}) }xs ) {
            $buffer = $1;
            $defender_text = center_text( $defender_text, length( $buffer ) );
            $_ =~ s{ D{2,} }{$defender_text}xs;
        }

        if ( $_ =~ m{ (S{2,}) }xs ) {
            $buffer = $1;
            if ( scalar( @other_ship_texts ) == 0 ) {
                @other_ship_texts = word_wrap( $other_ship_text, length( $buffer ) );
                $other_ship_text = '';
            }
            my $ship_line = shift( @other_ship_texts );
            $ship_line = center_text( $ship_line, length( $buffer ) );
            $_ =~ s{ S{2,} }{$ship_line}xs;
        }


        if ( $_ =~ m{ (C{2,}) }xs ) {
            $buffer = $1;
            $colony_text =~ s{ \s $ }{}xs;
            $colony_text = center_text( $colony_text, length( $buffer ) );
            $_ =~ s{ C{2,} }{$colony_text}xs;
        }

        unless ( $tile->monolith_count() > 0 ) {
            $_ =~ s{MON}{   }xs;
        }

        if ( $tile->ancient_links() > 0 ) {
            my $ancient_count = $tile->ancient_links();
            $_ =~ s{ANC\s}{ANC$ancient_count}xs;
        }
        else {
            $_ =~ s{ANC\s}{    }xs;
        }

        unless ( $disc_count > 0 ) {
            $_ =~ s{DISC}{    }xs;
        }

        unless ( $tile->has_wormhole() ) {
            $_ =~ s{WORM}{    }xs;
        }

        unless ( $tile->is_hive() ) {
            $_ =~ s{HIVE}{    }xs;
        }
    }


    return @display;
}

#############################################################################

sub _get_ship_text_of_owner_id {
    my $self        = shift;
    my $tile        = shift;
    my $owner_id    = shift;

    my @class_order = (
    'class_interceptor',
    'class_cruiser',
    'class_dreadnought',
    'class_starbase',
    'class_ancient_cuiser',
    'class_ancient_destroyer',
    'class_ancient_dreadnought',
    'class_defense',
    );

    my $ship_text = '';
    my %ship_type_counts = ();

    foreach my $ship_tag ( $tile->ships()->items() ) {
        my $ship = $self->ships()->{ $ship_tag };
        if ( $ship->owner_id() == $owner_id ) {
            if ( defined( $ship_type_counts{ $ship->template()->class() } ) ) {
                $ship_type_counts{ $ship->template()->class() }++;
            }
            else {
                $ship_type_counts{ $ship->template()->class() } = 1;
            }
        }
    }

    foreach my $class ( @class_order ) {
        if ( defined( $ship_type_counts{ $class } ) ) {
            $ship_text .= desc_from_class( $class, 1 ) . $ship_type_counts{ $class };
        }
    }

    return $ship_text;
}

#############################################################################

sub _info_available_tech {
    my $self            = shift;

    my @lines = ( "\n" );
    my %available_tech = ();
    my %tech_counts = ();

    foreach my $tech_tag ( $self->available_tech()->items() ) {
        my $tech = $self->technology()->{ $tech_tag };

        if ( defined( $tech ) ) {
            unless ( defined( $available_tech{ $tech->category() } ) ) {
                $available_tech{ $tech->category() } = [];
            }

            unless ( defined( $tech_counts{ $tech->tag() } ) ) {
                $tech_counts{ $tech->tag() } = 0;
                push( @{ $available_tech{ $tech->category() } }, $tech );
            }

            $tech_counts{ $tech->tag() }++;
        }
    }

    foreach my $tech_type ( $TECH_MILITARY, $TECH_GRID, $TECH_NANO, $TECH_WILD ) {
        my @sorted_techs = ();
        my @tech_names = ();

        if ( defined( $available_tech{ $tech_type } ) ) {
            @sorted_techs = sort { $a->base_cost() <=> $b->base_cost() } @{ $available_tech{ $tech_type } };
        }

        foreach my $tech ( @sorted_techs ) {
            my $text = $tech->long_name() . ' (' . $tech->base_cost() . '/' . $tech->min_cost() . ')';
            if ( $tech_counts{ $tech->tag() } > 1 ) {
                $text .= ' x' . $tech_counts{ $tech->tag() };
            }
            push( @tech_names, $text );
        }

        push( @lines, text_from_tech_enum( $tech_type, 1 ) . ' ' . join( ', ', @tech_names ) );
    }

    return @lines;
}


#############################################################################

sub _info_races {
    my $self            = shift;

    my @ids = ( 0 .. $self->user_ids()->count() - 1 );

    my @lines = ();

    foreach my $player_id ( @ids ) {
        my $race = $self->race_of_player_id( $player_id );

        if ( defined( $race ) ) {
            push( @lines, join( "\n", $self->_race_ascii( $race ) ) );
        }
    }

    return @lines;
}

#############################################################################

sub _race_ascii {
    my $self            = shift;
    my $race            = shift;

    my @lines = ( "\n" );

    my $waiting_on_text = ( $self->waiting_on_player_id() == $race->owner_id() ) ? ' *waiting on*' : '';

    push(
        @lines,
        $race->owner_id() . ') '
            . $race->long_name()
            . ' [' . ($self->user_ids()->items())[ $race->owner_id() ] . ']'
            . $waiting_on_text
    );

    foreach my $tech_type ( $TECH_MILITARY, $TECH_NANO, $TECH_GRID ) {
        my @tech_names = ();

        foreach my $tech_tag ( $race->tech_track_of( $tech_type )->techs() ) {
            my $tech = $self->technology()->{ $tech_tag };
            if ( defined( $tech ) ) {
                push( @tech_names, $tech->long_name() );
            }
        }

        push(
            @lines,
            text_from_tech_enum( $tech_type, 1 )
                . ' ' . $race->tech_track_of( $tech_type )->current_credit() . '/'
                . $race->tech_track_of( $tech_type )->vp_total() . 'vp : '
                . join( ',', @tech_names )
        );
    }

    foreach my $res_type ( $RES_SCIENCE, $RES_MINERALS, $RES_MONEY, $RES_INFLUENCE ) {

        my $track = $race->resource_track_of( $res_type );

        my $text = text_from_resource_enum( $res_type );
        unless ( $res_type == $RES_INFLUENCE ) {
            $text .= ' : ' . $race->resource_count( $res_type );
        }

        $text .= ' : ' . $track->track_value() . ' : ' . $track->available_to_spend();

        if ( $res_type == $RES_INFLUENCE ) {
            $text .= '/' . $track->spent_count();
        }

        push( @lines, $text );
    }

    foreach my $class ( 'class_interceptor', 'class_cruiser', 'class_dreadnought', 'class_starbase' ) {
        my $template = $race->template_of_class( $class );

        if ( defined( $template ) ) {
            push( @lines, $self->_ship_template_ascii( $template ) );
        }
    }

    



    return @lines;
}

#############################################################################

sub _ship_template_ascii {
    my $self        = shift;
    my $template    = shift;

    my $text = desc_from_class( $template->class() ) . ' : ' . $template->cost() . '  ';

    $text .= 'Mv' . $template->total_movement() . ' ';
    $text .= 'In' . $template->total_initiative() . ' ';
    $text .= 'Co' . $template->total_computer() . ' ';
    $text .= 'Sh' . $template->total_shields() . ' ';
    $text .= 'Hp' . $template->total_hull_points() . ' ';
    $text .= 'En' . $template->total_energy_used() . '/' . $template->total_energy() . ' ';

    my %beam = $template->total_beam_attacks();
    if ( %beam ) {
        $text .= 'Beam ';
        foreach my $strength ( sort( keys( %beam ) ) ) {
            $text .= $strength . 'x' . $beam{ $strength } . ' ';
        }
    }

    my %missile = $template->total_missile_attacks();
    if ( %missile ) {
        $text .= 'Missile ';
        foreach my $strength ( sort( keys( %missile ) ) ) {
            $text .= $strength . 'x' . $missile{ $strength } . ' ';
        }
    }

    my @component_names = ();
    foreach my $comp_tag ( $template->components() ) {
        push( @component_names, $self->ship_components()->{ $comp_tag }->long_name() );
    }

    while ( scalar( @component_names ) < $template->slots() ) {
        push( @component_names, '[empty]' );
    }

    $text .= '(' . join( ',', @component_names ) . ') ';

    return $text;
}

#############################################################################
#############################################################################
1
