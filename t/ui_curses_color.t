#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
require Test::NoWarnings;

use App::USelect::UI::Curses::Color qw( get_color );

use Curses qw(
    A_BOLD A_UNDERLINE A_DIM
    COLOR_BLACK COLOR_RED COLOR_BLUE
);

sub parse_color { goto &App::USelect::UI::Curses::Color::_parse_color };

my @good_cases = (
    [ 'red,blue,bold,underline',
           [ COLOR_RED, COLOR_BLUE, A_BOLD | A_UNDERLINE ] ],
    [ 'bold,red,blue,underline',
           [ COLOR_RED, COLOR_BLUE, A_BOLD | A_UNDERLINE ] ],
    [ 'bold,blue,underline',    [ COLOR_BLUE, -1, A_BOLD | A_UNDERLINE ] ],
    [ 'bold,underline',         [ -1, -1, A_BOLD | A_UNDERLINE ] ],
    [ 'bold',                   [ -1, -1, A_BOLD ] ],
    [ 'default,red',            [ -1, COLOR_RED, 0 ] ],
    [ 'base02',                 [ COLOR_BLACK, -1, 0 ] ],
    [ 'base03',                 [ COLOR_BLACK, -1, A_BOLD ] ],
    [ 'base03,base02',          [ COLOR_BLACK, COLOR_BLACK, A_BOLD ] ],
    [ '',                       [ -1, -1, 0 ] ],
    [ ' red , blue, bold ,underline , dim',
           [ COLOR_RED, COLOR_BLUE, A_BOLD | A_UNDERLINE | A_DIM ] ],
);
for (@good_cases) {
    my ($color_string, $expected) = @$_;

    eq_or_diff([ parse_color($color_string) ], $expected,
        "\"$color_string\" successfully parses correctly");

    my $color = get_color($color_string);
    isnt($color, 0, "\"$color_string\" makes a color");
    is($color, get_color($color_string), "... both times");
}

my @bad_cases = (
    [ 'red,blue,green', qr/Too many colors/ ],
    [ 'bloo,red',       qr/Unknown "bloo"/  ],
    [ 'red,orange',     qr/"orange" cannot be used as a background color/ ],
);
for (@bad_cases) {
    my ($color_string, $error_msg) = @$_;

    throws_ok { parse_color($color_string) } $error_msg,
        "\"$color_string\" fails to parse as expected";
}


Test::NoWarnings::had_no_warnings();
done_testing();
