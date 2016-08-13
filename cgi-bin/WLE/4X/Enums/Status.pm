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
        current player id


END

our @EXPORT = qw(

    state_text_from_enum
    phase_text_from_enum
    subphase_text_from_enum

    $ST_PREGAME
    $ST_RACESELECTION
    $ST_NORMAL
    $ST_FINISHED

    $PH_PREPARING

    $PH_ACTION
    $PH_COMBAT
    $PH_UPKEEP
    $PH_CLEANUP

    $SUB_MISSILE
    $SUB_BEAM
    $SUB_PLANETARY
    $SUB_VP_DRAW
    $SUB_NULL



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

our $SUB_MISSILE        = $i++;
our $SUB_BEAM           = $i++;
our $SUB_PLANETARY      = $i++;
our $SUB_VP_DRAW        = $i++;
our $SUB_NULL           = $i++;

$i = 0;

our $EV_FROM_LOG                = $i++;
our $EV_FROM_INTERFACE          = $i++;
our $EV_FROM_LOG_FOR_DISPLAY    = $i++;
our $EV_SUB_ACTION              = $i++;


#############################################################################

sub state_text_from_enum {
    my $state           = shift;

    my %values = (
        $ST_PREGAME         => 'Pre-Game Configuration',
        $ST_RACESELECTION   => 'Race Selection',
        $ST_NORMAL          => 'Round',
        $ST_FINISHED        => 'Finished',
    );

    if ( defined( $values{ $state } ) ) {
        return $values{ $state };
    }

    return 'Unknown';
}

#############################################################################

sub phase_text_from_enum {
    my $phase           = shift;

    my %values = (
        $PH_PREPARING   => 'Preparing',
        $PH_ACTION      => 'Action Phase',
        $PH_COMBAT      => 'Combat Phase',
        $PH_UPKEEP      => 'Upkeep Phase',
        $PH_CLEANUP     => 'Cleanup Phase',
    );

    if ( defined( $values{ $phase } ) ) {
        return $values{ $phase };
    }

    return 'Unknown';
}

#############################################################################

sub subphase_text_from_enum {
    my $subphase        = shift;

    my %values = (
        $SUB_MISSILE    => 'Missile Attacks',
        $SUB_BEAM       => 'Beam Attacks',
        $SUB_PLANETARY  => 'Planetary Bombardment',
        $SUB_VP_DRAW    => 'VP Draw',
        $SUB_NULL       => '',
    );

    if ( defined( $values{ $subphase } ) ) {
        return $values{ $subphase };
    }

    return 'Unknown';
}



#############################################################################
#############################################################################
1
