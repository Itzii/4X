package WLE::4X::Objects::Server;

use strict;
use warnings;

use WLE::4X::Methods::Simple;



#############################################################################

sub _raw_add_source {
    my $self        = shift;
    my $tag         = shift;

    push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_source {
    my $self        = shift;
    my $tag         = shift;

    my @current_tags = $self->source_tags();
    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [];

    foreach my $t ( @current_tags ) {
        unless ( $t eq $tag ) {
            push( @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} }, $t );
        }
    }

    return;
}

#############################################################################

sub _raw_add_option {
    my $self        = shift;
    my $tag         = shift;

    push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $tag );

    return;
}

#############################################################################

sub _raw_remove_option {
    my $self        = shift;
    my $tag         = shift;

    my @current_tags = $self->source_tags();
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [];

    foreach my $t ( @current_tags ) {
        unless ( $t eq $tag ) {
            push( @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} }, $t );
        }
    }

    return;
}


#############################################################################

sub _raw_add_player {
    my $self        = shift;
    my $player_id   = shift;

    push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $player_id );

    return;
}


#############################################################################

sub _raw_remove_player {
    my $self        = shift;
    my $player_id   = shift;

    my @current_ids = $self->player_ids();
    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [];

    foreach my $id ( @current_ids ) {
        unless ( $id == $player_id ) {
            push( @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} }, $id );
        }
    }

    return;
}

#############################################################################

