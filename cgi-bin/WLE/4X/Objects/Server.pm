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
use WLE::4X::Objects::PlayerActions;
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
    $self->{'RETURN_DATA'} = '';

    $self->{'ENV'} = {};

    $self->{'ENV'}->{'FILE_RESOURCES'} = $args{'resource_file'};
    $self->{'ENV'}->{'DIR_STATE_FILES'} = $args{'state_files'};
    $self->{'ENV'}->{'DIR_LOG_FILES'} = $args{'log_files'};

    $self->{'ENV'}->{'DIR_STATE_FILES'} =~ s{ /$ }{}xs;
    $self->{'ENV'}->{'DIR_LOG_FILES'} =~ s{ /$ }{}xs;

    $self->{'ENV'}->{'CURRENT_PLAYER_ID'} = -1;
    $self->{'ENV'}->{'FLAG_READ_ONLY'} = 0;


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

    $self->reset();

    return $self;
}

#############################################################################

sub reset {
    my $self        = shift;
    my $flag_hard   = shift; $flag_hard = 1             unless defined( $flag_hard );

    if ( $flag_hard ) {

    $self->{'SETTINGS'} = {};

        $self->{'SETTINGS'}->{'LOG_ID'} = '';

        $self->{'SETTINGS'}->{'SOURCE_TAGS'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
        $self->{'SETTINGS'}->{'OPTION_TAGS'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
        $self->{'SETTINGS'}->{'STARTING_LOCATIONS'} = WLE::Objects::Stack->new();

        $self->{'SETTINGS'}->{'LONG_NAME'} = '';

        $self->{'SETTINGS'}->{'USER_IDS'} = WLE::Objects::Stack->new();

        $self->{'SETTINGS'}->{'PLAYERS_PENDING'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
        $self->{'SETTINGS'}->{'PLAYERS_DONE'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
        $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'} = WLE::Objects::Stack->new( 'flag_exclusive' => 1 );
        $self->{'SETTINGS'}->{'WAITING_ON_PLAYER'} = -1;

        $self->{'SETTINGS'}->{'CURRENT_TRAITOR'} = '';
    }

    $self->{'RACES'} = {};
    $self->{'SHIP_TEMPLATES'} = {};
    $self->{'SHIPS'} = {};
    $self->{'SHIP_POOL'} = {};
    $self->{'COMPONENTS'} = {};
    $self->{'TILES'} = {};
    $self->{'TECHNOLOGY'} = {};
    $self->{'DISCOVERIES'} = {};
    $self->{'DEVELOPMENTS'} = {};

    $self->{'COMBAT_HITS'} = WLE::Objects::Stack->new();
    $self->{'MISSILE_DEFENSE_HITS'} = 0;

    $self->{'DIE_ROLLS'} = [];

    $self->{'BOARD'} = WLE::4X::Objects::Board->new( 'server' => $self );
    $self->{'TECH_BAG'} = WLE::Objects::Stack->new();
    $self->{'AVAILABLE_TECH'} = WLE::Objects::Stack->new();
    $self->{'DISCOVERY_BAG'} = WLE::Objects::Stack->new();
    $self->{'DEVELOPMENT_STACK'} = WLE::Objects::Stack->new();
    $self->{'VP_BAG'} = WLE::Objects::Stack->new();

    $self->{'TEMPLATE_COMBAT_ORDER'} = WLE::Objects::Stack->new();


    $self->{'STATE'} = {
        'STATE' => $ST_PREGAME,
        'ROUND' => 0,
        'PHASE' => $PH_PREPARING,
        'PLAYER' => -1,
        'SUBPHASE' => 0,
        'TILE' => '',
    };

    return;
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

    my $action_tag = lc( $args{'action'} );
    my $method = undef;

    if ( $action_tag eq 'create_game' ) {
        $method = \&action_create_game;
        $self->{'ENV'}->{'ACTING_PLAYER_ID'} = 0;
    }
    else {
        my $error_message = $self->_check_allowed_action( $args{'log_id'}, $args{'user'}, $action_tag, \$method );

        unless ( $error_message eq '' ) {
            $self->_close_all();
            return ( 'success' => 0, 'message' => $error_message );
        }
    }

    my %response = (
        'success' => 0,
        'message' => '',
    );

    $response{'success'} = $method->( $self, %args );
    $response{'message'} = $self->last_error();
    $response{'data'} = $self->returned_data();
    $response{'allowed'} = [];

    my $race = $self->race_of_acting_player();

    if ( defined( $race ) ) {
        $response{'allowed'} = [ $race->adjusted_allowed_actions()->items() ];
    }

    if ( $response{'success'} == 1 && $self->{'ENV'}->{'FLAG_READ_ONLY'} == 0 ) {
        $self->_save_state();
    }

    $self->_close_all();

    return %response;
}

#############################################################################

sub _check_allowed_action {
    my $self        = shift;
    my $log_id      = shift;
    my $user_id     = shift;
    my $action_tag  = shift;
    my $r_method    = shift;

    my %actions = (

        'status'            => { 'flag_anytime' => 1, 'flag_read_only' => 1, 'method' => \&action_status },
        'exchange'          => { 'flag_anytime' => 1, 'method' => \&action_exchange },

        'create_game'       => { 'method' => \&action_create_game },
        'add_source'        => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_source },
        'remove_source'     => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_source },
        'add_option'        => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_option },
        'remove_option'     => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_option },
        'add_player'        => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_add_player },
        'remove_player'     => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_remove_player },
        'begin'             => { 'flag_req_state' => $ST_PREGAME, 'flag_owner_only' => 1, 'method' => \&action_begin },

        'select_race'       => { 'flag_req_state' => $ST_RACESELECTION, 'flag_active_player' => 1, 'method' => \&action_select_race_and_location },

        'action_pass'       => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_pass_action },
        'action_explore'    => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_explore },
        'action_influence'  => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_influence },
        'action_research'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_research },
        'action_upgrade'    => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_upgrade },
        'action_build'      => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_build },
        'action_move'       => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_move },

        'action_react_upgrade' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_react_upgrade },
        'action_react_build' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_react_build },
        'action_react_move' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_react_move },

        'place_tile'        => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_explore_place_tile },
        'discard_tile'      => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_explore_discard_tile },
        'unflip_colony_ship'=> { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_influence_unflip_colony_ship },

        'place_influence_token' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_interrupt_place_influence_token },
        'replace_cube'      => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_interrupt_replace_cube },
        'choose_discovery'  => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_interrupt_choose_discovery },
