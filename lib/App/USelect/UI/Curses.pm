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

has _window => (
    is       => 'rw',
    isa      => 'Curses',
    default  => sub { Curses->new },
);

has _command_table => (
    is         => 'ro',
    isa        => 'HashRef',
    init_arg   => undef,
    lazy_build => 1,
);

has _help_text => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]',
    init_arg   => undef,
    lazy_build => 1,
);

has _stdout => (
    is => 'ro',
    init_arg => undef,
    writer => '_set_stdout',
);

sub _has_int  { _has_var('Int',  @_) }
sub _has_str  { _has_var('Str',  @_) }
sub _has_bool { _has_var('Bool', @_) }

_has_int  _first_line       => 0;
_has_int  _cursor           => 0;
_has_str  _mode             => 'select';
_has_bool _exit_requested   => 0;
_has_int  _width            => 0;
_has_int  _height           => 0;

sub _set_cursor {
    my ($self, $new_cursor) = @_;
    $self->_cursor($new_cursor) if defined $new_cursor;
    return $new_cursor;
}
sub _build__command_table {
    my ($self) = @_;

    my %select_mode_table = (

        exit => {
            help => 'select current line and exit',
            code => sub {
                    $self->selector->line($self->_cursor)->select
                        if not $self->selector->selected_lines;
                    $self->_exit_requested(1);
                },
        },

        abort => {
            help => 'abort with no selection',
            code => sub {
                    $_->deselect for $self->selector->selectable_lines;
                    $self->_exit_requested(1);
                },
        },

        resize => {
            # no-op, but implement a handler to force a redraw
            code => sub { },
        },

        cursor_up => {
            help => 'prev selectable line',
            code => sub { $self->_move_cursor(-1) },
        },

        cursor_down => {
            help => 'next selectable line',
            code => sub { $self->_move_cursor(+1) },
        },

        cursor_pgup => {
            help => 'page up',
            code => sub { $self->_page_up_down(-1) },
        },

        cursor_pgdn => {
            help => 'page dn',
            code => sub { $self->_page_up_down(+1) },
        },

        cursor_top => {
            help => 'first selectable line',
            code => sub { $self->_cursor_to_end(-1) },
        },

        cursor_bottom => {
            help => 'last selectable line',
            code => sub { $self->_cursor_to_end(+1) },
        },

        toggle_selection => {
            help => 'toggle selection for current line',
            code => sub { $self->selector->line($self->_cursor)->toggle },

        },

        select_all => {
            help => 'select all lines',
            code => sub { $_->select for $self->selector->selectable_lines },
        },

        deselect_all => {
            help => 'deselect all lines',
            code => sub { $_->deselect for $self->selector->selectable_lines },
        },

        toggle_all => {
            help => 'toggle selection for all lines',
            code => sub { $_->toggle for $self->selector->selectable_lines },
        },

        help => {
            help => 'show help screen',
            code => sub { $self->_mode('help') },
        },

    );

    my %help_mode_table = (

        exit => {
            code => sub { $self->_mode('select') },
        },
        abort => {
            code => sub { $self->_mode('select') },
        },
        resize => {
            code => sub { },
        },


    );

    return {
        select  => \%select_mode_table,
        help    => \%help_mode_table,
    };
};

sub _build__help_text {
    my ($self) = @_;

    my @help_items = qw(
        exit abort
        -
        cursor_down cursor_up cursor_pgdn cursor_pgup cursor_top cursor_bottom
        -
        toggle_selection select_all deselect_all toggle_all
        -
        help
    );

    my @help = (
        "uselect v$App::USelect::VERSION",
        '',
    );

    for my $item (@help_items) {
        my $help_text = '';
        if ($item ne '-') {
            my $command = $self->_command_table->{select}->{$item};
            die "No help for $item" unless $command->{help};

            my $keys = join(', ', $self->_command_keys($item));
            $help_text = sprintf('    %-20s', $keys) . $command->{help};
        }
        push(@help, $help_text);
    }

    push(@help, '');
    push(@help, 'https://github.com/sdt/App-USelect');

    return \@help;
}

