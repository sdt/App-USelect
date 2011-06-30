package App::USelect::Display;
use Moose;
#use namespace::autoclean;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

use Modern::Perl;
use Curses;
use List::Util  qw/ min max /;

use App::USelect::Selector;

has selector => (
    is      => 'ro',
    isa     => 'App::USelect::Selector',
);

has _first_line => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has _cursor => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has window => (
    is      => 'rw',
    isa     => 'Curses',
    default => sub { Curses->new },
);

has _width => (
    is      => 'rw',
    isa     => 'Int',
);

has _height => (
    is      => 'rw',
    isa     => 'Int',
);

has _debug_msg => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has key_action_table => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    builder  => '_build_key_action_table',
    lazy     => 1,
);

sub _build_key_action_table {
    my ($self) = @_;

    my $esc     = chr(27);
    my $newline = "\n";
    my %kt = (
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
        '-'                 => \&_action_deselect_all,
        't'                 => \&_action_toggle_all,
    );
    return \%kt;
}

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

    $self->_on_resize;
    while ($self->_update) { }
}

sub _update {
    my ($self) = @_;

    my $in = $self->window->getch;
    my $handler = $self->key_action_table->{$in};

    return $handler->($self) if $handler;

    $self->_debug_msg("$in");
    $self->_redraw;
    return 1;
}

sub _redraw {
    my ($self) = @_;
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
    $self->_draw_status_line;
    #$self->window->move($self->_width, $self->_height);
    $self->window->refresh;
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

    my $rhs = $self->_debug_msg;
    my $len = length($lhs) + length($rhs);
    my $msg = $lhs . (' ' x ($self->_width - $len - 1)) . $rhs;

    $self->print_line(0, $y, $attr, $msg);
}

sub _on_resize {
    my ($self) = @_;
    my ($h, $w);
    $self->window->getmaxyx($h, $w);
    $self->_width($w);
    $self->_height($h);

    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->_height - 1) {
        $self->_first_line($self->_cursor - $self->_height + 2);
    }

    $self->_redraw;
}

sub _scroll_to_top {
    my ($self) = @_;

    $self->_cursor($self->selector->next_selectable(-1, +1));
    $self->_first_line(0);
    $self->_redraw;
}

sub _scroll_to_bottom {
    my ($self) = @_;

    my $slr = $self->selector;
    $self->_cursor($slr->next_selectable($slr->line_count, -1));
    $self->_first_line(max(0, $slr->line_count - $self->_height + 1));
    $self->_redraw;
}

sub _action_quit { return }

sub _action_abort {
    my ($self) = @_;

    $_->deselect for $self->selector->selectable_lines;
    return;
}

sub _action_resize {
    my ($self) = @_;

    $self->_on_resize;
    return 1;
}

sub _action_cursor_up {
    my ($self) = @_;

    my $curs = $self->_cursor;
    my $new_curs = $self->selector->next_selectable($curs, -1);

    if ($curs == $new_curs) {
        $self->_scroll_to_top;
    }
    else {
        $self->_cursor($new_curs);
    }
    $self->_on_resize;
    return 1;
}

sub _action_cursor_down {
    my ($self) = @_;

    my $curs = $self->_cursor;
    my $new_curs = $self->selector->next_selectable($curs, 1);

    if ($curs == $new_curs) {
        $self->_scroll_to_bottom;
    }
    else {
        $self->_cursor($new_curs);
    }
    $self->_on_resize;
    return 1;
}

sub _action_cursor_top {
    my ($self) = @_;

    $self->_scroll_to_top;
    $self->_on_resize;
    return 1;
}

sub _action_cursor_bottom {
    my ($self) = @_;

    $self->_scroll_to_bottom;
    $self->_on_resize;
    return 1;
}

sub _action_toggle_selection {
    my ($self) = @_;

    $self->selector->line($self->_cursor)->toggle;
    $self->_redraw;
    return 1;
}

sub _action_select_all {
    my ($self) = @_;

    $_->select for $self->selector->selectable_lines;
    $self->_redraw;
    return 1;
}

sub _action_deselect_all {
    my ($self) = @_;

    $_->deselect for $self->selector->selectable_lines;
    $self->_redraw;
    return 1;
}

sub _action_toggle_all {
    my ($self) = @_;

    $_->toggle for $self->selector->selectable_lines;
    $self->_redraw;
    return 1;
}

#__PACKAGE__->meta->make_immutable;
1;
