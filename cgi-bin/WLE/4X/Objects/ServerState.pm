package WLE::4X::Objects::Server;

use strict;
use warnings;


#############################################################################

sub _does_log_exist {
    my $self        = shift;
    my $log_id      = shift;

    return ( -e $self->_state_file( $log_id ) );
}

#############################################################################

sub _log_data {
    my $self        = shift;
    my $data        = shift;

    print { $self->{'FH_LOG'} } $data . "\n";

    return;
}

#############################################################################

sub _open_for_reading {
    my $self        = shift;
    my $log_id      = shift;

    $self->set_error( '' );

    unless ( $self->_set_log_id( $log_id ) ) {
        $self->set_error( 'Invalid Log ID: ' . $log_id );
        return 0;
    }

    $self->{'FH_STATE'} = $self->_open_file( $self->_state_file() );

    $self->_read_state( $log_id );

    return defined( $self->{'FH_STATE'} );
}

#############################################################################

sub _open_for_writing {
    my $self        = shift;
    my $log_id      = shift;
    my $flag_create = shift; $flag_create = 0           unless defined( $flag_create );

    $self->set_error( '' );

    unless ( $self->_set_log_id( $log_id ) ) {
        $self->set_error( 'Invalid Log ID: ' . $log_id );
        return 0;
    }

    $self->{'FH_LOG'} = $self->_open_file_with_lock( $self->_log_file(), $flag_create );
    $self->{'FH_STATE'} = $self->_open_file_with_lock( $self->_state_file(), $flag_create );

    if ( defined( $self->{'FH_LOG'} ) && defined( $self->{'FH_STATE'} ) ) {
        $self->{'FH_LOG'}->autoflush;
        $self->{'FH_STATE'}->autoflush;

        unless ( $flag_create ) {
            $self->_read_state( $log_id );
        }

        return 1;
    }

    return 0;
}

#############################################################################

sub _close_all {
    my $self        = shift;

    if ( defined( $self->{'FH_LOG'} ) ) {
        close( $self->{'FH_LOG'} );
    }

    if ( defined( $self->{'FH_STATE'} ) ) {
        close( $self->{'FH_STATE'} );
    }

}

#############################################################################

sub _read_state {
    my $self        = shift;
    my $log_id      = shift;

#    print STDERR "\nLoading State ... ";

    # using Data::Dumper

    my $fh = $self->{'FH_STATE'};

    seek( $fh, 0, 0 );

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    # settings

    $self->_set_log_id( $VAR1->{'SETTINGS'}->{'LOG_ID'} );
    $self->set_long_name( $VAR1->{'SETTINGS'}->{'LONG_NAME'} );

    $self->source_tags()->fill( @{ $VAR1->{'SETTINGS'}->{'SOURCE_TAGS'} } );
    $self->option_tags()->fill( @{ $VAR1->{'SETTINGS'}->{'OPTION_TAGS'} } );

    foreach my $player_id ( keys( %{ $VAR1->{'SETTINGS'}->{'PLAYERS'} } ) ) {
        my $player = WLE::4X::Objects::Player->new( 'server' => $self );
        if ( $player->from_hash( $VAR1->{'SETTINGS'}->{'PLAYERS'}->{ $player_id } ) ) {
            $self->players()->{ $player->id() } = $player;
        }
    }

    $self->pending_players()->fill( @{ $VAR1->{'SETTINGS'}->{'PLAYERS_PENDING'} } );
    $self->done_players()->fill( @{ $VAR1->{'SETTINGS'}->{'PLAYERS_DONE'} } );
    $self->players_next_round->fill( @{ $VAR1->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} } );
