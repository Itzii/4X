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

    unless ( open( $fh, '<', $self->_file_resources() ) ) {
        $self->set_error( 'Failed to open file for reading: ' . $self->_file_resources() );
        return 0;
    }

    flock( $fh, LOCK_SH );

    # using Data::Dumper

    my $VAR1;
    my @data = <$fh>;
    my $single_line = join( '', @data );
    eval $single_line; warn $@ if $@;

    # settings

    unless ( defined( $VAR1->{'PLAYER_COUNT_SETTINGS'} ) ) {
        $self->set_error( 'Missing Section in resource file: PLAYER_COUNT_SETTINGS' );
        return 0;
    }

    my $settings = $VAR1->{'PLAYER_COUNT_SETTINGS'}->{ scalar( $self->player_ids() ) };

    unless ( defined( $settings ) ) {
        $self->set_error( 'Invalid Player Count: ' . scalar( $self->player_ids() ) );
        return 0;
    }

    unless ( $self->has_source( $settings->{'SOURCE_TAG'} ) ) {
        $self->set_error( 'Invalid player count for chosen sources: ' . scalar( $self->player_ids() ) );
        return 0;
    }

    # vp tokens

    $self->{'VP_BAG'} = [];

    foreach my $value ( 1 .. 4 ) {
        if ( defined( $settings->{'VP_' . $value } ) ) {
            foreach ( 0 .. $settings->{'VP_' . $value } - 1 ) {
                push( @{ $self->{'VP_BAG'} }, $value );
            }
        }
    }

    shuffle_in_place( $self->{'VP_BAG'} );




#    'START_TECH_COUNT' => 22,
#    'ROUND_TECH_COUNT' => 10,
#    'SECTOR_LIMIT_2' => 12,
#    'SECTOR_LIMIT_3' => 22,
#    'DEVELOPMENTS' => 8,



    # setup ship component tiles

    unless ( defined( $VAR1->{'COMPONENTS'} ) ) {
        $self->set_error( 'Missing Section in resource file: COMPONENTS' );
        return 0;
    }

    $self->{'COMPONENTS'} = {};

    foreach my $component_key ( keys( %{ $VAR1->{'COMPONENTS'} } ) ) {
        my $component = WLE::4X::Objects::ShipComponent->new( 'server' => $self, 'tag' => $component_key );

        if ( $component->from_hash( $VAR1->{'COMPONENTS'}->{ $component_key } ) ) {

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

    unless ( defined( $VAR1->{'TECHNOLOGY'} ) ) {
        $self->set_error( 'Missing Section in resource file: TECHNOLOGY' );
        return 0;
    }

    $self->{'TECHNOLOGY'} = {};

    foreach my $tech_key ( keys( %{ $VAR1->{'TECHNOLOGY'} } ) ) {

        my $technology = WLE::4X::Objects::Technology->new( 'server' => $self, 'tag' => $tech_key );

        my @instances = $technology->from_hash( $VAR1->{'TECHNOLOGY'}->{ $tech_key } );

        if ( @instances ) {
            if ( matches_any( $instances[ 0 ]->source_tag(), $self->source_tags() ) ) {

                if ( $instances[ 0 ]->required_option() eq '' ) {
                    foreach ( @instances ) {
                        $self->{'TECHNOLOGY'}->{ $_->tag() } = $_;
                    }
                }
                elsif ( matches_any( $instances[ 0 ]->required_option(), $self->option_tags() ) ) {
                    foreach ( @instances ) {
                        $self->{'TECHNOLOGY'}->{ $_->tag() } = $_;
                    }
                }
            }
        }
    }















    $self->{'SETTINGS'}->{'STATE'} = '0:0';

    return;
}


#############################################################################
#############################################################################
1
