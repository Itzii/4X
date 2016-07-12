package WLE::4X::Enums::Status;

use strict;
use warnings;
use Exporter;

our @ISA	= qw( Exporter );
our @EXPORT_OK = qw(
);

my $notes = <<'END';

V::WW::XX::YYY::ZZ

    V - state

        $ST_PREGAME - in pre_game mode - selecting options, adding players, etc ...
        $ST_RACESELECTION - race selection mode
        $ST_NORMAL - normal turns
        $ST_FINISHED - game is finished

    WW - round - will always be a two-digit number

    XX - phase

        $PH_PREPARING - in pre-game round or race selection ...

        in normal round ...

        $PH_ACTION
        $PH_COMBAT
        $PH_UPKEEP
        $PH_CLEANUP

    YYY -
        in pre-game indicates current player id

        in normal round
            action phase - player id

            combat phase - tile id

            upkeep phase - player id

END

our @EXPORT = qw(

    $ST_PREGAME
    $ST_RACESELECTION
    $ST_NORMAL
    $ST_FINISHED

    $PH_PREPARING

    $PH_ACTION
    $PH_COMBAT
    $PH_UPKEEP
    $PH_CLEANUP



    $EV_FROM_INTERFACE
    $EV_FROM_LOG
    $EV_FROM_LOG_FOR_DISPLAY
    $EV_SUB_ACTION

);

my $i = 0;

our $ST_PREGAME         = $i++;
our $ST_RACESELECTION   = $i++;
our $ST_NORMAL          = $i++;
our $ST_FINISHED        = $i++;

$i = 0;

our $PH_PREPARING       = $i++;
our $PH_ACTION          = $i++;
our $PH_COMBAT          = $i++;
our $PH_UPKEEP          = $i++;
our $PH_CLEANUP         = $i++;

$i = 0;

our $EV_FROM_LOG                = $i++;
our $EV_FROM_INTERFACE          = $i++;
our $EV_FROM_LOG_FOR_DISPLAY    = $i++;
our $EV_SUB_ACTION              = $i++;


#############################################################################
#############################################################################
1
