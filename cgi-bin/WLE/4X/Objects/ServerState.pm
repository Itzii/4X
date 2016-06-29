package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Methods::Simple;


#############################################################################

sub _log_data {
    my $self        = shift;
    my $data        = shift;

    print { $self->{'FH_LOG'} } $data . "\n";

    return;
}

#############################################################################

sub _open_for_writing {
    my $self        = shift;
    my $log_id      = shift;

    $self->set_error( '' );

    unless ( $self->_set_log_id( $log_id ) ) {
        $self->set_error( 'Invalid Log ID: ' . $log_id );
        return 0;
    }

    $self->{'FH_LOG'} = $self->_open_file_with_lock( $self->_log_file() );

    $self->{'FH_STATE'} = $self->_open_file_with_lock( $self->_state_file() );

    if ( defined( $self->{'FH_LOG'} ) && defined( $self->{'FH_STATE'} ) ) {
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

    my $fh;

    unless ( open( $fh, '<', $self->_state_file() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_state_file() );
        return 0;
    }

    flock( $fh, LOCK_SH );

    # using Data::Dumper

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    $self->{'TECH_DRAW_COUNT'} = $VAR1->{'ROUND_TECH_COUNT'};

    # setup ship component tiles
    # print STDERR "\n  ship components ... ";

    unless ( defined( $VAR1->{'COMPONENTS'} ) ) {
        $self->set_error( 'Missing Section in resource file: COMPONENTS' );
        return 0;
    }

    $self->{'COMPONENTS'} = {};

    foreach my $component_key ( keys( %{ $VAR1->{'COMPONENTS'} } ) ) {
        my $component = WLE::4X::Objects::ShipComponent->new(
            'server' => $self,
            'tag' => $component_key,
            'hash' => $VAR1->{'COMPONENTS'}->{ $component_key },
        );

        if ( defined( $component ) ) {
            $self->{'COMPONENTS'}->{ $component_key } = $component;
        }
    }

    # setup technology tiles
#    print STDERR "\n  technology ... ";

    unless ( defined( $VAR1->{'TECHNOLOGY'} ) ) {
        $self->set_error( 'Missing Section in resource file: TECHNOLOGY' );
        return 0;
    }

    $self->{'TECHNOLOGY'} = {};

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new(
            'server' => $self,
            'tag' => $tech_key,
            'hash' => $VAR1->{'TECHNOLOGY'}->{ $tech_key },
        );

        if ( defined( $technology ) ) {
            $self->{'TECHNOLOGY'}->{ $technology->tag() } = $technology;
        }
    }

    $self->{'TECH_BAG'} = $VAR1->{'TECH_BAG'};

    $self->{'AVAILABLE_TECH'} = $VAR1->{'AVAILABLE_TECH'};

    # vp tokens
    # print STDERR "\n  vp tokens ... ";

    $self->{'VP_BAG'} = $VAR1->{'VP_BAG'};

    # discoveries
#    print STDERR "\n  discoveries ... ";

    $self->{'DISCOVERIES'} = {};

    foreach my $disc_key ( keys( %{ $VAR1->{'DISCOVERIES'} } ) ) {

        my $discovery = WLE::4X::Objects::Discovery->new(
            'server' => $self,
            'tag' => $disc_key,
            'hash' => $VAR1->{'DISCOVERIES'}->{ $disc_key },
        );

        if ( defined( $discovery ) ) {
            $self->{'DISCOVERIES'}->{ $discovery->tag() } = $discovery;
        }
    }

    $self->{'DISCOVERY_BAG'} = $VAR1->{'DISCOVERY_BAG'};

    # tiles
#    print STDERR "\n  tiles ... ";

    $self->{'TILE_STACK_1'} = $VAR1->{'TILE_STACK_1'};
    $self->{'TILE_STACK_2'} = $VAR1->{'TILE_STACK_2'};
    $self->{'TILE_STACK_3'} = $VAR1->{'TILE_STACK_3'};

    $self->{'TILES'} = {};

    $self->{'BOARD'} = $VAR1->{'BOARD'};

#    print STDERR "\nReading Tiles ... ";

    foreach my $tile_key ( keys( %{ $VAR1->{'TILES'} } ) ) {

        my $tile = WLE::4X::Objects::Tile->new(
            'server' => $self,
            'tag' => $tile_key,
            'hash' => $VAR1->{'TILES'}->{ $tile_key },
        );

#        print "\nTile: " . $tile->tag();

        if ( defined( $tile ) ) {
            $self->{'TILES'}->{ $tile->tag() } = $tile;
        }
    }

    # developments
#    print STDERR "\n  developments ... ";

    $self->{'DEVELOPMENTS'} = [];

    foreach my $dev_key ( keys( %{ $VAR1->{'DEVELOPMENTS'} } ) ) {

        my $development = WLE::4X::Objects::Development->new(
            'server' => $self,
            'tag' => $dev_key,
            'hash' => $VAR1->{'DEVELOPMENTS'}->{ $dev_key },
        );

        if ( defined( $development ) ) {
            push( @{ $self->{'DEVELOPMENTS'} }, $development );
        }
    }

    $self->{'SETTINGS'} = $VAR1->{'SETTINGS'};

    # setup ship templates
#    print STDERR "\n  ship templates ... ";

    unless ( defined( $VAR1->{'SHIP_TEMPLATES'} ) ) {
        $self->set_error( 'Missing Section in resource file: SHIP_TEMPLATES' );
        return 0;
    }

    $self->{'SHIP_TEMPLATES'} = {};

    foreach my $template_key ( keys( %{ $VAR1->{'SHIP_TEMPLATES'} } ) ) {

        my $template = WLE::4X::Objects::ShipTemplate->new(
            'server' => $self,
            'tag' => $template_key,
            'hash' => $VAR1->{'SHIP_TEMPLATES'}->{ $template_key },
        );

        if ( defined( $template ) ) {
            $self->{'SHIP_TEMPLATES'}->{ $template->tag() } = $template;
        }
    }


    # races

    $self->{'RACES'} = {};

    foreach my $race_tag ( keys( %{ $VAR1->{'RACES'} } ) ) {

        my $race = WLE::4X::Objects::Race->new(
            'server' => $self,
            'tag' => $race_tag,
            'hash' => $VAR1->{'RACES'}->{ $race_tag },
        );

        if ( defined( $race ) ) {
            $self->{'RACES'}->{ $race_tag } = $race;
        }
    }


    # using Storable

#    $self->{'DATA'} = fd_retrieve( $fh );

    close( $fh );

    return 1;
}

