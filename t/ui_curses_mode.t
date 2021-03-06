#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
require Test::NoWarnings;

my $role = 'App::USelect::UI::Curses::Mode';

throws_ok {
    package FailMode; use Mouse; with $role;
} qr/'$role' requires the methods '_build__command_table', 'draw', and 'get_status_text' to be implemented/;

lives_ok {
    package TestMode; use Mouse; with $role;

    has last_command => (is => 'rw');

    sub draw { shift->last_command('draw') }
    sub get_status_text { shift->last_command('get_status_text') }
    sub _build__command_table {
        return {
            one => {
                keys => [qw( a 1 )],
                code => sub { shift->last_command('one') },
            },
            two => {
                keys => [qw( b 2 )],
                code => sub { shift->last_command('two') },
            },
        };
    }
} 'Role can be consumed with required methods defined';

my $tm;
lives_ok { $tm = TestMode->new } 'Consuming class ctor lives';

ok($tm->update('a'), 'Key a does something');
is($tm->last_command, 'one', 'Expected method called');

ok($tm->update('b'), 'Key b does something');
is($tm->last_command, 'two', 'Expected method called');

$tm->last_command(undef);
ok(! $tm->update('c'), 'Key c does something');
is($tm->last_command, undef, 'No method called');

ok($tm->update('1'), 'Key 1 does something');
is($tm->last_command, 'one', 'Expected method called');

ok($tm->update('2'), 'Key 2 does something');
is($tm->last_command, 'two', 'Expected method called');

no_leaks_ok { $tm = TestMode->new } 'No memory leaks';

throws_ok {
    package FailMode2; use Mouse; with $role;
    sub draw { }
    sub get_status_text { }
    sub _build__command_table {
        return {
            cmd0 => {
                keys => [qw( a b )],
                code => sub { },
            },
            cmd1 => {
                keys => [qw( b c )],
                code => sub { },
            },
        };
    }
    my $fm2 = FailMode2->new;
    $fm2->_key_dispatch_table;
} qr/Conflicting key b for cmd0 and cmd1/;

Test::NoWarnings::had_no_warnings();
done_testing;
