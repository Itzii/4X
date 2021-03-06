#!/usr/bin/perl

use strict;
use warnings;


STDOUT->autoflush( 1 );
STDERR->autoflush( 1 );

use lib ".";

use Data::Dumper;

use WLE::4X::Server::ASCII_Server;

my %args = _parse_commandline();

my $server = WLE::4X::Server::ASCII_Server->new(
    'resource_file'		=> "../resources/core.res",
    'state_files'		=> "../statefiles",
    'log_files'			=> "../statefiles",
);

foreach my $arg_tag ( keys( %args ) ) {
    if ( $args{ $arg_tag } =~ m{,}x ) {
        my @value_list = split( /,/, $args{ $arg_tag } );
        $args{ $arg_tag } = \@value_list;
    }
}


my %response = $server->do( %args );

unless ( $response{'success'} == 1 ) {
    print "\nCommand Failed: " . $response{'message'};
    exit();
}

print "\n" . $response{'message'};
print "\n\n" . $response{'data'};
print "\n";


#############################################################################

sub _parse_commandline {

	my @extraargs	= ();
	my %buffer 		= ();

	my $previousname = '';

	foreach my $arg ( @ARGV ) {

		if ( $arg =~ m{ ^ \+(.*) }xms ) {
			$arg = $1; # ~ s{ ^ - }{}xmsg;
			$previousname = $arg;
			$buffer{ $previousname } = 1;
		}
		elsif ( $previousname eq '' ) {
			push( @extraargs, $arg );
		}
		elsif ( ref( $buffer{ $previousname } ) eq 'ARRAY' ) {
			push( @{ $buffer{ $previousname } }, $arg );
		}
		elsif ( $buffer{ $previousname } eq '1' ) {
			$buffer{ $previousname } = $arg;
		}
		else {
			$buffer{ $previousname } = [ $buffer{ $previousname }, $arg ];
		}
	}

	$buffer{ '_args' } = \@extraargs;

	return %buffer;
}

#############################################################################
#############################################################################
