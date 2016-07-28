package WLE::4X::Enums::Basic;

use strict;
use warnings;
use Exporter;

our @ISA	= qw( Exporter );
our @EXPORT_OK = qw(
);

our @EXPORT = qw(

    text_from_resource_enum
    enum_from_resource_text

    text_from_tech_enum
    enum_from_tech_text

    text_from_vp_enum
    enum_from_vp_text

    text_from_action_enum
    enum_from_action_text

    $RES_MONEY
    $RES_MINERALS
    $RES_SCIENCE
    $RES_INFLUENCE
    $RES_COUNT
    $RES_WILD
    $RES_SCIENCE_MONEY
    $RES_UNKNOWN

    $TECH_MILITARY
    $TECH_GRID
    $TECH_NANO
    $TECH_WILD
    $TECH_UNKNOWN

    $VP_BATTLE
    $VP_AMBASSADOR
    $VP_ANY
    $VP_COUNT
    $VP_UNKNOWN

    $ACT_EXPLORE
    $ACT_INFLUENCE
    $ACT_INFLUENCE_COLONY
    $ACT_RESEARCH
    $ACT_UPGRADE
    $ACT_BUILD
    $ACT_MOVE
    $ACT_PASS
    $ACT_COUNT
    $ACT_UNKNOWN

);

my $i = 0;

our $RES_MONEY          = $i++;
our $RES_MINERALS       = $i++;
our $RES_SCIENCE        = $i++;
our $RES_INFLUENCE      = $i++;
our $RES_COUNT          = $i++;
our $RES_WILD           = $i++;
our $RES_SCIENCE_MONEY  = $i++;
our $RES_UNKNOWN        = $i++;

$i = 0;

our $TECH_MILITARY      = $i++;
our $TECH_GRID          = $i++;
our $TECH_NANO          = $i++;
our $TECH_WILD          = $i++;
our $TECH_UNKNOWN       = $i++;

$i = 0;

our $VP_BATTLE          = $i++;
our $VP_AMBASSADOR      = $i++;
our $VP_ANY             = $i++;
our $VP_COUNT           = $i++;
our $VP_UNKNOWN         = $i++;

$i = 0;

our $ACT_EXPLORE        = $i++;
our $ACT_INFLUENCE      = $i++;
our $ACT_INFLUENCE_COLONY = $i++;
our $ACT_RESEARCH       = $i++;
our $ACT_UPGRADE        = $i++;
our $ACT_BUILD          = $i++;
our $ACT_MOVE           = $i++;
our $ACT_PASS           = $i++;
our $ACT_COUNT          = $i++;
our $ACT_UNKNOWN        = $i++;


#############################################################################

sub text_from_resource_enum {
    my $enum        = shift;

    my %values = (
        $RES_MONEY          => 'MONEY',
        $RES_MINERALS       => 'MINERALS',
        $RES_SCIENCE        => 'SCIENCE',
        $RES_INFLUENCE      => 'INFLUENCE',
        $RES_WILD           => 'WILD',
        $RES_SCIENCE_MONEY  => 'SCIENCE_MONEY',
    );

    if ( defined( $values{ $enum } ) ) {
        return $values{ $enum },
    }

    return 'UNKNOWN';
}

#############################################################################

sub enum_from_resource_text {
    my $text        = shift;

    foreach my $enum ( 0 .. $RES_COUNT - 1 ) {
        if ( text_from_resource_enum( $enum ) eq uc( $text ) ) {
            return $enum;
        }
    }

    if ( text_from_resource_enum( $RES_WILD ) eq uc( $text ) ) {
        return $RES_WILD;
    }

    return $RES_UNKNOWN;
}

#############################################################################

sub text_from_tech_enum {
    my $tech_type       = shift;

    my %values = (
        $TECH_MILITARY  => 'MILITARY',
        $TECH_GRID      => 'GRID',
        $TECH_NANO      => 'NANO',
        $TECH_WILD      => 'WILD',
    );

    if ( defined( $values{ $tech_type } ) ) {
        return $values{ $tech_type },
    }

    return 'UNKNOWN';
}

#############################################################################

sub enum_from_tech_text {
    my $text        = shift;

    foreach my $enum ( 0 .. $RES_COUNT - 1 ) {
        if ( text_from_tech_enum( $enum ) eq uc( $text ) ) {
            return $enum;
        }
    }

    return $TECH_UNKNOWN;
}

#############################################################################

sub text_from_vp_enum {
    my $vp_type         = shift;

    my %values = (
        $VP_BATTLE          => 'BATTLE',
        $VP_AMBASSADOR      => 'AMBASSADOR',
        $VP_ANY             => 'ANY',
    );

    if ( defined( $values{ $vp_type } ) ) {
        return $values{ $vp_type };
    }

    return 'UNKNOWN';
}

#############################################################################

sub enum_from_vp_text {
    my $text        = shift;

    foreach my $enum ( 0 .. $VP_COUNT - 1 ) {
        if ( text_from_vp_enum( $enum ) eq uc( $text ) ) {
            return $enum;
        }
    }

    return $VP_UNKNOWN;
}

#############################################################################

sub text_from_action_enum {
    my $act_type         = shift;

    my %values = (
        $ACT_EXPLORE        => 'EXPLORE',
        $ACT_INFLUENCE      => 'INFLUENCE',
        $ACT_INFLUENCE_COLONY => 'INFLUCE_COL',
        $ACT_RESEARCH       => 'RESEARCH',
        $ACT_UPGRADE        => 'UPGRADE',
        $ACT_BUILD          => 'BUILD',
        $ACT_MOVE           => 'MOVE',
        $ACT_PASS           => 'PASS',
    );

    if ( defined( $values{ $act_type } ) ) {
        return $values{ $act_type };
    }

    return 'UNKNOWN';
}

#############################################################################

sub enum_from_action_text {
    my $text        = shift;

    foreach my $enum ( 0 .. $ACT_COUNT - 1 ) {
        if ( text_from_action_enum( $enum ) eq uc( $text ) ) {
            return $enum;
        }
    }

    return $ACT_UNKNOWN;
}

#############################################################################
#############################################################################
1
