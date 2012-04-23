#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
require Test::NoWarnings;

use App::USelect::Selector;
use App::USelect::UI::Curses::Keys ':all';

my $class = 'App::USelect::UI::Curses::Mode::Select';
use_ok $class;

throws_ok { $class->new } qr/Attribute \(ui\) is required/;

my $s;
lives_ok { $s = $class->new(ui => mock_ui()) } 'Constructor lives';

is($s->_cursor, 0, 'Cursor is at line 0');
is($s->_first_line, 0, 'First line is 0');
is(($s->get_status_text)[0], '1 of 15, 0 selected', 'Status is correct');

lives_ok { $s->update('k') } 'Cursor up';
is($s->_cursor, 0, 'Cursor is at line 0');

lives_ok { $s->update('j') } 'Cursor down';
is($s->_cursor, 4, 'Cursor is at line 4');
is($s->_first_line, 0, 'First line is 0');
is(($s->get_status_text)[0], '2 of 15, 0 selected', 'Status is correct');

lives_ok { $s->update('G') } 'Cursor end';
is($s->_cursor, 120, 'Cursor is at line 120');
is($s->_first_line, 101, 'First line is 101');
is(($s->get_status_text)[0], '15 of 15, 0 selected', 'Status is correct');

lives_ok { $s->update('g') } 'Cursor home';
is($s->_cursor, 0, 'Cursor is at line 0');
is($s->_first_line, 0, 'First line is 0');
is(($s->get_status_text)[0], '1 of 15, 0 selected', 'Status is correct');

sub clamp { $_[0] < 0 ? 0 : $_[0] }

my @updown_points = ( 0, 4, 8, 17, 20, 23, 33, 39, 65, 69, 72, 97, 105, 108, 120 );

my @expected = ((map { [ $_,  clamp($_ - 23) ] } @updown_points), [ 120, 101 ]);
my @got = map { my $x = [ $s->_cursor, $s->_first_line ]; $s->update(down); $x } (1 .. 1+@updown_points);
eq_or_diff(\@got, \@expected, 'Cursor down works all the way');

@expected = map { [ $_, $_ < 101 ? $_ : 101 ] } reverse @updown_points;
@got = map { my $x = [ $s->_cursor, $s->_first_line ]; $s->update(up); $x } (1 .. @updown_points);
eq_or_diff(\@got, \@expected, 'Cursor up works all the way');

my @pgup_points = ( 0, 33, 65, 97, 120 );
@expected = ((map { [ $_,  clamp($_ - 23) ] } @pgup_points), [ 120, 101 ]);
@got = map { my $x = [ $s->_cursor, $s->_first_line ]; $s->update(pgdn); $x } (1 .. 1+@pgup_points);
eq_or_diff(\@got, \@expected, 'Cursor pgdn works all the way');

my @pgdn_points = ( 120, 72, 39, 8, 0 );
@expected = map { [ $_, $_ < 101 ? $_ : 101 ] } @pgdn_points;
@got = map { my $x = [ $s->_cursor, $s->_first_line ]; $s->update(pgup); $x } (1 .. @pgdn_points);
eq_or_diff(\@got, \@expected, 'Cursor pgup works all the way');

$s->update(' ');
$s->update(down);
$s->update(' ');
is(($s->get_status_text)[0], '2 of 15, 2 selected', 'Toggle selection works');
$s->update(up);
$s->update(' ');
is(($s->get_status_text)[0], '1 of 15, 1 selected', 'Toggle selection works');

$s->update('t');
is(($s->get_status_text)[0], '1 of 15, 14 selected', 'Toggle all works');

$s->update('a');
is(($s->get_status_text)[0], '1 of 15, 15 selected', 'Select all works');

$s->update('A');
is(($s->get_status_text)[0], '1 of 15, 0 selected', 'Deselect all works');

$s->update(' ');
$s->update(esc);
is(($s->get_status_text)[0], '1 of 15, 0 selected', 'Escape works');
is($s->ui->{exit}, 1, 'Escape works');

$s->update(enter);
is(($s->get_status_text)[0], '1 of 15, 1 selected', 'Enter selects one if none selected');
is($s->ui->{exit}, 2, 'Enter triggers exit');

$s->update(enter);
is(($s->get_status_text)[0], '1 of 15, 1 selected', 'Enter does nothing if some selected');
is($s->ui->{exit}, 3, 'Enter triggers exit');

$s->update('g');
$s->update('a');
$s->draw();
sub check_ui_line {
    my ($line_no, $color, $prefix) = @_;
    eq_or_diff($s->ui->{0}->{$line_no},
        [ $color, $prefix . ' ' . $s->ui->selector->line($line_no)->text ],
            "$color line drawn ok");
}
check_ui_line(0, cursor_selected => '#');
check_ui_line(1, unselectable => ' ');
check_ui_line(4, selectable_selected => '#');

$s->update('A');
$s->draw();
check_ui_line(0, cursor_unselected => '.');
check_ui_line(4, selectable_unselected => '.');

$s->update('h');
is($s->ui->{mode}, 'Help', 'Help mode activated ok');

Test::NoWarnings::had_no_warnings();
done_testing;

#------------------------------------------------------------------------------

