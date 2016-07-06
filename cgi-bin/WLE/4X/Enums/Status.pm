package WLE::4X::Enums::Status;

use strict;
use warnings;
use Exporter;

our @ISA	= qw( Exporter );
our @EXPORT_OK = qw(
);

# WW::XX::YYY::ZZ

our @EXPORT = qw(

# WW - round - will always be a two-digit number - 00 indicates pre-game round, 99 indicates the game is finished

# XX - phase
#   in pre-game round ...

    $PH_PREPARING

#   in normal round ...

    $PH_ACTION
    $PH_COMBAT
    $PH_UPKEEP
    $PH_CLEANUP

# YYY -
#      in pre-game indicates current player id
#
#      in normal round
#           action phase - player id
#
#           combat phase - tile id
#
#           upkeep phase - player id




);

my $i = 0;

our $PH_PREPARING       = $i++;
our $PH_ACTION          = $i++;
our $PH_COMBAT          = $i++;
our $PH_UPKEEP          = $i++;
our $PH_CLEANUP         = $i++;


#############################################################################
#############################################################################
1
