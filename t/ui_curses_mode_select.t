#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Test::LeakTrace;
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

lives_ok { $s->update(pgdn) } 'Cursor page down';
is($s->_cursor, 33, 'Cursor is at line 33');
is($s->_first_line, 10, 'First line is 10');

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
}

sub mock_ui {
    return App::USelect::UI::Curses->new(
        selector => App::USelect::Selector->new(
            is_selectable => sub { $_[0] !~ /^(\d+:|$)/ },
            text => [ map { chomp ; $_ } <DATA> ],
        )
    );
}

__DATA__
bin/uselect                                                     line 0
20:    "help|h|?"          => sub { pod2usage(0) },
22:    "version|v"         => sub {

lib/App/USelect/Selector/Line.pm                                line 4
17:sub is_selected { 0 }
19:sub can_select {

lib/App/USelect/Selector.pm                                     line 8
42:sub _build__lines {
44:    my $build_line = sub {
53:sub selectable_lines {
55:    return $self->_grep(sub { $_->can_select });
58:sub selected_lines {
60:    return $self->_grep(sub { $_->is_selected });
63:sub next_selectable {

lib/App/USelect/UI/Curses/Color/Solarized.pm                    line 17
41:sub solarized_color {

lib/App/USelect/UI/Curses/Color.pm                              line 20
17:sub curses_color {

lib/App/USelect/UI/Curses/Keys.pm                               line 23
16:sub esc     { chr(27)   }
17:sub enter   { "\n"      }
18:sub up      { KEY_UP    }
19:sub down    { KEY_DOWN  }
20:sub pgup    { KEY_PPAGE }
21:sub pgdn    { KEY_NPAGE }
23:sub ctrl {
40:sub key_name {

lib/App/USelect/UI/Curses/Mode/Help.pm                          line 33
22:sub _build__command_table {
25:            code => sub { shift->ui->pop_mode },
32:sub draw {
43:sub get_status_text {

lib/App/USelect/UI/Curses/Mode/Select.pm
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

lib/App/USelect/UI/Curses/Mode.pm
36:sub _build__key_dispatch_table {
52:sub update {

lib/App/USelect/UI/Curses/ModeHelp.pm
29:sub _build_help_text {

lib/App/USelect/UI/Curses.pm
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

lib/App/USelect.pm
16:sub run {
19:    my $select_sub = _make_select_sub($opt)
25:            is_selectable => $select_sub,
48:sub _make_select_sub {
68:    my $select_sub = eval('sub { $_ = shift; ' . $opt->{select_code} . '}'); ## no critic ProhibitStringyEval
74:    return $select_sub;

t/selector.t
17:sub is_selectable {

t/ui_curses_mode.t
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

t/ui_curses_mode_select.t
24:    sub selector { shift->{selector} }
25:    sub new {
31:sub mock_ui {
34:            is_selectable => sub { $_[0] =~ /four/ },
