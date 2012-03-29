package App::USelect::UI;

# ABSTRACT: Curses UI class for uselect
# VERSION

use Any::Moose;
use namespace::autoclean;

use Modern::Perl;
use Curses qw(
    cbreak curs_set endwin init_pair nocbreak noecho start_color
    use_default_colors

    COLOR_PAIR A_BOLD
    COLOR_BLACK COLOR_WHITE
    COLOR_RED COLOR_YELLOW COLOR_GREEN COLOR_CYAN COLOR_BLUE COLOR_MAGENTA

    KEY_UP KEY_DOWN KEY_PPAGE KEY_NPAGE KEY_RESIZE
);
use List::Util qw( min );
use Text::Tabs qw( expand );

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

has window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
);

has width => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

has height => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
);

my $esc = chr(27);
my $enter = "\n";
sub _ctrl {
    my ($char) = @_;
    return chr(ord($char) - ord('a') + 1);
}

my %keys_table = (
    exit                => [ $enter ],
    abort               => [ $esc, 'q' ],
    resize              => [ KEY_RESIZE ],
    cursor_up           => [ KEY_UP, 'k' ],
    cursor_down         => [ KEY_DOWN, 'j' ],
    cursor_pgup         => [ KEY_NPAGE, _ctrl('b'), _ctrl('u') ],
    cursor_pgdn         => [ KEY_PPAGE, _ctrl('f'), _ctrl('d') ],
    cursor_top          => [ 'g' ],
    cursor_bottom       => [ 'G' ],
    toggle_selection    => [ ' ' ],
    select_all          => [ 'a', '*' ],
    deselect_all        => [ 'A', '-' ],
    toggle_all          => [ 't' ],
    help                => [ 'h', '?' ],
);

my %key_name = (
    $esc            => 'ESC',
    $enter          => 'ENTER',
    KEY_UP()        => 'UP',
    KEY_DOWN()      => 'DOWN',
    KEY_NPAGE()     => 'PGDN',
    KEY_PPAGE()     => 'PGUP',

    ( map { _ctrl($_) => '^' . uc($_) } 'a'..'z' ),
);

my %key_dispatch_table;
while (my ($command, $keys) = each %keys_table) {
    for my $key (@{ $keys }) {
        die "Conflicting key definitions for $command and " . $key_dispatch_table{$key}
            if exists $key_dispatch_table{$key};
        $key_dispatch_table{$key} = $command;
    }
}

# Cache and init colors on demand
my %color_table;
sub color {
    my ($fg, $bg) = @_;
    my $key = "$fg:$bg";

    if (exists $color_table{$key}) {
        return $color_table{$key};
    }

    my $index = 1 + keys %color_table;
    init_pair($index, $fg, $bg);

    return $color_table{$key} = COLOR_PAIR($index);
}

# Use solarized color names
my %scolor_table = (
    base03    => [ COLOR_BLACK,   A_BOLD ],
    base02    => [ COLOR_BLACK           ],
    base01    => [ COLOR_GREEN,   A_BOLD ],
    base00    => [ COLOR_YELLOW,  A_BOLD ],
    base0     => [ COLOR_BLUE,    A_BOLD ],
    base1     => [ COLOR_CYAN,    A_BOLD ],
    base2     => [ COLOR_WHITE           ],
    base3     => [ COLOR_WHITE,   A_BOLD ],
    yellow    => [ COLOR_YELLOW          ],
    orange    => [ COLOR_RED,     A_BOLD ],
    red       => [ COLOR_RED             ],
    magenta   => [ COLOR_MAGENTA         ],
    violet    => [ COLOR_MAGENTA, A_BOLD ],
    blue      => [ COLOR_BLUE            ],
    cyan      => [ COLOR_CYAN            ],
    green     => [ COLOR_GREEN           ],
    transp    => [ -1                    ],
);
sub scolor {
    my ($sfg, $sbg) = @_;

    my ($fgc, $fga) = @{ $scolor_table{$sfg} };
    my ($bgc, $bga) = @{ $scolor_table{$sbg} };

    die "Cannot use $sbg as a background color" if $bga;

    my $attr = color($fgc, $bgc);
    $attr |= $fga if $fga;
    return $attr;
}

sub BUILD {
    my ($self, $args) = @_;

    use_default_colors;
    start_color;
    noecho;
    cbreak;
    $self->window->keypad(1);
    #curs_set(0);
    $self->_update_size;
}

sub end {
    nocbreak;
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

    $self->_pre_draw($selector, $cursor);

    my $line_count = min($self->height - 1,
                         $selector->line_count - $first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $first_line;
        my $line = $selector->line($y + $first_line);
        my $attr = ($line_no == $cursor) ? scolor('base3',  'red')
                 : $line->is_selected    ? scolor('orange', 'transp')
                 : $line->can_select     ? scolor('yellow',   'transp')
                 :                       0;

        my $prefix = $line->can('select') ?
                     $line->is_selected ?
                     '# ' : '. ' : '  ';
        $self->_print_line(0, $y, $attr, $prefix . $line->text);
    }
    $self->window->move($cursor - $first_line, $self->width-1);

    $self->_post_draw($selector);
}

sub draw_help {
    my ($self, $selector, $help, $cursor) = @_;

    $self->_pre_draw($selector, $cursor);

    my $x = 4;
    my $y = 2;
    for my $item (@{ $help }) {
        $self->_print_line($x, $y, 0, $item);
        $y++;
    }

    $self->_post_draw($selector);
}

sub command_keys {
    my ($self, $command) = @_;
    return map { $key_name{$_} // $_ } @{ $keys_table{$command} };
}

sub _selection {
    my ($selector, $cursor) = @_;

    # TODO: oh no
    my $sel = 1;
    while (defined ($cursor = $selector->next_selectable($cursor, -1))) {
        $sel++;
    }
    return $sel;
}

sub _draw_status_line {
    my ($self, $selector, $cursor) = @_;

    my $selectable = $selector->selectable_lines;
    my $selected   = $selector->selected_lines;
    my $selection  = _selection($selector, $cursor);

    my $lhs = ($selectable > 0)
            ? "$selection of $selectable, $selected selected"
            : 'No lines selectable';
    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my $mhs = 'uselect v' . $version; # middle-hand side :b
    my $rhs = '? for help';

    my $wid = $self->width;

    my $msg = ' ' x $wid;
    substr($msg, $wid - length($rhs)) = $rhs;
    substr($msg, ($wid - length($mhs))/2, length($mhs)) = $mhs;
    substr($msg, 0, length($lhs)) = $lhs;

    my $attr = scolor('base0', 'base02');
    $self->_print_line(0, $self->height-1, $attr, $msg);
}

sub _print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my $old_attr = $self->window->attron($attr);

    my ($h, $w); $self->window->getmaxyx($h, $w);
    $w -= $x;
    $str = expand($str);
    if (length($str) > $w) {
        $str = substr($str, 0, $w);
    }
    else {
        $str .= ' ' x ($w - length($str));
    }
    $self->window->addstr($y, $x, $str);

    $self->window->attrset($old_attr);
}

sub _pre_draw {
    my ($self, $selector, $cursor) = @_;

    $self->_update_size;
    $self->window->erase;
    $self->_draw_status_line($selector, $cursor);
}

sub _post_draw {
    my ($self, $selector) = @_;

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
