package WLE::4X::Objects::Server;

use strict;
use warnings;

use Data::Dumper;
use Fcntl ':flock';
#use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
#use XML::Bare;

use WLE::Methods::Simple;

use WLE::4X::Objects::MetaActions;
use WLE::4X::Objects::RawActions;
use WLE::4X::Objects::LogActions;
use WLE::4X::Objects::ServerState;

use WLE::4X::Objects::Element;
use WLE::4X::Objects::ShipComponent;
use WLE::4X::Objects::Technology;
use WLE::4X::Objects::Development;
use WLE::4X::Objects::Discovery;
use WLE::4X::Objects::Tile;
use WLE::4X::Objects::Board;
use WLE::4X::Objects::Race;
use WLE::4X::Objects::Ship;
use WLE::4X::Objects::ShipTemplate;


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
#  player index
#
#   dd3 -
#    00 - waiting to select race
#    01 - waiting to select location
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

    $self->{'ENV'}->{'CURRENT_USER'} = -1;
    $self->{'ENV'}->{'LOG_ID'} = '';


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

    $self->{'SETTINGS'}->{'STATUS'} = '0';

    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [];

    $self->{'RACES'} = {};
    $self->{'SHIP_TEMPLATES'} = {};


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

    $self->{'ENV'}->{'CURRENT_USER'} = -1;
    my $user_id = 0;
    foreach my $player_id ( $self->player_ids() ) {
        if ( $args{'user'} eq $player_id ) {
            $self->{'ENV'}->{'CURRENT_USER'} = $user_id;
        }
        $user_id++;
    }

    my $action = lc( $args{'action'} );
    delete( $args{'action'} );

    my %actions = (

        'status'            => { 'flag_prestart' => 0, 'flag_owner_only' => 0, 'flag_player_phase' => 0, 'method' => \&status },

        'create_game'       => { 'flag_prestart' => 0, 'flag_owner_only' => 0, 'flag_player_phase' => 0, 'method' => \&action_create_game },
        'add_source'        => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_add_source },
        'remove_source'     => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_remove_source },
        'add_option'        => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_add_option },
        'remove_option'     => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_remove_option },
        'add_player'        => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_add_player },
        'remove_player'     => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_remove_player },
        'begin'             => { 'flag_prestart' => 1, 'flag_owner_only' => 1, 'flag_player_phase' => 0, 'method' => \&action_begin },



    );

    unless ( defined( $actions{ $action } ) ) {
        return ( 'success' => 0, 'message' => "Invalid 'action' element." );
    }

    if ( $actions{ $action }->{'flag_prestart'} && $self->status() ne '0' ) {
        return ( 'success' => 0, 'message' => 'Unable to perform action on game in progress.' );
    }

    if ( $actions{ $action }->{'flag_owner_only'} && $self->user_is_owner() == 0 )  {
        return ( 'success' => 0, 'message' => 'Action is allowed by game owner only.' );
    }

    if ( $actions{ $action }->{'flag_player_phase'} ) {
        my $waiting_on = $self->waiting_on_player_id();

        if ( $waiting_on == -1 || ( $waiting_on > -1 && $waiting_on != $self->current_user() ) ) {
            return ( 'success' => 0, 'message' => 'Action is not allowed by this player at this time.' );
        }
    }

    my %response = (
        'success' => 0,
        'message' => '',
    );

    $response{'success'} = $actions{ $action }->{'method'}->( $self, %args );
    $response{'message'} = $self->last_error();

    return %response;
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

sub current_user {
    my $self        = shift;

    return $self->{'ENV'}->{'CURRENT_USER'};
}

#############################################################################

sub user_is_owner {
    my $self        = shift;

    return ( $self->current_user() == 0 );
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

    return $self->{'SETTINGS'}->{'STATUS'};
}

#############################################################################

sub status_parts {
    my $self        = shift;

    return split( /:/, $self->status() );
}

#############################################################################

sub waiting_on_player_id {
    my $self        = shift;

    return ( $self->status_parts() )[ 1 ];
}

#############################################################################

sub board {
    my $self        = shift;

    return $self->{'BOARD'};
}

#############################################################################

sub races {
    my $self        = shift;

    return $self->{'RACES'};
}

#############################################################################

sub templates {
    my $self        = shift;

    return $self->{'SHIP_TEMPLATES'};
}

#############################################################################

sub ship_components {
    my $self        = shift;

    return $self->{'COMPONENTS'};
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
    my $log_id      = shift; $log_id = $self->log_id()          unless ( defined( $log_id ) );

    return $self->_dir_state_files() . '/' . $log_id . '.state';
}


#############################################################################
#############################################################################
1