#    print STDERR "\nLoading Players Next Round: " . join( ',', $self->players_next_round()->items() );


    $self->set_waiting_on_player_id( $VAR1->{'SETTINGS'}->{'WAITING_ON_PLAYER'} );

    $self->set_current_traitor( $VAR1->{'SETTINGS'}->{'CURRENT_TRAITOR'} );

    if ( defined( $VAR1->{'SETTINGS'}->{'STARTING_LOCATIONS'} ) ) {
        foreach my $location ( @{ $VAR1->{'SETTINGS'}->{'STARTING_LOCATIONS'} } ) {
            $self->starting_locations()->add_items( $location );
        }
    }

    if ( defined( $VAR1->{'STATE'}->{'STATE'} ) ) {
        $self->set_state( $VAR1->{'STATE'}->{'STATE'} );
    }

    if ( defined( $VAR1->{'STATE'}->{'ROUND'} ) ) {
        $self->set_round( $VAR1->{'STATE'}->{'ROUND'} );
    }

    if ( defined( $VAR1->{'STATE'}->{'PLAYER'} ) ) {
        $self->set_waiting_on_player_id( $VAR1->{'STATE'}->{'PLAYER'} );
    }

    if ( defined( $VAR1->{'STATE'}->{'PHASE'} ) ) {
        $self->set_phase( $VAR1->{'STATE'}->{'PHASE'} );
    }

    if ( defined( $VAR1->{'STATE'}->{'SUBPHASE'} ) ) {
        $self->set_subphase( $VAR1->{'STATE'}->{'SUBPHASE'} );
    }

    if ( defined( $VAR1->{'STATE'}->{'TILE'} ) ) {
        $self->set_current_tile( $VAR1->{'STATE'}->{'TILE'} );
    }


    $self->set_tech_draw_count( $VAR1->{'ROUND_TECH_COUNT'} );


    # setup ship component tiles
    # print STDERR "\n  ship components ... ";

    unless ( defined( $VAR1->{'COMPONENTS'} ) ) {
        $self->set_error( 'Missing Section in resource file: COMPONENTS' );
        return 0;
    }

    foreach my $component_key ( keys( %{ $VAR1->{'COMPONENTS'} } ) ) {
        my $component = WLE::4X::Objects::ShipComponent->new(
            'server' => $self,
            'tag' => $component_key,
            'hash' => $VAR1->{'COMPONENTS'}->{ $component_key },
        );

        if ( defined( $component ) ) {
            $self->ship_components()->{ $component_key } = $component;
        }
    }

    # setup technology tiles
#    print STDERR "\n  technology ... ";

    unless ( defined( $VAR1->{'TECHNOLOGY'} ) ) {
        $self->set_error( 'Missing Section in resource file: TECHNOLOGY' );
        return 0;
    }

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new(
            'server' => $self,
            'tag' => $tech_key,
            'hash' => $VAR1->{'TECHNOLOGY'}->{ $tech_key },
        );

        if ( defined( $technology ) ) {
            $self->technology()->{ $technology->tag() } = $technology;
        }
    }

    $self->tech_bag()->fill( @{ $VAR1->{'TECH_BAG'} } );
    $self->available_tech()->fill( @{ $VAR1->{'AVAILABLE_TECH'} } );

    # vp tokens
    # print STDERR "\n  vp tokens ... ";

    $self->vp_bag()->fill( @{ $VAR1->{'VP_BAG'} } );

    # discoveries
#    print STDERR "\n  discoveries ... ";

    foreach my $disc_key ( keys( %{ $VAR1->{'DISCOVERIES'} } ) ) {

        my $discovery = WLE::4X::Objects::Discovery->new(
            'server' => $self,
            'tag' => $disc_key,
            'hash' => $VAR1->{'DISCOVERIES'}->{ $disc_key },
        );

        if ( defined( $discovery ) ) {
            $self->discoveries()->{ $discovery->tag() } = $discovery;
        }
    }

    $self->discovery_bag()->fill( @{ $VAR1->{'DISCOVERY_BAG'} } );

    # tiles
#    print STDERR "\n  tiles ... ";

    $self->board()->from_hash( $VAR1->{'BOARD'} );

#    print STDERR "\nReading Tiles ... ";

    foreach my $tile_key ( keys( %{ $VAR1->{'TILES'} } ) ) {

#        print "\nReading Tile: " . $tile_key . ' ...';

        my $tile = WLE::4X::Objects::Tile->new(
            'server' => $self,
            'tag' => $tile_key,
            'hash' => $VAR1->{'TILES'}->{ $tile_key },
        );

        if ( defined( $tile ) ) {
#            print " storing.";
            $self->tiles()->{ $tile->tag() } = $tile;
        }
    }

    # developments
#    print STDERR "\n  developments ... ";

    foreach my $dev_key ( keys( %{ $VAR1->{'DEVELOPMENTS'} } ) ) {

        my $development = WLE::4X::Objects::Development->new(
            'server' => $self,
            'tag' => $dev_key,
            'hash' => $VAR1->{'DEVELOPMENTS'}->{ $dev_key },
        );

        if ( defined( $development ) ) {
            $self->developments()->{ $dev_key } = $development;
        }
    }

    $self->development_stack()->fill( @{ $VAR1->{'DEVELOPMENT_STACK'} } );


    # setup ship templates
