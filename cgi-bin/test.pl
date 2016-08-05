#!/usr/bin/perl

use strict;
use warnings;


STDOUT->autoflush( 1 );
STDERR->autoflush( 1 );

use lib ".";

use Test::More;
use Data::Dumper;
use Time::HiRes;
use Module::Load;

use WLE::4X::Objects::Server;


# Do not use credentials for a database with working data!!!!!
# This test script will truncate all tables when it's finished
# i.e. It will DESTROY ALL DATA when it is finished!!!

my %_required_modules = (

	'Data::Dumper'				=> [ 500, sub { } ],
#	'Storable'					=> [ 500, sub { } ],


);

my @_test_methods = (

	[ 'WLE::Methods::Simple'							, \&test_Methods_Simple ],

	[ 'WLE::4X::Objects::Element'						, \&test_Object_Element ],
	[ 'WLE::4X::Objects::ShipComponent'					, \&test_Object_ShipComponent ],
	[ 'WLE::4X::Objects::Technology'					, \&test_Object_Technology ],
	[ 'WLE::4X::Objects::Discovery'						, \&test_Object_Discovery ],
	[ 'WLE::4X::Objects::Development'					, \&test_Object_Development ],
	[ 'WLE::4X::Objects::Tile'							, \&test_Object_Tile ],
	[ 'WLE::4X::Objects::Board'							, \&test_Object_Board ],


	[ 'WLE::4X::Objects::Server'						, \&test_Object_Server ],


);

my %_args 				= ();

my %_creation_times 	= ();
my $_creation_index 	= 1;
my $_flag_load_test 	= 0;

my %_section_times 		= ();
my $_section_index 		= 1;
my $_section_current 	= '';

my $_begin_time			= Time::HiRes::time();

test();

my $_end_time = Time::HiRes::time() - $_begin_time;

print "\n Total Time: " . sprintf( "%0.3f", $_end_time ) . " seconds";


#############################################################################
#############################################################################
#############################################################################
#############################################################################

sub test_Methods_Simple {

	my @test = ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 );

	WLE::Methods::Simple::shuffle_in_place( \@test );

	show( join( ',', @test ) );

	my $value = 0b01110000;
	my $shifted_value = 0b11100000;
	$value = WLE::Methods::Simple::rotate_bits_left( $value );

	ok( $value == $shifted_value, 'left shift is correct' );

	$value = 0b11100000;
	$shifted_value = 0b11000001;
	$value = WLE::Methods::Simple::rotate_bits_left( $value );

	ok( $value == $shifted_value, 'left shift with moved bit is correct' );
#	show( sprintf( '%0b', $value ) );

	$value = 0b00001110;
	$shifted_value = 0b00000111;
	$value = WLE::Methods::Simple::rotate_bits_right( $value );

	ok( $value == $shifted_value, 'right shift is correct' );

	$value = 0b00000111;
	$shifted_value = 0b10000011;
	$value = WLE::Methods::Simple::rotate_bits_right( $value );

	ok( $value == $shifted_value, 'right shift with moved bit is correct' );

	$value = 0b00111000;
	$shifted_value = 0b00110001;
	$value = WLE::Methods::Simple::rotate_bits_left( $value, 6 );

	ok( $value == $shifted_value, 'left shift of short byte is correct' );

	$value = 0b00000111;
	$shifted_value = 0b00100011;
	$value = WLE::Methods::Simple::rotate_bits_right( $value, 6 );

	ok( $value == $shifted_value, 'right shift of short byte is correct' );

	return;
}


#############################################################################

sub test_Object_Element {

	my $element = WLE::4X::Objects::Element->new( 'server' => '1' );

	ok( defined( $element ) && ref( $element ) eq 'WLE::4X::Objects::Element', 'element object created');

	return;
}

#############################################################################

sub test_Object_ShipComponent {

	my $component = WLE::4X::Objects::ShipComponent->new( 'server' => '1' );

	ok( defined( $component ) && ref( $component ) eq 'WLE::4X::Objects::ShipComponent', 'component object created');

	return;
}

#############################################################################

sub test_Object_Technology {

	my $technology = WLE::4X::Objects::Technology->new( 'server' => '1' );

	ok( defined( $technology ) && ref( $technology ) eq 'WLE::4X::Objects::Technology', 'technology object created');

	return;
}

#############################################################################

sub test_Object_Discovery {

	my $discovery = WLE::4X::Objects::Discovery->new( 'server' => '1' );

	ok( defined( $discovery ) && ref( $discovery ) eq 'WLE::4X::Objects::Discovery', 'discovery object created');

	return;
}

#############################################################################

sub test_Object_Development {

	my $development = WLE::4X::Objects::Development->new( 'server' => '1' );

	ok( defined( $development ) && ref( $development ) eq 'WLE::4X::Objects::Development', 'development object created');

	return;
}

#############################################################################

