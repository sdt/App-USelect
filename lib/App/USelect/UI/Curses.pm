package App::USelect::UI::Curses;
use strict;
use warnings;

# ABSTRACT: Curses UI class for uselect
# VERSION

use Any::Moose;
use namespace::autoclean;

use Curses qw(
    cbreak curs_set endwin nocbreak noecho start_color use_default_colors
    KEY_UP KEY_DOWN KEY_PPAGE KEY_NPAGE KEY_RESIZE
);
use List::Util qw( min max );
use Text::Tabs qw( expand );
use Try::Tiny;

use App::USelect::UI::Curses::Color::Solarized qw( solarized_color );
use App::USelect::UI::Curses::Mode::Select;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately

has selector => (
    is       => 'ro',
    isa      => 'App::USelect::Selector',
    required => 1,
);

has errors => (
    is      => 'ro',
    isa     => 'Str',
    init_arg => undef,
    predicate => 'has_errors',
    writer => '_set_errors',
);

has _mode_table => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

has _mode_stack => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [ shift->_get_mode('Select') ] },
);

sub _get_mode {
    my ($self, $name) = @_;
    if (! exists $self->_mode_table->{$name}) {
        my $class = 'App::USelect::UI::Curses::Mode::' . $name;
        $self->_mode_table->{$name} = $class->new(ui => $self);
    }
    return $self->_mode_table->{$name};
}

sub push_mode {
    my ($self, $mode) = @_;
    push(@{ $self->_mode_stack }, $self->_get_mode($mode));
}

sub pop_mode {
    my ($self) = @_;
    pop(@{ $self->_mode_stack });
}

sub _mode {
    my ($self) = shift;
    return $self->_mode_stack->[-1];
}

has _window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
);

has _stdout => (
    is => 'ro',
    init_arg => undef,
    writer => '_set_stdout',
);

has [qw( _width _height )] => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has _exit_requested => (
    is => 'rw',
    isa => 'Bool',
    default => 0,

);

sub _set_cursor {               #XXX: select
    my ($self, $new_cursor) = @_;
    $self->_cursor($new_cursor) if defined $new_cursor;
    return $new_cursor;
}

my %command_table = (

    help => {

        exit => {
            code => sub { shift->_mode('select') },
        },
        abort => {
            code => sub { shift->_mode('select') },
        },
        resize => {
            code => sub { },
        },
    },
);

my $esc = chr(27);
my $enter = "\n";
sub _ctrl {
    my ($char) = @_;
    return chr(ord($char) - ord('a') + 1);
}

my %key_name = (
    $esc            => 'ESC',
    $enter          => 'ENTER',
    KEY_UP()        => 'UP',
    KEY_DOWN()      => 'DOWN',
    KEY_NPAGE()     => 'PGDN',
    KEY_PPAGE()     => 'PGUP',

    ( map { _ctrl($_) => '^' . uc($_) } 'a'..'z' ),
);

# TODO: split this out per-mode
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

sub run {
    my ($self) = shift;

    $self->_pre_run();
    try {
        while (not $self->_exit_requested) {
            $self->_draw();
            $self->_update();
        }
    }
    catch {
        $self->_set_errors($_);
    };
    $self->_post_run();
}

sub _draw {
    my ($self) = @_;

    $self->_pre_draw();
    $self->_mode->draw();
    $self->_post_draw();
}

my %color_table = (
    cursor_selected         =>  'green/base02',
    cursor_unselected       =>  'base1/base02',
    selectable_selected     =>  'green/transp',
    selectable_unselected   =>  'base0/transp',
    unselectable            =>  'base01/transp',
    status                  =>  'base1/base02',
);
sub _color {
    my ($name) = @_;

    my $solarized_color = $color_table{$name}
        or die "Unknown color $name";

    return solarized_color($solarized_color);
}

sub _pre_run {
    my ($self) = @_;

    $self->_attach_console();
    use_default_colors;
    start_color;
    noecho;
    cbreak;
    $self->_window->keypad(1);
    $self->_update_size;
    $self->_exit_requested(0);
}

sub _post_run {
    my ($self) = @_;
    nocbreak;
    endwin;
    $self->_detach_console();
}

sub _update {
    my ($self) = @_;

    while (1) {
        my $key = $self->_window->getch;
        return if $key eq KEY_RESIZE;
        return if $self->_mode->update($key);
    }
}

sub _draw_help {
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

sub _command_keys {
    my ($command) = @_;
    return map { $key_name{$_} // $_ } @{ $keys_table{$command} };
}

#XXX: This gets called by the status line, but is select
sub _selection_index {
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
    my $selection  = _selection_index($selector, $cursor);

    my $lhs = ($selectable > 0)
            ? "$selection of $selectable, $selected selected"
            : 'No lines selectable';
    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my $mhs = 'uselect v' . $version; # middle-hand side :b
    my $rhs = '? for help';

    my $wid = $self->_width;

    my $msg = ' ' x $wid;
    substr($msg, $wid - length($rhs)) = $rhs;
    substr($msg, ($wid - length($mhs))/2, length($mhs)) = $mhs;
    substr($msg, 0, length($lhs)) = $lhs;

    my $attr = _color('status');
    $self->_print_line(0, $self->_height-1, $attr, $msg);
}

sub move_cursor_to {
    my ($self, $x, $y) = @_;
    $self->_window->move($y, $x);
}

sub _print_line {
    my ($self, $x, $y, $color, $str) = @_;

    my $attr = _color($color);
    my $old_attr = $self->_window->attron($attr);

    my ($h, $w); $self->_window->getmaxyx($h, $w);
    $w -= $x;
    $str = expand($str);
    if (length($str) > $w) {
        $str = substr($str, 0, $w);
    }
    else {
        $str .= ' ' x ($w - length($str));
    }
    $self->_window->addstr($y, $x, $str);

    $self->_window->attrset($old_attr);
}

sub _pre_draw {
    my ($self) = @_;

    $self->_update_size;
    $self->_window->erase;
}

sub _post_draw {
    my ($self) = @_;

    #$self->_draw_status_line($selector, $cursor);
    $self->_window->refresh;
}

sub _update_size {
    my ($self) = @_;

    my ($h, $w);
    $self->_window->getmaxyx($h, $w);
    $self->_width($w);
    $self->_height($h);
}

sub _attach_console {
    my ($self) = @_;
    open(STDIN, '<', '/dev/tty');

    open my $stdout, '>&STDOUT';
    open(STDOUT, '>', '/dev/tty');

    $self->_set_stdout($stdout);
}

sub _detach_console {
    my ($self) = @_;
    open(STDOUT, '>&', $self->_stdout);
}

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 METHODS

=head2 run

Run the application.

=head2 has_errors

True if there were errors.

=head2 errors

String describing any errors.

=cut