#    print STDERR "\n  ship templates ... ";

    unless ( defined( $VAR1->{'SHIP_TEMPLATES'} ) ) {
        $self->set_error( 'Missing Section in resource file: SHIP_TEMPLATES' );
        return 0;
    }

    foreach my $template_key ( keys( %{ $VAR1->{'SHIP_TEMPLATES'} } ) ) {

#        print STDERR "\n     " . $template_key;

        my $template = WLE::4X::Objects::ShipTemplate->new(
            'server' => $self,
            'tag' => $template_key,
            'hash' => $VAR1->{'SHIP_TEMPLATES'}->{ $template_key },
        );

        if ( defined( $template ) ) {
#            print STDERR " added.";
            $self->templates()->{ $template->tag() } = $template;
        }
    }

    $self->template_combat_order()->fill( @{ $VAR1->{'TEMPLATE_COMBAT_ORDER'} } );

    # ships

    foreach my $ship_key ( keys( %{ $VAR1->{'SHIPS'} } ) ) {

#        print STDERR "\nReading ship data " . $ship_key . " ... ";

        my $ship = WLE::4X::Objects::Ship->new(
            'server' => $self,
            'tag' => $ship_key,
            'hash' => $VAR1->{'SHIPS'}->{ $ship_key },
        );

        if ( defined( $ship ) ) {
#            print STDERR 'added.';
            $self->ships()->{ $ship->tag() } = $ship;
        }
    }

    # ship pool

    foreach my $ship_key ( keys( %{ $VAR1->{'SHIP_POOL'} } ) ) {

        my $ship = WLE::4X::Objects::Ship->new(
            'server' => $self,
            'tag' => $ship_key,
            'hash' => $VAR1->{'SHIP_POOL'}->{ $ship_key },
        );

        if ( defined( $ship ) ) {
            $self->ship_pool()->{ $ship->tag() } = $ship;
        }
    }


    # races

    foreach my $race_tag ( keys( %{ $VAR1->{'RACES'} } ) ) {

        my $race = WLE::4X::Objects::Race->new(
            'server' => $self,
            'tag' => $race_tag,
            'hash' => $VAR1->{'RACES'}->{ $race_tag },
        );

        if ( defined( $race ) ) {
            $self->races()->{ $race_tag } = $race;
        }
    }

    # current combat die rolls

    if ( defined( $VAR1->{'COMBAT_HITS'} ) ) {
        $self->combat_hits()->fill( @{ $VAR1->{'COMBAT_HITS'} } );
    }

    if ( defined( $VAR1->{'MISSILE_DEFENSE_HITS'} ) ) {
        $self->set_missile_defense_hits( $VAR1->{'MISSILE_DEFENSE_HITS'} );
    }


    # using Storable

#    $self->{'DATA'} = fd_retrieve( $fh );

    return 1;
}

#############################################################################

