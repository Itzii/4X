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

    $RES_MONEY
    $RES_MINERALS
    $RES_SCIENCE
    $RES_INFLUENCE
    $RES_COUNT
    $RES_WILD
    $RES_UNKNOWN


);

my $i = 0;

our $RES_MONEY          = $i++;
our $RES_MINERALS       = $i++;
our $RES_SCIENCE        = $i++;
our $RES_INFLUENCE      = $i++;
our $RES_COUNT          = $i++;
our $RES_WILD           = $i++;
our $RES_UNKNOWN        = $i++;

#############################################################################

sub text_from_resource_enum {
    my $enum        = shift;

    my %values = (
        $RES_MONEY      => 'MONEY',
        $RES_MINERALS   => 'MINERALS',
        $RES_SCIENCE    => 'SCIENCE',
        $RES_INFLUENCE  => 'INFLUENCE',
        $RES_WILD       => 'WILD',
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

    if ( text_from_resouce_enum( $RES_WILD ) eq uc( $text ) ) {
        return $RES_WILD;
    }

    return $RES_UNKNOWN;
}

#############################################################################
#############################################################################
1
