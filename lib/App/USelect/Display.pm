package App::USelect::Display;
use Moose;
#use namespace::autoclean;

use Modern::Perl;
use Curses;
use Hash::Util  qw/ lock_hash /;
use List::Util  qw/ min max /;

use App::USelect::Selector;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

has selector => (
    is       => 'ro',
    isa      => 'App::USelect::Selector',
);

has window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
);

has _first_line => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
    default  => 0,
);

has _cursor => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
    default  => 0,
);

has _mode => (
    is       => 'rw',
    isa      => 'Str',
    init_arg => undef,
    default  => 'select',
);

has _width => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

has _height => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

has _exit_requested => (
    is       => 'rw',
    isa      => 'Bool',
    init_arg => undef,
    default  => 0,
);

my $esc     = chr(27);
my $newline = "\n";

my %key_dispatch_table = (

    select => {
        $newline            => \&_action_quit,
        $esc                => \&_action_abort,
        q                   => \&_action_abort,
        Curses::KEY_RESIZE  => \&_action_resize,
        k                   => \&_action_cursor_up,
        Curses::KEY_UP      => \&_action_cursor_up,
        j                   => \&_action_cursor_down,
        Curses::KEY_DOWN    => \&_action_cursor_down,
        g                   => \&_action_cursor_top,
        G                   => \&_action_cursor_bottom,
        ' '                 => \&_action_toggle_selection,
        a                   => \&_action_select_all,
        '*'                 => \&_action_select_all,
        'A'                 => \&_action_deselect_all,
        '-'                 => \&_action_deselect_all,
        t                   => \&_action_toggle_all,
        h                   => \&_action_enter_help_mode,
        '?'                 => \&_action_enter_help_mode,
    },

    help => {
        $esc                => \&_action_leave_help_mode,
        q                   => \&_action_leave_help_mode,
        ' '                 => \&_action_leave_help_mode,
    },
);
lock_hash(%key_dispatch_table);

my %draw_dispatch_table = (
    select  => \&_draw_select_mode,
    help    => \&_draw_help_mode,
);
lock_hash(%key_dispatch_table);

sub BUILD {
    my ($self, $args) = @_;

    start_color;
    init_pair(1, COLOR_YELLOW, COLOR_BLACK);
    init_pair(2, COLOR_WHITE,  COLOR_BLUE);
    init_pair(3, COLOR_WHITE,  COLOR_RED);
    init_pair(4, COLOR_GREEN,  COLOR_BLACK);
    noecho;
    cbreak;
    $self->window->keypad(1);
    curs_set(0);
    $self->_redraw;
}

sub DEMOLISH {
    endwin;
}

sub print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my ($h, $w); $self->window->getmaxyx($h, $w);
    my $old_attr = $self->window->attron($attr);
    $self->window->addstr($y, $x, $str . (' ' x ($w - length($str))));
    $self->window->attrset($old_attr);
}

sub run {
    my ($self) = shift;

    while (not $self->_exit_requested) {
        $self->_update;
    }
}

sub _update {
    my ($self) = @_;

    my $key = $self->window->getch;
    my $handler = $key_dispatch_table{$self->_mode}->{$key};

    if ($handler) {
        $self->$handler();
        $self->_redraw;
    }
}

sub _update_size {
    my ($self) = @_;

    my ($h, $w);
    $self->window->getmaxyx($h, $w);
    $self->_width($w);
    $self->_height($h);
}

sub _redraw {
    my ($self) = @_;

    $self->_update_size;
    $self->window->erase;

    $draw_dispatch_table{$self->_mode}->($self);

    $self->_draw_status_line;
    $self->window->refresh;
}

sub _draw_select_mode {
    my ($self) = @_;

    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->_height - 1) {
        $self->_first_line($self->_cursor - $self->_height + 2);
    }

    my $slr = $self->selector;
    my $line_count = min($self->_height - 1,
                         $slr->line_count - $self->_first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $self->_first_line;
        my $line = $slr->line($y + $self->_first_line);
        my $attr = ($line_no == $self->_cursor) ? COLOR_PAIR(3)
                 : $line->can('select') ? COLOR_PAIR(1) : 0;
        my $prefix = $line->can('select') ?
                     $line->is_selected ?
                     '# ' : '. ' : '  ';
        $self->print_line(0, $y, $attr, $prefix . $line->text);
    }
}

sub _draw_help_mode {
    my ($self) = @_;

    my $help_text = <<"END_HELP";

    ENTER           exit with current selection

    ESC, q          abort (with no selection)

    j, KEY_DOWN     next selectable line
    k, KEY_UP       prev selectable line

    g               first selectable line
    G               last selectable line

    SPACE           toggle selection for this line

    a, *            select all lines
    A, -            deselect all lines
    t               toggle selection for all lines

    ?, h            help

END_HELP

    my $y = 2;
    for my $line (split(/\n/, $help_text)) {
        $self->print_line(0, $y++, 0, $line);
    }
}

sub _draw_status_line {
    my ($self) = @_;
    my $y = $self->_height - 1;
    my $attr = COLOR_PAIR(2);

    my $selectable = $self->selector->selectable_lines;
    my $selected   = $self->selector->selected_lines;

    my $lhs = ($selectable > 0)
            ? "Selected $selected of $selectable"
            : 'No lines selectable';

    my $rhs = 'uselect ? for help';
    my $len = length($lhs) + length($rhs);
    my $msg = $lhs . (' ' x ($self->_width - $len - 1)) . $rhs;

    $self->print_line(0, $y, $attr, $msg);
}

sub _move_cursor {
    my ($self, $dir) = @_;

    my $curs = $self->_cursor;
    my $new_curs = $self->selector->next_selectable($self->_cursor, $dir);

    if ($new_curs == $self->_cursor) {
        $self->_scroll_to_end($dir);
    }
    else {
        $self->_cursor($new_curs);
    }

}

sub _scroll_to_end {
    my ($self, $dir) = @_;
    my $slr = $self->selector;

    if ($dir < 0) {
        $self->_cursor($slr->next_selectable(-1, +1));
        $self->_first_line(0);
    }
    else {
        $self->_cursor($slr->next_selectable($slr->line_count, -1));
        $self->_first_line(max(0, $slr->line_count - $self->_height + 1));
    }
}

sub _action_quit {
    my ($self) = @_;
    $self->_exit_requested(1);
}

sub _action_resize { }

sub _action_abort {
    my ($self) = @_;
    $_->deselect for $self->selector->selectable_lines;
    $self->_exit_requested(1);
}

sub _action_cursor_up {
    my ($self) = @_;
    $self->_move_cursor(-1);
}

sub _action_cursor_down {
    my ($self) = @_;
    $self->_move_cursor(1);
}

sub _action_cursor_top {
    my ($self) = @_;
    $self->_scroll_to_end(-1);
}

sub _action_cursor_bottom {
    my ($self) = @_;
    $self->_scroll_to_end(+1);
}

sub _action_toggle_selection {
    my ($self) = @_;
    $self->selector->line($self->_cursor)->toggle;
}

sub _action_select_all {
    my ($self) = @_;
    $_->select for $self->selector->selectable_lines;
}

sub _action_deselect_all {
    my ($self) = @_;
    $_->deselect for $self->selector->selectable_lines;
}

sub _action_toggle_all {
    my ($self) = @_;
    $_->toggle for $self->selector->selectable_lines;
}

sub _action_enter_help_mode {
    my ($self) = @_;
    $self->_mode('help');
}

sub _action_leave_help_mode {
    my ($self) = @_;
    $self->_mode('select');
}

#__PACKAGE__->meta->make_immutable;
1;
