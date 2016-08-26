package WLE::Objects::Server;

use strict;
use warnings;

use Data::Dumper;
use Fcntl ':flock';
#use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
#use XML::Bare;

use WLE::Methods::Simple;

my $_option_notes = <<'END';


END

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

    $self->{'RAW_ACTIONS'} = {};
    $self->_init_raw_actions();

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

    $self->{'ENV'}->{'ACTING_PLAYER'} = undef;
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

sub add_raw_actions {
    my $self        = shift;
    my $r_actions   = shift;

    foreach my $sub_ref ( keys( %{ $r_actions } ) ) {
        $self->{'RAW_ACTIONS'}->{ $sub_ref } = $r_actions->{ $sub_ref };
    }

    return;
}

#############################################################################

sub run_raw_action_from_log {
    my $self        = shift;
    my $action      = shift;
    my $data        = shift;

    foreach my $method ( keys( %{ $self->{'RAW_ACTIONS'} } ) ) {
        if ( $self->{'RAW_ACTIONS'}->{ $method } eq $action ) {
            $method->( $self, $EV_FROM_LOG, $data );
            return 1;
        }
    }

    return 0;
}

#############################################################################

sub log_event {
    my $self            = shift;
    my $event_type      = shift;
    my $ref_to_method   = shift;
    my @args            = @_;

    $Data::Dumper::Indent = 0;

    if ( $event_type == $EV_FROM_INTERFACE ) {
        $self->_log_data( $self->{'RAW_ACTIONS'}->{ $ref_to_method } . ':' . Dumper( \@args ) );
    }
    elsif ( $event_type == $EV_SUB_ACTION ) {
        $self->_log_data( '  _' . $self->{'RAW_ACTIONS'}->{ $ref_to_method } . ':' . Dumper( \@args ) );
    }

    return;
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

        $self->{'SETTINGS'}->{'LONG_NAME'} = '';

        $self->{'SETTINGS'}->{'PLAYERS'} = {};

        $self->{'SETTINGS'}->{'WAITING_ON_PLAYER'} = -1;
    }

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
        my $owning_player = WLE::4X::Objects::Player->new( 'server' => $self, 'id' => 0, 'user_id' => $args{'user'} );;
        $owning_player->set_is_owner( 1 );

        $self->{'SETTINGS'}->{'PLAYERS'}->{ '0' } = $owning_player;
        $self->{'ENV'}->{'ACTING_PLAYER'} = $owning_player;
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

#    print STDERR "\nActing Player Type - Bare : " . $self->{'ENV'}->{'ACTING_PLAYER'};
#    print STDERR "\nActing Player Type: " . $self->acting_player();

    $response{'allowed'} = [ $self->acting_player()->adjusted_allowed_actions()->items() ];

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

        'pay_upkeep'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_UPKEEP, 'method' => \&action_pay_upkeep },
        'pull_influence'   => { 'flag_req_state' => $ST_NORMAL, 'flag_active_player' => 1, 'flag_req_phase' => $PH_UPKEEP, 'method' => \&action_pull_influence },


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

    my $acting_player = $self->player_of_user_id( $user_id );

    unless ( defined( $acting_player ) ) {
        $acting_player = WLE::4X::Objects::Player->new( 'server' => $self, 'user_id' => -1, 'id' => -1 );
        $acting_player->set_long_name( 'Anonymous Player' );
    }

    $self->{'ENV'}->{'ACTING_PLAYER'} = $acting_player;

    if ( defined( $action->{'flag_anytime'} ) ) {
        return '';
    }

    if ( defined( $action->{'flag_req_state'} ) ) {
        if ( $self->state() != $action->{'flag_req_state'} ) {
            return 'Invalid state for action.';
        }
    }

    if ( defined( $action->{'flag_owner_only'} ) && $self->acting_player()->is_owner() == 0 )  {
        return 'Action is allowed by game owner only.';
    }

    if ( defined( $action->{'flag_active_player'} ) ) {
        my $waiting_on = $self->waiting_on_player_id();

        if ( $waiting_on == -1 || ( $waiting_on > -1 && $waiting_on != $self->acting_player()->id() ) ) {
            return 'Action is not allowed by this player at this time.';
        }
    }

    if ( defined( $action->{'flag_req_phase'} ) ) {
        if ( $self->phase() != $action->{'flag_req_phase'} ) {
            return 'Wrong phase for action.';
        }
    }

    if ( $self->state() == $ST_NORMAL ) {

        unless ( defined( $action->{'flag_ignore_allowed'} ) ) {
            unless ( $self->acting_player()->adjusted_allowed_actions()->contains( $action_tag ) ) {
#                print STDERR "\nAllowed Actions: " . join( ',', $self->acting_player()->allowed_actions()->items() );
                return 'Action is not allowed by player at this time.';
            }
        }
    }

    return '';
}

#############################################################################

sub players {
    my $self        = shift;#!/usr/bin/env perl

    return $self->{'SETTINGS'}->{'PLAYERS'};
}

#############################################################################

sub acting_player {
    my $self        = shift;

    return $self->{'ENV'}->{'ACTING_PLAYER'};
}

#############################################################################

sub player_of_user_id {
    my $self        = shift;
    my $user_id     = shift;

    foreach my $player ( values( %{ $self->players() } ) ) {
        if ( $player->user_id() eq $user_id ) {
            return $player;
        }
    }

    return undef;
}

#############################################################################

sub player_of_id {
    my $self        = shift;
    my $player_id   = shift;

    return $self->players()->{ $player_id };
}

#############################################################################

sub player_count {
    my $self        = shift;

    return scalar( keys( %{ $self->players() } ) );
}

#############################################################################

sub player_list {
    my $self        = shift;

    my @players = sort { $a->id() <=> $b->id() } values( %{ $self->players() } );

    return @players;
}

#############################################################################

sub add_player {
    my $self        = shift;
    my $player      = shift;

    my $id = 0;
    while ( defined( $self->players()->{ $id } ) ) {
        $id++;
    }

    $self->players()->{ $id } = $player;
    $player->set_id( $id );

    return;
}

#############################################################################

sub remove_player {
    my $self        = shift;
    my $user_id     = shift;

    foreach my $player ( $self->player_list() ) {
        if ( $player->user_id() eq $user_id ) {
            delete( $self->players()->{ $player->id() } );
            last;
        }
    }

    return;
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

sub user_id_of_player_id {
    my $self        = shift;
    my $player_id   = shift;

    foreach my $player ( values( %{ $self->players() } ) ) {
        if ( $player->id() == $player_id ) {
            return $player->user_id();
        }
    }

    return -1;
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
        $self->acting_player()->id(),
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

    return $self->{'ROUND_TECH_COUNT'}
}

#############################################################################

sub set_tech_draw_count {
    my $self        = shift;
    my $value       = shift;

    $self->{'ROUND_TECH_COUNT'} = $value;

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
