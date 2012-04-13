package App::USelect::UI::Curses;
use strict;
use warnings;

# ABSTRACT: Curses UI class for uselect
# VERSION

use Any::Moose;
use namespace::autoclean;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately TODO broken?

use Curses qw(
    cbreak endwin initscr nocbreak noecho start_color use_default_colors
    refresh KEY_RESIZE
);
use Text::Tabs qw( expand );
use Try::Tiny;

use App::USelect::UI::Curses::Color::Solarized qw( solarized_color );

use App::USelect::UI::Curses::Mode::Help;
use App::USelect::UI::Curses::Mode::Select;

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

has _mode_stack => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [ shift->_new_mode('Select') ] },
);

sub _new_mode {
    my ($self, $name, @args) = @_;

    my $class = 'App::USelect::UI::Curses::Mode::' . $name;
    return $class->new(ui => $self, @args);
}

sub push_mode {
    my ($self, $mode, @args) = @_;
    push(@{ $self->_mode_stack }, $self->_new_mode($mode, @args));
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
    lazy     => 1,
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
    help                    =>  'transp/transp',
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
    initscr;
    cbreak;
    noecho;
    use_default_colors;
    start_color;
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

sub _draw_status_line {
    my ($self) = @_;

    my ($lhs, $rhs) = $self->_mode->get_status_text;

    # TODO: make mhs an optional user message
    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my $mhs = 'uselect v' . $version; # middle-hand side :b

    my $wid = $self->_width;

    my $msg = ' ' x $wid;
    substr($msg, $wid - length($rhs)) = $rhs;
    substr($msg, ($wid - length($mhs))/2, length($mhs)) = $mhs;
    substr($msg, 0, length($lhs)) = $lhs;

    $self->print_line(0, $self->_height-1, 'status', $msg);
}

sub move_cursor_to {
    my ($self, $x, $y) = @_;
    $self->_window->move($y, $x);
}

sub print_line {
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
    $self->_draw_status_line;
}

sub _post_draw {
    my ($self) = @_;

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
