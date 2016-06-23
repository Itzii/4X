package WLE::4X::Objects::Server;

use strict;
use warnings;

use Data::Dumper;
use Fcntl ':flock';
#use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
#use XML::Bare;

use WLE::4X::Methods::Simple;

use WLE::4X::Objects::MetaActions;
use WLE::4X::Objects::RawActions;
use WLE::4X::Objects::LogActions;

use WLE::4X::Objects::Element;
use WLE::4X::Objects::ShipComponent;
use WLE::4X::Objects::Technology;
use WLE::4X::Objects::Development;
use WLE::4X::Objects::Discovery;
use WLE::4X::Objects::Tile;
use WLE::4X::Objects::Board;


# state breakdown

# d1:dd2:dd3:dd4

# d1 -
# 0 - pre-game
#
# shouldn't be any more digits
#
# 1 - game has started - selecting races and positions
#
# dd2 -
#  00 -
#
# 2 - normal turn
# 3 - game has finished



#############################################################################
# constructor args
#
# 'resource_file'		- required : path to the core resource file
# 'state_files'         - required : path to folder holding state files
# 'log_files'           - required : path to folder holding log files

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

    $self->{'FH_STATE'} = undef;
    $self->{'FH_LOG'} = undef;
    $self->{'LAST_ERROR'} = '';

    $self->{'ENV'} = {};

    $self->{'ENV'}->{'FILE_RESOURCES'} = $args{'resource_file'};
    $self->{'ENV'}->{'DIR_STATE_FILES'} = $args{'state_files'};
    $self->{'ENV'}->{'DIR_LOG_FILES'} = $args{'log_files'};

    $self->{'ENV'}->{'DIR_STATE_FILES'} =~ s{ /$ }{}xs;
    $self->{'ENV'}->{'DIR_LOG_FILES'} =~ s{ /$ }{}xs;


    unless ( -e $self->_file_resources() ) {
        $self->set_error( 'Unable to locate core resource file: ' . $self->_file_resources() );

        return $self;
    }

    unless ( -d $self->_dir_state_files() ) {
        $self->set_error( 'Unable to locate state files directory: ' . $self->_dir_state_files() );

        return $self;
    }

    unless ( -d $self->_dir_log_files() ) {
        $self->set_error( 'Unable to locate log files directory: ' . $self->_dir_log_files() );

        return $self;
    }

    $self->{'SETTINGS'} = {};

    $self->{'SETTINGS'}->{'LOG_ID'} = '';
    $self->{'SETTINGS'}->{'OWNER_ID'} = 0;

    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [];
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [];

    $self->{'SETTINGS'}->{'LONG_NAME'} = '';

    $self->{'SETTINGS'}->{'STATE'} = '0';

    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [];


    return $self;
}

#############################################################################

sub has_option {
    my $self        = shift;
    my $option      = shift;

    if ( $option eq '' ) {
        return 1;
    }

    return matches_any( $option, @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} } );
}

#############################################################################

sub has_source {
    my $self        = shift;
    my $source      = shift;

    if ( $source eq '' ) {
        return 1;
    }

    return matches_any( $source, @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} } );
}

#############################################################################

sub source_tags {
    my $self        = shift;

    return @{ $self->{'SETTINGS'}->{'SOURCE_TAGS'} };
}

#############################################################################

sub option_tags {
    my $self        = shift;

    return @{ $self->{'SETTINGS'}->{'OPTION_TAGS'} };
}

#############################################################################

sub player_ids {
    my $self        = shift;

    return @{ $self->{'SETTINGS'}->{'PLAYER_IDS'} };
}


#############################################################################

sub last_error {
    my $self        = shift;

    my $error = $self->{'LAST_ERROR'};

    $self->{'LAST_ERROR'} = '';

    return $error;
}

#############################################################################

sub set_error {
    my $self        = shift;
    my $value       = shift;

    $self->{'LAST_ERROR'} = $value;
}

#############################################################################

sub long_name {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'LONG_NAME'};
}

#############################################################################

sub status {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'STATE'};
}

#############################################################################

sub board {
    my $self        = shift;

    return $self->{'BOARD'};
}

#############################################################################

sub tile_from_tag {
    my $self        = shift;
    my $tag         = shift;

    return $self->{'TILES'}->{ $tag };
}

#############################################################################

sub log_id {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'LOG_ID'};
}

#############################################################################

sub _set_log_id {
    my $self        = shift;
    my $value       = shift;

    if ( defined( $value ) ) {
        if ( $value =~ m{ ^ [0-9a-zA-Z]{8,20} $ }xs ) {
            $self->{'SETTINGS'}->{'LOG_ID'} = $value;
            return 1;
        }
    }
    else {
        $self->set_error( 'Missing Log ID' );
        return 0;
    }

    $self->set_error( 'Invalid Log ID: ' . $value );

    return 0;
}

#############################################################################

sub _owner_id {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'OWNER_ID'};
}

#############################################################################

sub _set_owner_id {
    my $self        = shift;
    my $value       = shift;

    if ( defined( $value ) ) {
        if ( looks_like_number( $value ) ) {
            $self->{'SETTINGS'}->{'OWNER_ID'} = $value;
            return 1;
        }
    }
    else {
        $self->set_error( 'Missing Owner ID' );
        return 0;
    }

    $self->set_error( 'Invalid Owner ID: ' . $value );
    return 0;
}

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

        $data{'BOARD'} = $self->{'BOARD'};

        # developments

        my @developments = ();
        foreach my $development ( @{ $self->{'DEVELOPMENTS'} } ) {
            my $dev_hash = {};
            $development->to_hash( $dev_hash );
            push( @developments, $dev_hash );
        }
        $data{'DEVELOPMENTS'} = \@developments;






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

sub _file_resources {
    my $self        = shift;

    return $self->{'ENV'}->{'FILE_RESOURCES'};
}

#############################################################################

sub _dir_state_files {
    my $self        = shift;

    return $self->{'ENV'}->{'DIR_STATE_FILES'};
}

#############################################################################

sub _dir_log_files {
    my $self        = shift;

    return $self->{'ENV'}->{'DIR_LOG_FILES'};
}

#############################################################################

sub _log_file {
    my $self        = shift;

    return $self->_dir_log_files() . '/' . $self->log_id() . '.log';
}

#############################################################################

sub _state_file {
    my $self        = shift;

    return $self->_dir_state_files() . '/' . $self->log_id() . '.state';
}

#############################################################################
#############################################################################
1