sub _save_state {
    my $self        = shift;

    # using Data::Dumper

    my %data = ();

    $data{'SETTINGS'}->{'LOG_ID'} = $self->log_id();

    $data{'SETTINGS'}->{'SOURCE_TAGS'} = [ $self->source_tags()->items() ];
    $data{'SETTINGS'}->{'OPTION_TAGS'} = [ $self->option_tags()->items() ];

    $data{'SETTINGS'}->{'LONG_NAME'} = $self->long_name();

    foreach my $player ( $self->player_list() ) {
        my %player_hash = ();
        if ( $player->to_hash( \%player_hash ) ) {
            $data{'SETTINGS'}->{'PLAYERS'}->{ $player->id() } = \%player_hash;
        }
    }

    $data{'SETTINGS'}->{'PLAYERS_PENDING'} = [ $self->pending_players()->items() ];
    $data{'SETTINGS'}->{'PLAYERS_DONE'} = [ $self->done_players()->items() ];
    $data{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} = [ $self->players_next_round()->items() ];
#    print STDERR "\nSaving Players Next Round: " . join( ',', @{ $data{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} } );

#    print STDERR "\nDump of list: " . Dumper( $data{'SETTINGS'} );

    $data{'SETTINGS'}->{'CURRENT_TRAITOR'} = $self->current_traitor();

    $data{'STATE'}->{'STATE'} = $self->state();
    $data{'STATE'}->{'ROUND'} = $self->round();
    $data{'STATE'}->{'PLAYER'} = $self->waiting_on_player_id();
    $data{'STATE'}->{'PHASE'} = $self->phase();
    $data{'STATE'}->{'SUBPHASE'} = $self->subphase();
    $data{'STATE'}->{'TILE'} = $self->current_tile();

    unless ( $self->status() eq '0' ) {

        $data{'SETTINGS'}->{'STARTING_LOCATIONS'} = [ $self->starting_locations()->items() ];

        $data{'TECH_DRAW_COUNT'} = $self->tech_draw_count();

        # ship components
        $data{'COMPONENTS'} = {};

        foreach my $component ( values( %{ $self->ship_components() } ) ) {
            $data{'COMPONENTS'}->{ $component->tag() } = {};
            $component->to_hash( $data{'COMPONENTS'}->{ $component->tag() } );
        }

        # technology

        $data{'TECHNOLOGY'} = {};

        foreach my $technology ( values( %{ $self->technology() } ) ) {
            $data{'TECHNOLOGY'}->{ $technology->tag() } = {};
            $technology->to_hash( $data{'TECHNOLOGY'}->{ $technology->tag() } );
        }

        $data{'TECH_BAG'} = [ $self->tech_bag()->items() ];
        $data{'AVAILABLE_TECH'} = [ $self->available_tech()->items() ];

        # vp tokens

        $data{'VP_BAG'} = [ $self->vp_bag()->items() ];

        # discoveries

        foreach my $discovery ( values( %{ $self->discoveries() } ) ) {
            $data{'DISCOVERIES'}->{ $discovery->tag() } = {};
            $discovery->to_hash( $data{'DISCOVERIES'}->{ $discovery->tag() } );
        }

        $data{'DISCOVERY_BAG'} = [ $self->discovery_bag()->items() ];

        # board

        if ( defined( $self->{'BOARD'} ) ) {
            my %board = ();
            $self->{'BOARD'}->to_hash( \%board );
            $data{'BOARD'} = \%board;
        }

        # tiles

#        print STDERR "\nSaved Tiles: " . join( ',', keys( %{ $self->tiles() } ) );

        foreach my $tile ( values( %{ $self->tiles() } ) ) {
            $data{'TILES'}->{ $tile->tag() } = {};
            $tile->to_hash( $data{'TILES'}->{ $tile->tag() } );
        }

        # developments

        my @developments = ();
        foreach my $development ( values( %{ $self->developments() } ) ) {
            my %dev_hash = ();
            $development->to_hash( \%dev_hash );
            $data{'DEVELOPMENTS'}->{ $development->tag() } = \%dev_hash;
        }

        $data{'DEVELOPMENT_STACK'} = [ $self->development_stack()->items() ];

        # ship templates
#        print STDERR "\n saving ship_templates ... ";

        $data{'SHIP_TEMPLATES'} = {};
        foreach my $template ( values( %{ $self->templates() } ) ) {

            my %template_hash = ();
            $template->to_hash( \%template_hash );

            $data{'SHIP_TEMPLATES'}->{ $template->tag() } = \%template_hash;
        }

        $data{'TEMPLATE_COMBAT_ORDER'} = [ $self->template_combat_order()->items() ];

        # ships

        $data{'SHIPS'} = {};
#        print STDERR "\nShip Keys: " . join( ',', keys( %{ $self->ships() } ) );
        foreach my $ship ( values( %{ $self->ships() } ) ) {
            my %ship_hash = ();
            $ship->to_hash( \%ship_hash );
#            print STDERR "\nSaving ship data " . $ship->tag() . ' ... ';
            $data{'SHIPS'}->{ $ship->tag() } = \%ship_hash;
        }

        # ship pool

        $data{'SHIP_POOL'} = {};
        foreach my $ship ( values( %{ $self->ship_pool() } ) ) {
            my %ship_hash = ();
            $ship->to_hash( \%ship_hash );
            $data{'SHIP_POOL'}->{ $ship->tag() } = \%ship_hash;
        }

        # races

        $data{'RACES'} = {};
        foreach my $race ( values( %{ $self->races() } ) ) {
            my %race_hash = ();
            $race->to_hash( \%race_hash );
            $data{'RACES'}->{ $race->tag() } = \%race_hash;
        }

        # combat rolls

        $data{'COMBAT_ROLLS'} = [ $self->combat_hits()->items() ];
        $data{'MISSILE_DEFENSE_HITS'} = $self->missile_defense_hits();
    }

    truncate( $self->{'FH_STATE'}, 0 );

    $Data::Dumper::Indent = 1;
    $Data::Dumper::Sortkeys = 1;
    print { $self->{'FH_STATE'} } Dumper( \%data );

#    print STDERR Dumper( \%data );
#    if ( scalar( @{ $data{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} } ) > 0 ) {
#        $self->_close_all();
#        exit();
#    }

    # using Storable

#    stores_fd( $self->{'DATA'}, $self->{'FH_STATE'} );

    return;
}

#############################################################################

sub _open_file_with_lock {
    my $self        = shift;
    my $file_path   = shift;
    my $flag_create = shift; $flag_create = 0           unless defined( $flag_create );

    my $fh;

    unless ( $flag_create ) {
        unless ( -e $file_path ) {
            $self->set_error( 'Non-existant file: ' . $file_path );
            return undef;
        }
    }

    unless ( open( $fh, '+>>', $file_path ) ) {
        $self->set_error( 'Failed to open file for writing: ' . $file_path );
        return undef;
    }

    unless( flock( $fh, LOCK_EX ) ) {
        $self->set_error( 'Failed to lock file: ' . $file_path );
        return undef;
    }

    return $fh;
}

#############################################################################

sub _open_file {
    my $self        = shift;
    my $file_path   = shift;

    my $fh;

    unless ( -e $file_path ) {
        return undef;
    }

    unless ( open( $fh, '<', $file_path ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $file_path );
        return undef;
    }

    flock( $fh, LOCK_SH );

    return $fh;
}

#############################################################################
#############################################################################
1