{
    package App::USelect::UI::Curses;
    sub selector { shift->{selector} }
    sub new {
        my $class = shift;
        return bless { @_ }, $class;
    }
    sub _width  { 80 }
    sub _height { 25 }
    sub _exit_requested { shift->{exit}++ }
    sub print_line {
        my ($self, $x, $y, $color, $text) = @_;
        $self->{$x}->{$y} = [ $color, $text ];
    }
    sub push_mode { $_[0]->{mode} = $_[1] }
    sub move_cursor_to {}
}

sub mock_ui {
    return App::USelect::UI::Curses->new(
            selector => App::USelect::Selector->new(
                is_selectable => sub { $_[0] !~ /^(\d+:|$)/ },
                text => [ map {
                my $s = $_;
                chomp $s;
                $s =~ s/\s+line \d.*$//;
                $s; } <DATA> ],
                )
            );
}

__DATA__
bin/uselect                                                     line 0 / 1
20:    "help|h|?"          => sub { pod2usage(0) },
22:    "version|v"         => sub {

lib/App/USelect/Selector/Line.pm                                line 4 / 2
17:sub is_selected { 0 }
19:sub can_select {

lib/App/USelect/Selector.pm                                     line 8 / 3
42:sub _build__lines {
44:    my $build_line = sub {
53:sub selectable_lines {
55:    return $self->_grep(sub { $_->can_select });
58:sub selected_lines {
60:    return $self->_grep(sub { $_->is_selected });
63:sub next_selectable {

lib/App/USelect/UI/Curses/Color/Solarized.pm                    line 17 / 4
41:sub solarized_color {

lib/App/USelect/UI/Curses/Color.pm                              line 20 / 5
17:sub curses_color {

lib/App/USelect/UI/Curses/Keys.pm                               line 23 / 6
16:sub esc     { chr(27)   }
17:sub enter   { "\n"      }
18:sub up      { KEY_UP    }
19:sub down    { KEY_DOWN  }
20:sub pgup    { KEY_PPAGE }
21:sub pgdn    { KEY_NPAGE }
23:sub ctrl {
40:sub key_name {

lib/App/USelect/UI/Curses/Mode/Help.pm                          line 33 / 7
22:sub _build__command_table {
25:            code => sub { shift->ui->pop_mode },
32:sub draw {
43:sub get_status_text {

lib/App/USelect/UI/Curses/Mode/Select.pm                        line 39 / 8
26:    default => sub { shift->ui->selector },
35:sub _set_cursor {
41:sub _build__command_table {
46:            code => sub {
57:            code => sub {
67:            code => sub { shift->_move_cursor(-1) },
73:            code => sub { shift->_move_cursor(+1) },
79:            code => sub { shift->_page_up_down(-1) },
85:            code => sub { shift->_page_up_down(+1) },
91:            code => sub { shift->_cursor_to_end(-1) },
97:            code => sub { shift->_cursor_to_end(+1) },
103:            code => sub {
112:            code => sub { $_->select for shift->_selector->selectable_lines },
118:            code => sub { $_->deselect for shift->_selector->selectable_lines },
124:            code => sub { $_->toggle for shift->_selector->selectable_lines },
130:            code => sub {
140:sub draw {
173:sub _move_cursor {
181:sub _page_up_down {
204:sub _cursor_to_end {
218:sub _clamp {
224:sub _selection_index {
236:sub get_status_text {
250:sub _build__help_items {

lib/App/USelect/UI/Curses/Mode.pm                               line 65 / 9
36:sub _build__key_dispatch_table {
52:sub update {

lib/App/USelect/UI/Curses/ModeHelp.pm                           line 69 / 10
29:sub _build_help_text {

lib/App/USelect/UI/Curses.pm                                    line 72 / 11
39:    default => sub { [ shift->_new_mode('Select') ] },
42:sub _new_mode {
49:sub push_mode {
54:sub pop_mode {
59:sub _mode {
83:sub run {
99:sub _draw {
117:sub _color {
126:sub _pre_run {
140:sub _post_run {
147:sub _update {
157:sub _draw_status_line {
169:    substr($msg, $wid - length($rhs)) = $rhs;
170:    substr($msg, ($wid - length($mhs))/2, length($mhs)) = $mhs;
171:    substr($msg, 0, length($lhs)) = $lhs;
176:sub move_cursor_to {
181:sub print_line {
191:        $str = substr($str, 0, $w);
201:sub _pre_draw {
209:sub _post_draw {
214:sub _update_size {
223:sub _attach_console {
233:sub _detach_console {

lib/App/USelect.pm                                              line 97 / 12
16:sub run {
19:    my $select_sub = _make_select_sub($opt)
25:            is_selectable => $select_sub,
48:sub _make_select_sub {
68:    my $select_sub = eval('sub { $_ = shift; ' . $opt->{select_code} . '}'); ## no critic ProhibitStringyEval
74:    return $select_sub;

t/selector.t                                                    line 105 / 13
17:sub is_selectable {

t/ui_curses_mode.t                                              line 108 / 14
20:    sub draw { shift->last_command('draw') }
21:    sub get_status_text { shift->last_command('get_status_text') }
22:    sub _build__command_table {
26:                code => sub { shift->last_command('one') },
30:                code => sub { shift->last_command('two') },
59:    sub draw { }
60:    sub get_status_text { }
61:    sub _build__command_table {
65:                code => sub { },
69:                code => sub { },

t/ui_curses_mode_select.t                                       line 120 / 15
24:    sub selector { shift->{selector} }
25:    sub new {
31:sub mock_ui {
34:            is_selectable => sub { $_[0] =~ /four/ },