sub test_Object_Tile {

	my $tile = WLE::4X::Objects::Tile->new( 'server' => '1' );

	ok( defined( $tile ) && ref( $tile ) eq 'WLE::4X::Objects::Tile', 'tile object created');

	return;
}

#############################################################################

sub test_Object_Board {

	my $board = WLE::4X::Objects::Board->new( 'server' => '1' );

	ok( defined( $board ) && ref( $board ) eq 'WLE::4X::Objects::Board', 'board object created');

	return;
}



#############################################################################

sub test_Object_Server {

	my $log_id = 'testid123';

	unlink( '../statefiles/' . $log_id . '.log' );
	unlink( '../statefiles/' . $log_id . '.state' );

	my $server = WLE::4X::Objects::Server->new(
		'resource_file'		=> "../resources/official.res",
		'state_files'		=> "../statefiles",
		'log_files'			=> "../statefiles",
	);

	my $owner_id = 55;
	my @user_ids = ( $owner_id, 200, 300 );

	ok( defined( $server ) && ref( $server ) eq 'WLE::4X::Objects::Server', 'server object created');

	ok( $server->last_error() eq '', 'no errors found' );

	my %response;

	%response = $server->do(
		'action' 		=> 'create_game',
	);

	ok( $response{'success'} == 0, 'action_create_game failed with no arguments' );

	%response = $server->do(
		'action' 		=> 'create_game',
		'log_id'		=> 'test  id',
	);

	ok( $response{'success'} == 0, 'action_create_game failed with invalid log_id' );

	%response = $server->do(
		'action' 		=> 'create_game',
		'log_id'		=> $log_id,
	);

	ok( $response{'success'} == 0, 'action_create_game failed with missing owner_id' );

	%response = $server->do(
		'action' 		=> 'create_game',
		'user'			=> 'kdkd',
		'log_id'		=> 'testid',
	);

	ok( $response{'success'} == 0, 'action_create_game failed with invalid owner_id' );

	%response = $server->do(
		'action' 		=> 'create_game',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'r_source_tags' => [],
		'r_option_tags' => [],
	);

	ok( $response{'success'} == 0, 'action_create_game failed with missing source tag' );

	%response = $server->do(
		'action' 		=> 'create_game',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'r_source_tags' => [ 'src_base' ],
		'r_option_tags' => [],
	);

	ok( $response{'success'} == 1, 'create_game successful' );
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

#	return;

	%response = $server->do(
		'action' 		=> 'add_source',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'source_tag'	=> 'src_test',
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

#	return;

	%response = $server->do(
		'action' 		=> 'add_option',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'option_tag'	=> 'option_test',
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	%response = $server->do(
		'action' 		=> 'add_player',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'user_id'		=> $user_ids[ 1 ],
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

#	return;

	%response = $server->do(
		'action' 		=> 'add_player',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
		'user_id'		=> $user_ids[ 2 ],
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

#	return;

	%response = $server->do(
		'action' 		=> 'begin',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);
	ok( $response{'success'} == 1, 'action_begin successful' );
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	%response = $server->do(
		'action'		=> 'status',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);
	ok( $response{'success'} == 1, 'get status completed correctly' );
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}
	show( $response{'data'} );

#	return;

	%response = $server->do(
		'action'		=> 'select_race',
		'user'			=> 999,
		'log_id'		=> $log_id,
		'race_tag'		=> 'race_terran5',
		'location_x'	=> 0,
		'location_y'	=> -2,
	);
	ok( $response{'success'} == 0, 'select_race failed for invalid user' );

	%response = $server->do(
		'action'		=> 'status',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	my @status = split( /:/, $response{'data'} );
	my $waiting_for = $status[ 3 ];

#	show( $response{'data'} );

	%response = $server->do(
		'action'		=> 'select_race',
		'user'			=> $waiting_for,
		'log_id'		=> $log_id,
		'race_tag'		=> 'race_human5',
		'location_x'	=> 0,
		'location_y'	=> -2,
	);

	ok( $response{'success'} == 1, 'select_race successful' );
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	%response = $server->do(
		'action'		=> 'status',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	@status = split( /:/, $response{'data'} );
	$waiting_for = $status[ 3 ];


	%response = $server->do(
		'action'		=> 'select_race',
		'user'			=> $waiting_for,
		'log_id'		=> $log_id,
		'race_tag'		=> 'race_human2',
		'location_x'	=> 2,
		'location_y'	=> 0,
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	%response = $server->do(
		'action'		=> 'status',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);

	@status = split( /:/, $response{'data'} );
	$waiting_for = $status[ 3 ];
	show( $server->status() );


	%response = $server->do(
		'action'		=> 'select_race',
		'user'			=> $waiting_for,
		'log_id'		=> $log_id,
		'race_tag'		=> 'race_human1',
		'location_x'	=> -2,
		'location_y'	=> 2,
	);
	unless( $response{'success'} == 1 ) {
		show( $response{'message'} );
	}

	%response = $server->do(
		'action'		=> 'status',
		'user'			=> $owner_id,
		'log_id'		=> $log_id,
	);

	@status = split( /:/, $response{'data'} );
	$waiting_for = $status[ 3 ];
	show( $server->status() );


	%response = $server->do(
		'action'		=> 'action_pass',
		'user'			=> '3',
		'log_id'		=> $log_id,
	);

	ok( $response{'success'} == 0, 'action_pass failed' );



	%response = $server->do(
		'action'		=> 'action_pass',
		'user'			=> $waiting_for,
		'log_id'		=> $log_id,
	);

	ok( $response{'success'} == 1, 'action_pass succeeded' );
	show( $response{'message'} );


	return;
}



#############################################################################
#############################################################################

#############################################################################

sub test {

	my %units_to_test = ();
	my %modules_to_test = ();
	my $flag_test_all = 1;

	foreach my $arg ( @ARGV ) {
		$_args{ $arg } = 1;

		if ( $arg =~ m{ ^ PSG:: }xs ) {
			$units_to_test{ $arg } = 1;
			$flag_test_all = 0;
		}
		elsif ( defined( $_required_modules{ $arg } ) ) {
			$modules_to_test{ $arg } = 1;
			$flag_test_all = 0;
		}
	}


	if ( defined( $_args{'loadtest'} ) ) {
		$_flag_load_test = 1;
	}

	my $section_index = 1;
	my %section_times = ();

	foreach my $module_name ( sort( keys( %_required_modules ) ) ) {

		if ( $modules_to_test{ $module_name } || $flag_test_all ) {

			no strict 'refs';

			eval "require $module_name";
			my $version = ${ $module_name . '::VERSION' };
			unless ( defined( $version ) ) {
				$version = 'unknown';
			}
			print "\n" . sprintf( "%-32s", $module_name ) . sprintf( ' :  %8s', $version );

			my $count = $_required_modules{ $module_name }->[ 0 ];
			my $method = $_required_modules{ $module_name }->[ 1 ];

			my $begin = Time::HiRes::time();

			for ( 0 .. $count ) {
				$method->();
			}
			my $end = Time::HiRes::time() - $begin;
			print sprintf( '   %0.5f', $end );
		}

	}

	unless ( defined( $_args{ 'libraries_only' } ) ) {

		foreach my $section ( @_test_methods ) {

			my $module_name = $section->[ 0 ];

			eval "require $module_name";
		}

		print "\n";

		foreach my $section ( @_test_methods ) {

			my $module_name = $section->[ 0 ];
			my $method		= $section->[ 1 ];

			if ( defined( $units_to_test{ $module_name } ) || $flag_test_all ) {

				print "\nTesting " . $module_name . " ... \n";

				my $key = sprintf( "%03i_", $section_index ) . $module_name;

				$section_times{ $key } = Time::HiRes::time();

				$method->();

				$section_times{ $key } = Time::HiRes::time() - $section_times{ $key };

				$section_index++;
			}
		}
	}

	print "\nFinished.\n";
	done_testing();

}

#############################################################################

sub fake {
	my $message		= shift;
	print " ... " . $message . "\n";

	return;
}

#############################################################################

sub show {
	my $message		= shift;

	print "\n+++ $message +++\n";

	return;
}

#############################################################################

sub add_time_test {
	my $description		= shift;
	my $call_back		= shift;
	my $count			= shift;
	my @args			= @_;

	unless ( $_flag_load_test ) {
		return;
	}

	my $start = Time::HiRes::time();

	foreach ( 1 .. $count ) {
		$call_back->( @args );
	}

	my $elapsed = Time::HiRes::time() - $start;

	my $key = sprintf( '%03i_%s', $_creation_index++, $_section_current . '::' . $description );

	$_creation_times{ $key } = { 'elapsed' => $elapsed, 'count' => $count, 'average' => $elapsed / $count };

	return;
}

#############################################################################

sub show_load_test_results {

	my $elapsed = time - $_begin_time;

	print "\n--- Total Time Elapsed : " . sprintf( '%0.2f', $elapsed ) . " ----------------------------------------";

	print "\n--- Section Time Test Results ---------------------------------------------";

	foreach my $key ( sort( keys( %_section_times ) ) ) {
		print sprintf( "\n%-60s : %02.5f", $key, $_section_times{ $key } );
	}

	print "\n--- Action Time Test Results ----------------------------------------------";

	foreach my $key ( sort( keys( %_creation_times ) ) ) {

		my $message = '';

		if ( $_creation_times{ $key }->{'elapsed'} == 0 ) {
			$message = '--';
		}
		elsif ( $_creation_times{ $key }->{'elapsed'} > 5 ) {
			$message = 'high';
		}

		print sprintf(
			"\n%-60s : %7i  %0.2f  %0.5f  %s",
			$key,
			$_creation_times{ $key }->{'count'},
			$_creation_times{ $key }->{'elapsed'},
			$_creation_times{ $key }->{'average'},
			$message,
		);
	}

	return;
}
