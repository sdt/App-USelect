#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::PiSelect' ) || print "Bail out!\n";
}

diag( "Testing App::PiSelect $App::PiSelect::VERSION, Perl $], $^X" );
