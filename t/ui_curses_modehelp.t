#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
require Test::NoWarnings;

my $role = 'App::USelect::UI::Curses::ModeHelp';

throws_ok {
    package Fail; use Mouse; with $role;
} qr/'$role' requires the method '_build__help_items' to be implemented/;

lives_ok {
    package Test; use Mouse; with $role;

    sub _build__help_items {
        return [
            {
                name => 'cmd1',
                keys => [qw( a 1 )],
                help => 'The first command',
            },
            {
                name => 'cmd2',
                keys => [qw( b 2 )],
                help => 'The second command',
            },
        ];
    }
} 'Role can be consumed with required methods defined';

my $tmh;
lives_ok { $tmh = Test->new } 'Consuming class ctor lives';

no_leaks_ok { $tmh = Test->new } 'No memory leaks';

is(1, (grep { /a,\s*1.*The first command/ } @{ $tmh->help_text }),
    'Found help for first command');
is(1, (grep { /b,\s*2.*The second command/ } @{ $tmh->help_text }),
    'Found help for second command');

{
    package Test2; use Mouse; with $role;
    has items => ( is => 'ro' );
    sub _build__help_items { shift->items };
}

$tmh = Test2->new( items => [ { name => 'cmd3', keys => [qw( c 3 )] } ]);
throws_ok { $tmh->help_text }
    qr/No help defined for cmd3/, 'Commands need help defined on them';

$tmh = Test2->new( items => [ { name => 'cmd3', help => 'The 3rd command' } ]);
throws_ok { $tmh->help_text }
    qr/No keys defined for cmd3/, 'Commands need keys defined on them';

$tmh = Test2->new( items => [ { name => 'cmd3', help => 'The 3rd command',
                                 keys => [] } ]);
throws_ok { $tmh->help_text }
    qr/No keys defined for cmd3/, 'Commands need keys defined on them';

Test::NoWarnings::had_no_warnings();
done_testing;
