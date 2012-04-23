#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
require Test::NoWarnings;

my @lines = (
    'one two three four five',
    'six seven eight nine ten',
    'eleven twelve thirteen fourteen fifteen',
    'sixteen seventeen eighteen nineteen twenty',
    'twenty-one twenty-two twenty-three twenty-four twenty-five',
    'twenty-six twenty-seven twenty-eight twenty-nine thirty',
);
sub is_selectable {
    $_[0] =~ /four/;
}

my $class = 'App::USelect::Selector';
use_ok $class;

throws_ok { $class->new }
    qr/Attribute \(_text|_is_selectable\) is required/;
throws_ok { $class->new(text => \@lines) }
    qr/Attribute \(_is_selectable\) is required/;
throws_ok { $class->new(text => \@lines, is_selectable => 1) }
    qr/Attribute \(_is_selectable\) does not pass the type constraint/;
throws_ok { $class->new(is_selectable => \&is_selectable) }
    qr/Attribute \(_text\) is required/;
throws_ok { $class->new(text => 1, is_selectable => \&is_selectable) }
    qr/Attribute \(_text\) does not pass the type constraint/;

my $s;
lives_ok {
    $s = $class->new(text => \@lines, is_selectable => \&is_selectable)
} 'Valid constructor lives';
isa_ok($s, $class);

no_leaks_ok {
    $class->new(text => \@lines, is_selectable => \&is_selectable)
};

is($s->line_count, 6, 'Line count as expected');
eq_or_diff([ map { $s->line($_)->text } (0 .. 5)], \@lines,
    'Line data as expected');
eq_or_diff([ map { $_->text } $s->selectable_lines ], [ @lines[0, 2, 4] ],
    'Selectable lines as expected');
is(scalar(grep { ! $_->can_select } $s->selectable_lines), 0,
    'All selectable lines have can_select');

is($s->next_selectable(0, -1), undef, 'Prev selectable to first is undef');
is($s->next_selectable(0, +1), 2,     'Next selectable as expected');
is($s->next_selectable(2, -1), 0,     'Prev selectable as expected');
is($s->next_selectable(2, +1), 4,     'Next selectable as expected');
is($s->next_selectable(4, -1), 2,     'Prev selectable as expected');
is($s->next_selectable(4, +1), undef, 'Next selectable to last is undef');

is(scalar($s->selected_lines), 0,
    'No lines are currently selected');

ok(!$s->line(0)->is_selected, 'Line 0 is not selected');
ok($s->line(0)->can_select, 'Line 0 can be selected');
lives_ok { $s->line(0)->select } 'Line 0 can be selected';
ok($s->line(0)->is_selected, 'Line is now selected');
lives_ok { $s->line(0)->deselect } 'Line 0 can be deselected';
ok(!$s->line(0)->is_selected, 'Line is now deselected');
lives_ok { $s->line(0)->toggle } 'Line 0 can be toggled';
ok($s->line(0)->is_selected, 'Line is now selected');
lives_ok { $s->line(0)->toggle } 'Line 0 can be toggled';
ok(!$s->line(0)->is_selected, 'Line is now deselected');

ok(!$s->line(1)->is_selected, 'Line 1 is not selected');
ok(!$s->line(1)->can_select, 'Line 1 cannot be selected');
throws_ok { $s->line(1)->select }
    qr/Can't locate object method "select"/,
    'Line 1 cannot be selected';
throws_ok { $s->line(1)->deselect }
    qr/Can't locate object method "deselect"/,
    'Line 1 cannot be deselected';
throws_ok { $s->line(1)->toggle }
    qr/Can't locate object method "toggle"/,
    'Line 1 cannot be toggled';

$s->line(0)->select;
eq_or_diff([ map { $_->text } $s->selected_lines], $lines[0],
    'Selected lines as expected');

$s->line(4)->select;
eq_or_diff([ map { $_->text } $s->selected_lines], [ @lines[0, 4] ],
    'Selected lines as expected');

Test::NoWarnings::had_no_warnings();
done_testing;
