#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::USelect' ) || print "Bail out!\n";
}

diag( "Testing App::USelect $App::USelect::VERSION, Perl $], $^X" );