sub _raw_begin {
    my $self       = shift;

    my $fh = undef;

#    print STDERR "\nraw_begin ... ";

    unless ( open( $fh, '<', $self->_file_resources() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_file_resources() );
        print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    flock( $fh, LOCK_SH );

    # using Data::Dumper

#    print STDERR "\nparsing ... ";

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    # settings
#    print STDERR "\n  settings ... ";

    unless ( defined( $VAR1->{'PLAYER_COUNT_SETTINGS'} ) ) {
        $self->set_error( 'Missing Section in resource file: PLAYER_COUNT_SETTINGS' );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    my $settings = $VAR1->{'PLAYER_COUNT_SETTINGS'}->{ scalar( $self->player_ids() ) };

    unless ( defined( $settings ) ) {
        $self->set_error( 'Invalid Player Count: ' . scalar( $self->player_ids() ) );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    unless ( $self->has_source( $settings->{'SOURCE_TAG'} ) ) {
        $self->set_error( 'Invalid player count for chosen sources: ' . scalar( $self->player_ids() ) );
        # print STDERR $self->{'LAST_ERROR'};
        return 0;
    }

    $self->{'TECH_DRAW_COUNT'} = $settings->{'ROUND_TECH_COUNT'};


    # ancient ships
    # print STDERR "\n  ancient ships ... ";

    # TODO





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

            if ( matches_any( $component->source_tag(), $self->source_tags() ) ) {
                if ( $component->required_option() eq '' ) {
                    $self->{'COMPONENTS'}->{ $component_key } = $component;
                }
                elsif ( matches_any( $component->required_option(), $self->option_tags() ) ) {
                    $self->{'COMPONENTS'}->{ $component_key } = $component;
                }
            }
        }
    }

    # setup technology tiles
#    print STDERR "\n  technology ... ";

    unless ( defined( $VAR1->{'TECHNOLOGY'} ) ) {
        $self->set_error( 'Missing Section in resource file: TECHNOLOGY' );
        return 0;
    }

    $self->{'TECHNOLOGY'} = {};
    my @tech_bag = ();

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new(
            'server' => $self,
            'tag' => $tech_key,
            'hash' => $VAR1->{'TECHNOLOGY'}->{ $tech_key },
        );

        if ( defined( $technology ) ) {
            if ( matches_any( $technology->source_tag(), $self->source_tags() ) ) {
                if (
                    $technology->required_option() eq ''
                    || matches_any( $technology->required_option(), $self->option_tags() )
                ) {
                    $self->{'TECHNOLOGY'}->{ $technology->tag() } = $technology;

                    foreach ( 1 .. $technology->count() ) {
                        push( @tech_bag, $technology->tag() );
                    }
                }
            }
        }
    }

    shuffle_in_place( \@tech_bag );

    $self->{'TECH_BAG'} = \@tech_bag;

    # draw beginning tech tiles

    my @available_tech = ();

    foreach ( 1 .. $settings->{'START_TECH_COUNT'} ) {
        push( @available_tech, shift( @tech_bag ) );
    }

    $self->{'AVAILABLE_TECH'} = \@available_tech;

    # vp tokens
    # print STDERR "\n  vp tokens ... ";

    $self->{'VP_BAG'} = [];

    foreach my $value ( 1 .. 4 ) {
        if ( defined( $settings->{'VP_' . $value } ) ) {
            foreach ( 0 .. $settings->{'VP_' . $value } - 1 ) {
                push( @{ $self->{'VP_BAG'} }, $value );
            }
        }
    }

    shuffle_in_place( $self->{'VP_BAG'} );

    # discoveries
#    print STDERR "\n  discoveries ... ";

    $self->{'DISCOVERIES'} = {};

    my @discovery_bag = ();

    foreach my $disc_key ( keys( %{ $VAR1->{'DISCOVERIES'} } ) ) {

        my $discovery = WLE::4X::Objects::Discovery->new(
            'server' => $self,
            'tag' => $disc_key,
            'hash' => $VAR1->{'DISCOVERIES'}->{ $disc_key },
        );

        if ( defined( $discovery ) ) {
            if ( matches_any( $discovery->source_tag(), $self->source_tags() ) ) {
                if (
                    $discovery->required_option() eq ''
                    || matches_any( $discovery->required_option(), $self->option_tags() )
                ) {
                    $self->{'DISCOVERIES'}->{ $discovery->tag() } = $discovery;

                    foreach ( 1 .. $discovery->count() ) {
                        push( @discovery_bag, $discovery->tag() );
                    }
                }
            }
        }
    }

    shuffle_in_place( \@discovery_bag );

    $self->{'DISCOVERY_BAG'} = \@discovery_bag;

    # tiles
#    print STDERR "\n  tiles ... ";


    $self->{'TILE_STACK_1'} = [];
    $self->{'TILE_STACK_2'} = [];
    $self->{'TILE_STACK_3'} = [];

    $self->{'TILES'} = {};

    $self->{'BOARD'} = WLE::4X::Objects::Board->new( 'server' => $self );

#    print STDERR "\nReading Tiles ... ";

    foreach my $tile_key ( keys( %{ $VAR1->{'TILES'} } ) ) {

        my $tile = WLE::4X::Objects::Tile->new(
            'server' => $self,
            'tag' => $tile_key,
            'hash' => $VAR1->{'TILES'}->{ $tile_key },
        );

#        print "\nTile: " . $tile->tag();

        if ( defined( $tile ) ) {
            if ( matches_any( $tile->source_tag(), $self->source_tags() ) ) {
                if (
                    $tile->required_option() eq ''
                    || matches_any( $tile->required_option(), $self->option_tags() )
                ) {
                    $self->{'TILES'}->{ $tile->tag() } = $tile;

                    if ( $tile->which_stack() == 0 ) {
                        $self->board()->place_tile( 0, 0, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 1 ) {
                        push( @{ $self->{'TILE_STACK_1'} }, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 2 ) {
                        push( @{ $self->{'TILE_STACK_2'} }, $tile->tag() );
                    }
                    elsif ( $tile->which_stack() == 3 ) {
                        push( @{ $self->{'TILE_STACK_3'} }, $tile->tag() );
                    }
                }
            }
        }
    }

    shuffle_in_place( $self->{'TILE_STACK_1'} );
    shuffle_in_place( $self->{'TILE_STACK_2'} );
    shuffle_in_place( $self->{'TILE_STACK_3'} );

    foreach my $count ( 2 .. 3 ) {
        if ( defined( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
            if ( looks_like_number( $settings->{'SECTOR_LIMIT_' . $count } ) ) {
                while ( scalar( @{ $self->{'TILE_STACK_' . $count } } ) > $settings->{'SECTOR_LIMIT_' . $count } ) {
                    my $tag = shift( @{ $self->{'TILE_STACK_' . $count} } );
                    delete( $self->{'TILES'}->{ $tag } );
                }
            }
        }
    }

    # developments
#    print STDERR "\n  developments ... ";

    my @developments = ();

    foreach my $dev_key ( keys( %{ $VAR1->{'DEVELOPMENTS'} } ) ) {

        my $development = WLE::4X::Objects::Development->new(
            'server' => $self,
            'tag' => $dev_key,
            'hash' => $VAR1->{'DEVELOPMENTS'}->{ $dev_key },
        );

        if ( defined( $development ) ) {
            if ( matches_any( $development->source_tag(), $self->source_tags() ) ) {
                if (
                    $development->required_option() eq ''
                    || matches_any( $development->required_option(), $self->option_tags() )
                ) {
                    push( @developments, $development );
                }
            }
        }
    }

    shuffle_in_place( \@developments );

    if ( looks_like_number( $settings->{'DEVELOPMENTS'} ) ) {
        while ( scalar( @developments ) > $settings->{'DEVELOPMENTS'} ) {
            shift( @developments );
        }
    }

    $self->{'DEVELOPMENTS'} = \@developments;




    $self->{'SETTINGS'}->{'STATE'} = '0:0';

    return;
}


#############################################################################
#############################################################################
1
