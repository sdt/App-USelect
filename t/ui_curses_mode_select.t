#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
use App::USelect::Selector;

my $class = 'App::USelect::UI::Curses::Mode::Select';
use_ok $class;

throws_ok { $class->new } qr/Attribute \(ui\) is required/;

my $s;
lives_ok { $s = $class->new(ui => mock_ui()) };

done_testing;

#------------------------------------------------------------------------------

{
    package App::USelect::UI::Curses;
    sub selector { shift->{selector} }
    sub new {
        my $class = shift;
        return bless { @_ }, $class;
    }
}

sub mock_ui {
    return App::USelect::UI::Curses->new(
        selector => App::USelect::Selector->new(
            is_selectable => sub { $_[0] =~ /four/ },
            text => [
                'one two three four five',
                'six seven eight nine ten',
                'eleven twelve thirteen fourteen fifteen',
                'sixteen seventeen eighteen nineteen twenty',
                'twenty-one twenty-two twenty-three twenty-four twenty-five',
                'twenty-six twenty-seven twenty-eight twenty-nine thirty',
            ],
        )
    );
}