sub run {
    my ($self) = shift;

    $self->_pre_run();
    try {
        $self->_draw();
        while (not $self->_exit_requested) {
            $self->_update;
        }
    }
    catch {
        $self->_set_errors($_);
    };
    $self->_post_run();
}

sub _update {
    my ($self) = @_;

    my $command = $self->_next_command;

    if (my $handler = $self->_command_table->{$self->_mode}->{$command}) {
        $handler->{code}->();
        $self->_draw();
    }
}

sub _draw {
    my ($self) = @_;

    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->_height - 1) {
        $self->_first_line($self->_cursor - $self->_height + 2);
    }

    if ($self->_mode == 'select') {
        $self->_draw_select($self->selector, $self->_first_line, $self->_cursor);
    }
    elsif ($self->_mode == 'help') {
        $self->_draw_help($self->selector, $self->_help_text, $self->_cursor);
    }
}

sub _move_cursor {
    my ($self, $dir) = @_;

    my $curs = $self->_cursor;
    my $new_cursor = $self->selector->next_selectable($self->_cursor, $dir);
    $self->_set_cursor($new_cursor) or $self->_cursor_to_end($dir);
}

sub _page_up_down {
    my ($self, $dir) = @_;

    my $slr = $self->selector;
    my $orig_cursor = $self->_cursor;

    # Multiplying by $dir makes this work both ways.
    my $page_size = ($self->_height - 1) * $dir;

    # Move the cursor one page (clamped)
    $self->_cursor($self->_clamp($self->_cursor + $page_size));

    # If that line is selectable, we're good
    return if $slr->line($self->_cursor)->can_select;

    # Otherwise, try the next selectable, then the previous.
    $self->_set_cursor($slr->next_selectable($self->_cursor, $dir))
        // $self->_set_cursor($slr->next_selectable($self->_cursor, -$dir));

    # If we haven't moved, try scrolling the screen to show the remainder.
    $self->_cursor_to_end($dir) if ($self->_cursor == $orig_cursor);
}

sub _cursor_to_end {
    my ($self, $dir) = @_;
    my $slr = $self->selector;

    if ($dir < 0) {
        $self->_set_cursor($slr->next_selectable(-1, +1));
        $self->_first_line(0);
    }
    else {
        $self->_set_cursor($slr->next_selectable($slr->line_count, -1));
        $self->_first_line(max(0, $slr->line_count - $self->_height + 1));
    }
}

sub _has_var {
    my ($type, $name, $default, %extra) = @_;

    has $name => (
        is       => 'rw',
        isa      => $type,
        init_arg => undef,
        default  => $default,
        %extra,
    );
}

sub _clamp {
    my ($self, $value) = @_;
    my ($min, $max) = (0, $self->selector->line_count - 1);
    return min(max($value, $min), $max);
}

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

sub _next_command {
    my ($self) = @_;

    while (1) {
        my $key = $self->_window->getch;
        my $command = $key_dispatch_table{$key};
        return $command if defined $command;
    }
}

sub _draw_select {
    my ($self, $selector, $first_line, $cursor) = @_;

    $self->_pre_draw($selector, $cursor);

    my $line_count = min($self->_height - 1,
                         $selector->line_count - $first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $first_line;
        my $line = $selector->line($y + $first_line);
        my $suffix = $line->is_selected ? 'selected' : 'unselected';
        my $attr = ($line_no == $cursor) ? _color("cursor_$suffix")
                 : $line->can_select     ? _color("selectable_$suffix")
                 :                         _color('unselectable')
                 ;

        my $prefix = $line->is_selected   ? '# '
                   : $line->can('select') ? '. '
                   :                        '  '
                   ;

        $self->_print_line(0, $y, $attr, $prefix . $line->text);
    }
    $self->_window->move($cursor - $first_line, $self->_width-1);

    $self->_post_draw($selector);
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
    my ($self, $command) = @_;
    return map { $key_name{$_} // $_ } @{ $keys_table{$command} };
}

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

sub _print_line {
    my ($self, $x, $y, $attr, $str) = @_;

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
    my ($self, $selector, $cursor) = @_;

    $self->_update_size;
    $self->_window->erase;
    $self->_draw_status_line($selector, $cursor);
}

sub _post_draw {
    my ($self, $selector) = @_;

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
