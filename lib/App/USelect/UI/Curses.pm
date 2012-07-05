package App::USelect::UI::Curses;
use strict;
use warnings;

# ABSTRACT: Curses UI class for uselect
# VERSION

use Mouse;
use Mouse::Util::TypeConstraints;

BEGIN { $ENV{ESCDELAY} = 0 }    # make esc key respond immediately TODO broken?

use Curses qw();
use Text::Tabs qw( expand );
use Try::Tiny;

use App::USelect::Config;
use App::USelect::UI::Curses::Color         qw( get_color );
use App::USelect::UI::Curses::Mode::Help;
use App::USelect::UI::Curses::Mode::Select;

has selector => (
    is       => 'ro',
    isa      => 'App::USelect::Selector',
    required => 1,
);

has select_mode => (
    is       => 'ro',
    isa      => enum([qw( single multi )]),
    required => 1,
);

has errors => (
    is      => 'ro',
    isa     => 'Str',
    init_arg => undef,
    predicate => 'has_errors',
    writer => '_set_errors',
);

has message => (
    is      => 'ro',
    isa     => 'Str',
);

has _mode_stack => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [
            $self->_new_mode('Select', mode => $self->select_mode)
        ];
    },
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

has _colorscheme => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
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

sub _color {
    my ($self, $name) = @_;

    my $color = $self->_colorscheme->{$name}
        or die "Unknown color $name";

    return get_color($color);
}

sub _set_colorscheme {
    my ($self) = @_;
    my $scheme;
    if (Curses::has_colors) {
        $scheme = App::USelect::Config::get->{_}->{colorscheme};
        if (not $scheme or
            not App::USelect::Config::get->{"colorscheme/$scheme"}) {
            $scheme = 'color';
        }
    }
    else {
        $scheme = 'mono';
    }
    $self->_colorscheme(App::USelect::Config::get->{"colorscheme/$scheme"});
}

sub _pre_run {
    my ($self) = @_;

    $self->_attach_console();
    Curses::initscr;
    Curses::cbreak;
    Curses::noecho;
    Curses::use_default_colors;
    Curses::start_color;
    Curses::keypad(1);
    $self->_set_colorscheme;
    $self->_update_size;
    $self->_exit_requested(0);
}

sub _post_run {
    my ($self) = @_;
    Curses::nocbreak;
    Curses::endwin;
    $self->_detach_console();
}

sub _update {
    my ($self) = @_;

    while (1) {
        my $key = Curses::getch;
        return if $key eq Curses::KEY_RESIZE;
        return if $self->_mode->update($key);
    }
}

sub _draw_status_line {
    my ($self) = @_;

    my ($lhs, $rhs) = $self->_mode->get_status_text;

    my $mhs = $self->message;

    my $wid = $self->_width;

    my $msg = ' ' x $wid;
    substr($msg, $wid - length($rhs)) = $rhs;
    substr($msg, ($wid - length($mhs))/2, length($mhs)) = $mhs;
    substr($msg, 0, length($lhs)) = $lhs;

    $self->print_line(0, $self->_height-1, 'status', $msg);
}

sub move_cursor_to {
    my ($self, $x, $y) = @_;
    Curses::move($y, $x);
}

sub print_line {
    my ($self, $x, $y, $color, $str) = @_;

    my $attr = $self->_color($color);
    my $old_attr = Curses::attron($attr);

    my ($h, $w); Curses::getmaxyx($h, $w);
    $w -= $x;
    $str = expand($str);
    if (length($str) > $w) {
        $str = substr($str, 0, $w);
    }
    else {
        $str .= ' ' x ($w - length($str));
    }
    Curses::addstr($y, $x, $str);

    Curses::attrset($old_attr);
}

sub _pre_draw {
    my ($self) = @_;

    $self->_update_size;
    Curses::erase;
    $self->_draw_status_line;
}

sub _post_draw {
    my ($self) = @_;
    Curses::refresh;
}

sub _update_size {
    my ($self) = @_;

    my ($h, $w);
    Curses::getmaxyx($h, $w);
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

no Mouse;
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

=head2 push_mode( $mode_name, @args )

Create new $mode using @args, and push it on the mode stack.

=head2 pop_mode

Pop the mode stack.

=head2 print_line ($x, $y, $color, $text)

Print text in color at x,y. Curses interface for the mode classes.

=head2 move_cursor_to ( $x, $y )

Move the cursor to x,y. Curses interface for the mode classes.

=cut