#        'place_component'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_interrupt_place_component },
        'select_free_technology' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_interrupt_select_technology },

        'attack'            => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_attack },
        'roll_npc'          => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_roll_npc },
        'retreat'           => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_retreat },
        'allocate_hits'     => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_allocate_hits },
        'allocate_defense_hits' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_allocate_defense_hits },
        'acknowledge_hits'  => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_acknowledge_hits },
        'attack_populace'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_attack_populace },
        'apply_population_hits' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_apply_population_hits },
        'dont_attack_populace' => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_dont_attack_populace },
        'draw_vp'           => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_draw_vp },
        'select_vp_token'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_COMBAT, 'method' => \&action_select_vp_token },


        'use_colony_ship'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'flag_ignore_allowed' => 1, 'method' => \&action_use_colony_ship },
        'finish_turn'       => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_ACTION, 'method' => \&action_finish_turn },

    );

    my $action = $actions{ $action_tag };

    unless ( defined( $action ) ) {
        return "Invalid 'action' element.";
    }

    $$r_method = $action->{'method'};

    if ( defined( $action->{'flag_read_only'} ) ) {
        unless ( $self->_open_for_reading( $log_id ) ) {
            return $self->last_error();
        }
#        print STDERR "\n ( " . $self->outside_status() . " )";
        $self->{'ENV'}->{'FLAG_READ_ONLY'} = 1;
    }
    else {
        unless ( $self->_open_for_writing( $log_id ) ) {
            return $self->last_error();
        }
#        print STDERR "\n ( " . $self->outside_status() . " )";
    }

    $self->{'ENV'}->{'ACTING_PLAYER_ID'} = $self->user_ids()->index_of( $user_id );

    if ( defined( $action->{'flag_anytime'} ) ) {
        return '';
    }

    if ( defined( $action->{'flag_req_state'} ) ) {
        if ( $self->state() != $action->{'flag_req_state'} ) {
            return 'Invalid state for action.';
        }
    }

    if ( defined( $action->{'flag_owner_only'} ) && $self->player_is_owner() == 0 )  {
        return 'Action is allowed by game owner only.';
    }

    if ( defined( $action->{'flag_active_player'} ) ) {
        my $waiting_on = $self->waiting_on_player_id();

        if ( $waiting_on == -1 || ( $waiting_on > -1 && $waiting_on != $self->acting_player_id() ) ) {
#            print STDERR "\nUser IDs: " . join( ',', $self->user_ids()->items() );
#            print STDERR "\nActive User ID: " . $user_id;
#            print STDERR "\nWaiting On: " . $waiting_on;
#            print STDERR "\nActive: " . $self->acting_player_id();
            return 'Action is not allowed by this player at this time.';
        }
    }

    if ( defined( $action->{'flag_req_phase'} ) ) {
        if ( $self->phase() != $action->{'flag_req_phase'} ) {
            return 'Wrong phase for action.';
        }
    }

    if ( $self->state() == $ST_NORMAL ) {

        my $race = $self->race_of_acting_player();

        unless ( defined( $action->{'flag_ignore_allowed'} ) ) {
            unless ( $race->adjusted_allowed_actions()->contains( $action_tag ) ) {
                print STDERR "\nAllowed Actions: " . join( ',', $race->allowed_actions()->items() );
                return 'Action is not allowed by player at this time.';
            }
        }
    }

    return '';
}

