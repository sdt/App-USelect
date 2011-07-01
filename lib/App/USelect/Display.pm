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

has _command_table => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_command_table',
);

has _dispatch_table => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_dispatch_table',
);

sub has_int  { has_var('Int',  @_) }
sub has_str  { has_var('Str',  @_) }
sub has_bool { has_var('Bool', @_) }

has_int  _first_line => 0;
has_int  _cursor     => 0;
has_int  _width      => 0;
has_int  _height     => 0;
has_str  _mode       => 'select';
has_bool _exit_requested => 0;

my $esc = chr(27);
my $enter = "\n";
sub _build_command_table {
    my ($self) = @_;

    my %select_mode_table = (

        exit => {
            help => 'exit with current selection',
            keys => [ $enter ],
            code => sub { $self->_exit_requested(1) },
        },

        abort => {
            help => 'abort with no selection',
            keys => [ $esc, 'q' ],
            code => sub {
                    $_->deselect for $self->selector->selectable_lines;
                    $self->_exit_requested(1);
                },
        },

        resize => {
            keys => [ Curses::KEY_RESIZE ],
            code => sub { },
        },

        cursor_up => {
            keys => [ Curses::KEY_UP, 'k' ],
            help => 'prev selectable line',
            code => sub { $self->_move_cursor(-1) },
        },

        cursor_down => {
            keys => [ Curses::KEY_DOWN, 'j' ],
            help => 'next selectable line',
            code => sub { $self->_move_cursor(+1) },
        },

        cursor_top => {
            keys => [ 'g' ],
            help => 'first selectable line',
            code => sub { $self->_scroll_to_end(-1) },
        },

        cursor_bottom => {
            keys => [ 'G' ],
            help => 'last selectable line',
            code => sub { $self->_scroll_to_end(+1) },
        },

        toggle_selection => {
            keys => [ ' ' ],
            help => 'toggle selection for current line',
            code => sub { $self->selector->line($self->_cursor)->toggle },

        },

        select_all => {
            keys => [ 'a', '*' ],
            help => 'select all lines',
            code => sub { $_->select for $self->selector->selectable_lines },
        },

        deselect_all => {
            keys => [ 'A', '-' ],
            help => 'deselect all lines',
            code => sub { $_->deselect for $self->selector->selectable_lines },
        },

        toggle_all => {
            keys => [ 't' ],
            help => 'toggle selection for all lines',
            code => sub { $_->toggle for $self->selector->selectable_lines },
        },

        help => {
            keys => [ 'h', '?' ],
            help => 'show help screen',
            code => sub { $self->_mode('help') },
        },

        die => {
            keys => [ 'd' ],
            code => sub { die 'aaeiiieieiea!' },
        },
    );

    my %help_mode_table = (

        exit => {
            keys => [ 'q', chr(27) ],
            help => 'show help screen',
            code => sub { $self->_mode('select') },
        },

    );

    return {
        select  => \%select_mode_table,
        help    => \%help_mode_table,
    };
};

sub _build_dispatch_table {
    my ($self) = @_;

    my %dispatch_table;

    while (my ($mode, $mode_table) = each %{ $self->_command_table }) {
        for my $command (values %{ $mode_table }) {
            for my $key (@{ $command->{keys} }) {
                $dispatch_table{$mode}->{$key} = $command->{code};
            }
        }
    }

    return \%dispatch_table;
};

my %draw_dispatch_table = (
    select  => \&_draw_select_mode,
    help    => \&_draw_help_mode,
);
lock_hash(%draw_dispatch_table);

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

sub run {
    my ($self) = shift;

    while (not $self->_exit_requested) {
        $self->_update;
    }
}

sub end {
    endwin;
}

sub _update {
    my ($self) = @_;

    my $key = $self->window->getch;

    if (my $handler = $self->_dispatch_table->{$self->_mode}->{$key}) {

        $handler->($key);
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

my %key_name = (
    $esc                => 'ESC',
    $enter              => 'ENTER',
    Curses::KEY_UP      => 'UP',
    Curses::KEY_DOWN    => 'DOWN',
);

sub _draw_help_mode {
    my ($self) = @_;

    my @help_items = qw(
        exit abort - cursor_down cursor_up cursor_top cursor_bottom -
        toggle_selection select_all deselect_all toggle_all - help
    );

    my $y = 2;
    for my $item (@help_items) {
        if ($item ne '-') {
            my $command = $self->_command_table->{select}->{$item};
            my $keys = join(', ',
                          map { $key_name{$_} // $_ }
                            @{ $command->{keys} });

            die "No help for $item" unless $command->{help};

            $self->print_line(4, $y, 0,
                sprintf('%-12s', $keys) . $command->{help});
        }
        $y++;
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

sub print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my ($h, $w); $self->window->getmaxyx($h, $w);
    my $old_attr = $self->window->attron($attr);
    $self->window->addstr($y, $x, $str . (' ' x ($w - length($str))));
    $self->window->attrset($old_attr);
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

sub has_var {
    my ($type, $name, $default, %extra) = @_;

    has $name => (
        is       => 'rw',
        isa      => $type,
        init_arg => undef,
        default  => $default,
        %extra,
    );
}


#__PACKAGE__->meta->make_immutable;
1;