#############################################################################

sub _save_state {
    my $self        = shift;

    # using Data::Dumper

    my %data = ();

    $data{'SETTINGS'} = $self->{'SETTINGS'};

    unless ( $self->status() eq '0' ) {

        $data{'TECH_DRAW_COUNT'} = $self->{'TECH_DRAW_COUNT'};

        # ship components
        $data{'COMPONENTS'} = {};

        foreach my $key ( keys( %{ $self->{'COMPONENTS'} } ) ) {
            $data{'COMPONENTS'}->{ $key } = {};
            $self->{'COMPONENTS'}->{ $key }->to_hash( $data{'COMPONENTS'}->{ $key } );
        }

        # technology

        $data{'TECHNOLOGY'} = {};

        foreach my $key ( keys( %{ $self->{'TECHNOLOGY'} } ) ) {
            $data{'TECHNOLOGY'}->{ $key } = {};
            $self->{'TECHNOLOGY'}->{ $key }->to_hash( $data{'TECHNOLOGY'}->{ $key } );
        }

        $data{'TECH_BAG'} = $self->{'TECH_BAG'};
        $data{'AVAILABLE_TECH'} = $self->{'AVAILABLE_TECH'};

        # vp tokens

        $data{'VP_BAG'} = $self->{'VP_BAG'};

        # discoveries

        foreach my $key ( keys( %{ $self->{'DISCOVERIES'} } ) ) {
            $data{'DISCOVERIES'}->{ $key } = {};
            $self->{'DISCOVERIES'}->{ $key }->to_hash( $data{'DISCOVERIES'}->{ $key } );
        }

        $data{'DISCOVERY_BAG'} = $self->{'DISCOVERY_BAG'};

        # tiles

        foreach my $key ( keys( %{ $self->{'TILES'} } ) ) {
            $data{'TILES'}->{ $key } = {};
            $self->{'TILES'}->{ $key }->to_hash( $data{'TILES'}->{ $key } );
        }

        $data{'TILE_STACK_1'} = $self->{'TILE_STACK_1'};
        $data{'TILE_STACK_2'} = $self->{'TILE_STACK_2'};
        $data{'TILE_STACK_3'} = $self->{'TILE_STACK_3'};

        $data{'BOARD'} = {};
        $self->{'BOARD'}->to_hash( $data{'BOARD'} );

        # developments

        my @developments = ();
        foreach my $development ( @{ $self->{'DEVELOPMENTS'} } ) {
            my $dev_hash = {};
            $development->to_hash( $dev_hash );
            push( @developments, $dev_hash );
        }
        $data{'DEVELOPMENTS'} = \@developments;

        # ship templates

        $data{'SHIP_TEMPLATES'} = {};
        foreach my $template_tag ( %{ $self->{'SHIP_TEMPLATES'} } ) {

            if ( defined( $self->{'SHIP_TEMPLATES'}->{ $template_tag } ) ) {
                my %template_hash = ();
                $self->{'SHIP_TEMPLATES'}->{ $template_tag }->to_hash( \%template_hash );

                $data{'SHIP_TEMPLATES'}->{ $template_tag } = \%template_hash;
            }
        }

        # races

        $data{'RACES'} = {};
        foreach my $race_tag ( %{ $self->{'RACES'} } ) {

            if ( defined( $self->{'RACES'}->{ $race_tag } ) ) {
                my %race_hash = ();
                $self->{'RACES'}->{ $race_tag }->to_hash( \%race_hash );

                $data{'RACES'}->{ $race_tag } = \%race_hash;
            }
        }

    }

    truncate( $self->{'FH_STATE'}, 0 );

    print { $self->{'FH_STATE'} } Dumper( \%data );

    # using Storable

#    stores_fd( $self->{'DATA'}, $self->{'FH_STATE'} );

    return;
}

#############################################################################

sub _open_file_with_lock {
    my $self        = shift;
    my $file_path   = shift;

    my $fh;

    unless ( -e $file_path ) {

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
#############################################################################
1