#############################################################################

sub returned_data {
    my $self        = shift;

    return $self->{'RETURN_DATA'};
}

#############################################################################

sub set_returned_data {
    my $self        = shift;
    my $value       = shift;

    $self->{'RETURN_DATA'} = $value;

    return;
}

#############################################################################

sub has_option {
    my $self        = shift;
    my $option      = shift;

    if ( $option eq '' ) {
        return 1;
    }

    return $self->option_tags()->contains( $option );
}

#############################################################################

sub source_tags {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'SOURCE_TAGS'};
}

#############################################################################

sub has_source {
    my $self        = shift;
    my $source      = shift;

    if ( $source eq '' ) {
        return 1;
    }

    return $self->source_tags()->contains( $source );
}

#############################################################################

sub option_tags {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'OPTION_TAGS'};
}

#############################################################################

sub item_is_allowed_in_game {
    my $self        = shift;
    my $element     = shift;

    if (
        $self->source_tags()->contains( $element->source_tag() )
        && ( $element->required_option() eq '' || $self->option_tags()->contains( $element->required_option() ) )
    ) {
        return 1;
    }

    return 0;
}

#############################################################################

sub user_ids {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'USER_IDS'};
}

#############################################################################

sub user_id_of_player_id {
    my $self        = shift;
    my $player_id   = shift;

    if ( $player_id < 0 || $player_id > $self->user_ids()->count() - 1 ) {
        return -1;
    }

    return ($self->user_ids()->items())[ $player_id ]
}

#############################################################################

sub acting_player_id {
    my $self        = shift;

    return $self->{'ENV'}->{'ACTING_PLAYER_ID'};
}

#############################################################################

sub player_is_owner {
    my $self        = shift;

    return ( $self->acting_player_id() == 0 );
}

#############################################################################

sub race_tag_of_acting_player {
    my $self        = shift;

    my $race = $self->race_of_player_id( $self->acting_player_id() );

    if ( defined( $race ) ) {
        return $race->tag();
    }

    return '';
}

#############################################################################

sub race_of_player_id {
    my $self        = shift;
    my $player_id   = shift;

    foreach my $race ( values( %{ $self->races() } ) ) {
        if ( $race->owner_id() eq $player_id ) {
            return $race;
        }
    }

    return undef;
}

#############################################################################

sub race_of_acting_player {
    my $self        = shift;

    return $self->race_of_player_id( $self->acting_player_id() );
}

#############################################################################

sub action_status {
    my $self        = shift;
    my %args        = @_;

    $self->set_returned_data( $self->outside_status() );

    return 1;
}

#############################################################################

sub action_exchange {
    my $self        = shift;
    my %args        = @_;

    unless ( $self->_open_for_writing( $self->log_id() ) ) {
        return 0;
    }

    unless ( defined( $args{'res_from'} ) ) {
        $self->set_error( 'Missing Resource - From' );
        return 0;
    }

    unless ( defined( $args{'res_to'} ) ) {
        $self->set_error( 'Missing Resource - To' );
        return 0;
    }

    $self->_raw_exchange(
        $EV_FROM_INTERFACE,
        enum_from_resource_text( $args{'res_from'} ),
        enum_from_resource_text( $args{'res_to'} ),
    );

    $self->_save_state();

    $self->_close_all();

    return 1;
}

#############################################################################

sub outside_status {
    my $self        = shift;

    return sprintf(
        '%i:%i:%i:%i:%i:%s',
        $self->state(),
        $self->round(),
        $self->phase(),
        $self->user_id_of_player_id( $self->waiting_on_player_id() ),
        $self->subphase(),
        $self->current_tile(),
    );
}

#############################################################################

sub status {
    my $self        = shift;

    return sprintf(
        '%i:%i:%i:%i:%i:%s',
        $self->state(),
        $self->round(),
        $self->phase(),
        $self->waiting_on_player_id(),
        $self->subphase(),
        $self->current_tile(),
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

    return $self->{'SETTINGS'}->{'WAITING_ON_PLAYER'};
}

#############################################################################

sub set_waiting_on_player_id {
    my $self        = shift;
    my $player_id   = shift;

    $self->{'SETTINGS'}->{'WAITING_ON_PLAYER'} = $player_id;

    return;
}

#############################################################################

sub pending_players {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'PLAYERS_PENDING'};
}

#############################################################################

sub done_players {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'PLAYERS_DONE'};
}

#############################################################################

