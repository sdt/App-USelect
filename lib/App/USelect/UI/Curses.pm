package App::USelect::UI::Curses;
use Moose;
#use namespace::autoclean;

# Curses implementation of USelect:UI

use Modern::Perl;
use Curses;
use List::Util  qw/ min /;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

has window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
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
    init_pair(1, COLOR_YELLOW, COLOR_BLACK);
    init_pair(2, COLOR_WHITE,  COLOR_BLUE);
    init_pair(3, COLOR_WHITE,  COLOR_RED);
    init_pair(4, COLOR_GREEN,  COLOR_BLACK);
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

sub DELETEME_draw {
    my ($self, $selector, $first_line, $cursor_line, $mode) = @_;

    $self->_update_size;
    $self->window->erase;

    given ($mode) {
        when ('select') {
            $self->_draw_select_mode($selector, $first_line, $cursor_line)
        }
        when ('help') {
            $self->_draw_help_mode($selector, $first_line, $cursor_line)
        }
    }

    $self->_draw_status_line($selector);
    $self->window->refresh;
}

sub _update_size {
    my ($self) = @_;

    my ($h, $w);
    $self->window->getmaxyx($h, $w);
    $self->_width($w);
    $self->_height($h);
}

sub draw {
    my ($self, $selector, $first_line, $cursor) = @_;

    $self->_pre_draw($selector);

    my $line_count = min($self->_height - 1,
                         $selector->line_count - $first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $first_line;
        my $line = $selector->line($y + $first_line);
        my $attr = ($line_no == $cursor) ? COLOR_PAIR(3)
                 : $line->can('select') ? COLOR_PAIR(1) : 0;
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

sub _draw_status_line {
    my ($self, $selector) = @_;
    my $y = $self->_height - 1;
    my $attr = COLOR_PAIR(2);

    my $selectable = $selector->selectable_lines;
    my $selected   = $selector->selected_lines;

    my $lhs = ($selectable > 0)
            ? "Selected $selected of $selectable"
            : 'No lines selectable';

    my $rhs = 'uselect ? for help';
    my $len = length($lhs) + length($rhs);
    my $msg = $lhs . (' ' x ($self->_width - $len - 1)) . $rhs;

    $self->_print_line(0, $y, $attr, $msg);
}

sub _print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my ($h, $w); $self->window->getmaxyx($h, $w);
    my $old_attr = $self->window->attron($attr);
    $self->window->addstr($y, $x, $str . (' ' x ($w - length($str))));
    $self->window->attrset($old_attr);
}

sub command_keys {
    my ($self, $command) = @_;
    return map { $key_name{$_} // $_ } @{ $keys_table{$command} };
}

#__PACKAGE__->meta->make_immutable;
1;
