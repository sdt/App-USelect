package App::USelect::UI::Curses;
use Mouse;

with 'App::USelect::UI';
use namespace::autoclean;

# Curses implementation of USelect:UI

use Modern::Perl;
use Curses  qw/ cbreak curs_set endwin init_pair noecho start_color /;
use List::Util  qw/ min /;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

has window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
);

my $esc = chr(27);
my $enter = "\n";

my %keys_table = (
    exit                => [ $enter ],
    abort               => [ $esc, 'q' ],
    resize              => [ Curses::KEY_RESIZE ],
    cursor_up           => [ Curses::KEY_UP, 'k' ],
    cursor_down         => [ Curses::KEY_DOWN, 'j' ],
    cursor_top          => [ 'g' ],
    cursor_bottom       => [ 'G' ],
    toggle_selection    => [ ' ' ],
    select_all          => [ 'a', '*' ],
    deselect_all        => [ 'A', '-' ],
    toggle_all          => [ 't' ],
    help                => [ 'h', '?' ],
);

my %key_name = (
    $esc                => 'ESC',
    $enter              => 'ENTER',
    Curses::KEY_UP      => 'UP',
    Curses::KEY_DOWN    => 'DOWN',
);

my %key_dispatch_table;
while (my ($command, $keys) = each %keys_table) {
    for my $key (@{ $keys }) {
        $key_dispatch_table{$key} = $command;
    }
}

sub BUILD {
    my ($self, $args) = @_;

    start_color;
    init_pair(1, Curses::COLOR_YELLOW, Curses::COLOR_BLACK);
    init_pair(2, Curses::COLOR_WHITE,  Curses::COLOR_BLUE);
    init_pair(3, Curses::COLOR_WHITE,  Curses::COLOR_RED);
    init_pair(4, Curses::COLOR_GREEN,  Curses::COLOR_BLACK);
    noecho;
    cbreak;
    $self->window->keypad(1);
    curs_set(0);
    $self->_update_size;
}

sub end {
    endwin;
}

sub update {
    my ($self) = @_;

    while (1) {
        my $key = $self->window->getch;
        my $command = $key_dispatch_table{$key};
        return $command if defined $command;
    }
}

sub draw {
    my ($self, $selector, $first_line, $cursor) = @_;

    $self->_pre_draw($selector);

    my $line_count = min($self->height - 1,
                         $selector->line_count - $first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $first_line;
        my $line = $selector->line($y + $first_line);
        my $attr = ($line_no == $cursor) ? Curses::COLOR_PAIR(3)
                 : $line->can('select') ? Curses::COLOR_PAIR(1) : 0;
        my $prefix = $line->can('select') ?
                     $line->is_selected ?
                     '# ' : '. ' : '  ';
        $self->_print_line(0, $y, $attr, $prefix . $line->text);
    }

    $self->_post_draw($selector);
}

sub draw_help {
    my ($self, $selector, $help) = @_;

    $self->_pre_draw($selector);

    my $y = 2;
    for my $item (@{ $help }) {
        $self->_print_line(4, $y, 0, $item);
        $y++;
    }

    $self->_post_draw($selector);
}

sub command_keys {
    my ($self, $command) = @_;
    return map { $key_name{$_} // $_ } @{ $keys_table{$command} };
}

sub _draw_status_line {
    my ($self, $selector) = @_;
    my $y = $self->height - 1;
    my $attr = Curses::COLOR_PAIR(2);

    my $selectable = $selector->selectable_lines;
    my $selected   = $selector->selected_lines;

    my $lhs = ($selectable > 0)
            ? "Selected $selected of $selectable"
            : 'No lines selectable';

    my $rhs = 'uselect ? for help';
    my $len = length($lhs) + length($rhs);
    my $msg = $lhs . (' ' x ($self->width - $len - 1)) . $rhs;

    $self->_print_line(0, $y, $attr, $msg);
}

sub _print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my ($h, $w); $self->window->getmaxyx($h, $w);
    my $old_attr = $self->window->attron($attr);
    $self->window->addstr($y, $x, $str . (' ' x ($w - length($str))));
    $self->window->attrset($old_attr);
}

sub _pre_draw {
    my ($self, $selector) = @_;

    $self->_update_size;
    $self->window->erase;
}

sub _post_draw {
    my ($self, $selector) = @_;

    $self->_draw_status_line($selector);
    $self->window->refresh;
}

sub _update_size {
    my ($self) = @_;

    my ($h, $w);
    $self->window->getmaxyx($h, $w);
    $self->width($w);
    $self->height($h);
}

__PACKAGE__->meta->make_immutable;
1;