sub players_next_round {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'PLAYERS_NEXT_ROUND'};
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

sub subphase {
    my $self        = shift;

    return $self->{'STATE'}->{'SUBPHASE'};
}

#############################################################################

sub set_subphase {
    my $self        = shift;
    my $value       = shift;

    $self->{'STATE'}->{'SUBPHASE'} = $value;

    return;
}

#############################################################################

sub current_tile {
    my $self        = shift;

    return $self->{'STATE'}->{'TILE'};
}

#############################################################################

sub set_current_tile {
    my $self        = shift;
    my $value       = shift;

    $self->{'STATE'}->{'TILE'} = $value;

    return;
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

sub set_long_name {
    my $self        = shift;
    my $value       = shift;

    $self->{'SETTINGS'}->{'LONG_NAME'} = $value;

    return;
}

#############################################################################

sub current_traitor {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'CURRENT_TRAITOR'};
}

#############################################################################

sub set_current_traitor {
    my $self        = shift;
    my $value       = shift;

    $self->{'SETTINGS'}->{'CURRENT_TRAITOR'} = $value;

    return;
}

#############################################################################

sub board {
    my $self        = shift;

    return $self->{'BOARD'};
}

#############################################################################

sub tech_bag {
    my $self        = shift;

    return $self->{'TECH_BAG'};
}

#############################################################################

sub available_tech {
    my $self        = shift;

    return $self->{'AVAILABLE_TECH'};
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

sub new_ship_tag {
    my $self            = shift;
    my $template_tag    = shift;
    my $owner_id        = shift;

    if ( $owner_id eq '-1' ) {
        $owner_id = 'npc';
    }

    my $ship_index = 0;
    my $ship_tag;
    do {
        $ship_index++;
        $ship_tag = 'ship_' . $template_tag . '_' . $owner_id . '_' . $ship_index;
    } while ( exists( $self->ships()->{ $ship_tag } ) );

    return $ship_tag;
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

sub start_tech_count {
    my $self        = shift;

    return $self->{'START_TECH_COUNT'};
}

#############################################################################

sub set_start_tech_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'START_TECH_COUNT'} = $value;

    return;
}

#############################################################################

sub tech_draw_count {
    my $self        = shift;

    return $self->{'TECH_DRAW_COUNT'}
}

#############################################################################

sub set_tech_draw_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'TECH_DRAW_COUNT'} = $value;

    return;
}

#############################################################################

sub discoveries {
    my $self        = shift;

    return $self->{'DISCOVERIES'};
}

#############################################################################

sub discovery_bag {
    my $self        = shift;

    return $self->{'DISCOVERY_BAG'};
}

#############################################################################

sub developments {
    my $self        = shift;

    return $self->{'DEVELOPMENTS'};
}

#############################################################################

sub development_limit {
    my $self        = shift;

    if ( defined( $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} ) ) {
        return $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'};
    }

    return -1;
}

#############################################################################

sub set_development_limit {
    my $self        = shift;
    my $value       = shift;

    $self->{'SETTINGS'}->{'DEVELOPMENT_LIMIT'} = $value;

    return;
}

#############################################################################

sub development_stack {
    my $self        = shift;

    return $self->{'DEVELOPMENT_STACK'};
}

#############################################################################

sub vp_bag {
    my $self        = shift;

    return $self->{'VP_BAG'};
}

#############################################################################

sub template_combat_order {
    my $self        = shift;

    return $self->{'TEMPLATE_COMBAT_ORDER'};
}

#############################################################################

sub combat_hits {
    my $self        = shift;

    return $self->{'COMBAT_HITS'};
}

#############################################################################

sub missile_defense_hits {
    my $self        = shift;

    return $self->{'MISSILE_DEFENSE_HITS'};
}

#############################################################################

sub set_missile_defense_hits {
    my $self        = shift;
    my $value       = shift;

    $self->{'MISSILE_DEFENSE_HITS'} = $value;

    return;
}

#############################################################################

sub starting_locations {
    my $self        = shift;

    return $self->{'SETTINGS'}->{'STARTING_LOCATIONS'};
}

#############################################################################

sub tile_from_tag {
    my $self        = shift;
    my $tag         = shift;

    return $self->{'TILES'}->{ $tag };
}

#############################################################################

sub set_new_player_order {
    my $self        = shift;
    my @player_ids  = @_;

    $self->done_players()->clear();
    $self->pending_players()->fill( @player_ids );

    return;
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

sub die_rolls {
    my $self        = shift;

    return @{ $self->{'DIE_ROLLS'} };
}

#############################################################################

sub roll_die {
    my $self        = shift;

    my $roll = (int(rand(6)) + 1);

    push( @{ $self->{'DIE_ROLLS'} }, $roll );

    return $roll;
}

#############################################################################
#############################################################################
1
