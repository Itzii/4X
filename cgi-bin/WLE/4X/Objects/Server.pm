package WLE::4X::Objects::Server;

use strict;
use warnings;

use Data::Dumper;
use Fcntl ':flock';
#use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
#use XML::Bare;

use WLE::Methods::Simple;

use WLE::4X::Enums::Status;

use WLE::4X::Objects::MetaActions;
use WLE::4X::Objects::RawActions;
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
    $self->{'SETTINGS'}->{'SHIP_INDEX'} = 1;

    $self->{'SETTINGS'}->{'SOURCE_TAGS'} = [];
    $self->{'SETTINGS'}->{'OPTION_TAGS'} = [];

    $self->{'SETTINGS'}->{'LONG_NAME'} = '';

    $self->{'SETTINGS'}->{'PLAYER_IDS'} = [];

    $self->{'RACES'} = {};
    $self->{'SHIP_TEMPLATES'} = {};
    $self->{'SHIPS'} = {};
    $self->{'SHIP_POOL'} = {};
    $self->{'TILES'} = {};


    $self->{'STATE'} = {
        'STATE' => $ST_PREGAME,
        'ROUND' => 0,
        'PHASE' => $PH_PREPARING,
        'PLAYER' => -1,
        'SUBPHASE' => 0,
    };

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

        'status'            => { 'method' => \&action_status },

        'create_game'       => { 'flag_req_status' => $ST_PREGAME, 'method' => \&action_create_game },
        'add_source'        => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_source },
        'remove_source'     => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_source },
        'add_option'        => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_option },
        'remove_option'     => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_option },
        'add_player'        => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_player },
        'remove_player'     => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_player },
        'begin'             => { 'flag_req_status' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_begin },

        'select_race'       => { 'flag_req_status' => $ST_RACESELECTION, 'flag_player_phase' => 1, 'method' => \&action_select_race_and_location },



    );

    unless ( defined( $actions{ $action } ) ) {
        return ( 'success' => 0, 'message' => "Invalid 'action' element." );
    }

    if ( defined( $actions{ $action }->{'flag_req_status'} ) ) {
        if ( $self->state() != $actions{ $action }->{'flag_req_status'} ) {
            return ( 'success' => 0, 'message' => 'Invalid status for action.' );
        }
    }


    if ( defined( $actions{ $action }->{'flag_owner_only'} ) && $self->user_is_owner() == 0 )  {
        return ( 'success' => 0, 'message' => 'Action is allowed by game owner only.' );
    }

    if ( defined( $actions{ $action }->{'flag_player_phase'} ) ) {
        my $waiting_on = $self->waiting_on_player_id();

        if ( $waiting_on == -1 || ( $waiting_on > -1 && $waiting_on != $self->current_user() ) ) {
            return ( 'success' => 0, 'message' => 'Action is not allowed by this player at this time.' );
        }
    }

    my %response = (
        'success' => 0,
        'message' => '',
    );

    my $data = undef;
    $args{'__data'} = \$data;
    $response{'success'} = $actions{ $action }->{'method'}->( $self, %args );
    $response{'message'} = $self->last_error();
    $response{'data'} = $data;

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

sub item_is_allowed_in_game {
    my $self        = shift;
    my $element     = shift;

    if ( matches_any( $element->source_tag(), $self->source_tags() ) ) {
        if (
            $element->required_option() eq ''
            || matches_any( $element->required_option(), $self->option_tags() )
        ) {
            return 1;
        }
    }

    return 0;
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

sub action_status {
    my $self        = shift;
    my %args        = @_;

    my $r_data = $args{'__data'};

    my $player_id = -1;

    if ( $self->{'STATE'}->{'PLAYER'} > -1 ) {
        $player_id = $self->{'SETTINGS'}->{'PLAYER_IDS'}->[ $self->{'STATE'}->{'PLAYER'} ];
    }

    $$r_data = sprintf(
        '%i:%i:%i:%i:%i',
        $self->{'STATE'}->{'STATE'},
        $self->{'STATE'}->{'ROUND'},
        $self->{'STATE'}->{'PHASE'},
        $player_id,
        $self->{'STATE'}->{'SUBPHASE'},
    );

    return 1;
}

#############################################################################

sub status {
    my $self        = shift;

    return sprintf(
        '%i:%i:%i:%i:%i',
        $self->{'STATE'}->{'STATE'},
        $self->{'STATE'}->{'ROUND'},
        $self->{'STATE'}->{'PHASE'},
        $self->{'STATE'}->{'PLAYER'},
        $self->{'STATE'}->{'SUBPHASE'},
    );
}

#############################################################################

sub state {
    my $self        = shift;

    return $self->{'STATE'}->{'STATE'};
}

#############################################################################

sub set_state {
    my $self        = shift;
    my $new_state   = shift;

    $self->{'STATE'}->{'STATE'} = $new_state;

    return;
}

#############################################################################

sub waiting_on_player_id {
    my $self        = shift;

    return $self->{'STATE'}->{'PLAYER'};
}

#############################################################################

sub set_waiting_on_player_id {
    my $self        = shift;
    my $player_id   = shift;

    $self->{'STATE'}->{'PLAYER'} = $player_id;

    return;
}

#############################################################################

sub round {
    my $self        = shift;

    return $self->{'STATE'}->{'ROUND'};
}

#############################################################################

sub set_round {
    my $self        = shift;
    my $new_round   = shift;

    $self->{'STATE'}->{'ROUND'} = $new_round;

    return;
}

#############################################################################

sub phase {
    my $self        = shift;

    return $self->{'STATE'}->{'PHASE'};
}

#############################################################################

sub set_phase {
    my $self        = shift;
    my $new_phase   = shift;

    $self->{'STATE'}->{'PHASE'} = $new_phase;

    return;
}

#############################################################################

sub tick_player {
    my $self        = shift;

    my $done_player = shift( @{ $self->{'SETTINGS'}->{'PLAYERS_PENDING'} } );

    push( @{ $self->{'SETTINGS'}->{'PLAYERS_DONE'} }, $done_player );

    if ( scalar( @{ $self->{'SETTINGS'}->{'PLAYERS_PENDING'} } ) > 0 ) {
        $self->set_waiting_on_player_id( $self->{'SETTINGS'}->{'PLAYERS_PENDING'}->[ 0 ] );
        return 1;
    }

    $self->set_waiting_on_player_id( -1 );
    return 0;
}

#############################################################################

sub next_ship_index {
    my $self        = shift;

    my $index = $self->{'SETTINGS'}->{'SHIP_INDEX'};
    $self->{'SETTINGS'}->{'SHIP_INDEX'}++;

    return $index;
}

#############################################################################

sub start_next_round {
    my $self        = shift;




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

sub board {
    my $self        = shift;

    return $self->{'BOARD'};
}

#############################################################################

sub tiles {
    my $self        = shift;

    return $self->{'TILES'};
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

sub ships {
    my $self        = shift;

    return $self->{'SHIPS'};
}

#############################################################################

sub ship_pool {
    my $self        = shift;

    return $self->{'SHIP_POOL'};
}

#############################################################################

sub ship_components {
    my $self        = shift;

    return $self->{'COMPONENTS'};
}

#############################################################################

sub technology {
    my $self        = shift;

    return $self->{'TECHNOLOGY'};
}

#############################################################################

sub discoveries {
    my $self        = shift;

    return $self->{'DISCOVERIES'};
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
