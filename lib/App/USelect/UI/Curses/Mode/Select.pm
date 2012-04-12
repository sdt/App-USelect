package App::USelect::UI::Curses::Mode::Select;
use strict;
use warnings;

# ABSTRACT: Select mode for curses UI
# VERSION

use Any::Moose;
use namespace::autoclean;

use Curses qw(
    cbreak endwin nocbreak noecho start_color use_default_colors
    KEY_UP KEY_DOWN KEY_PPAGE KEY_NPAGE
);
use List::Util qw( min max );
use Text::Tabs qw( expand );
use Try::Tiny;

use App::USelect::UI::Curses::Color::Solarized qw( solarized_color );

has ui => (
    is      => 'ro',
    isa     => 'App::USelect::UI::Curses',
);

has selector => (
    is      => 'ro',
    isa     => 'App::USelect::Selector',
    init_arg => undef,
    default => sub { shift->ui->selector },
);

has [qw( _first_line _cursor )] => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub _set_cursor {
    my ($self, $new_cursor) = @_;
    $self->_cursor($new_cursor) if defined $new_cursor;
    return $new_cursor;
}

my %command_table = (

    exit => {
        help => 'select current line and exit',
        code => sub {
            my $self = shift;
            $self->selector->line($self->_cursor)->select
                if not $self->selector->selected_lines;
            $self->ui->_exit_requested(1);
        },
    },

    abort => {
        help => 'abort with no selection',
        code => sub {
            my $self = shift;
            $_->deselect for $self->selector->selectable_lines;
            $self->ui->_exit_requested(1);
        },
    },

    cursor_up => {
        help => 'prev selectable line',
        code => sub { shift->_move_cursor(-1) },
    },

    cursor_down => {
        help => 'next selectable line',
        code => sub { shift->_move_cursor(+1) },
    },

    cursor_pgup => {
        help => 'page up',
        code => sub { shift->_page_up_down(-1) },
    },

    cursor_pgdn => {
        help => 'page dn',
        code => sub { shift->_page_up_down(+1) },
    },

    cursor_top => {
        help => 'first selectable line',
        code => sub { shift->_cursor_to_end(-1) },
    },

    cursor_bottom => {
        help => 'last selectable line',
        code => sub { shift->_cursor_to_end(+1) },
    },

    toggle_selection => {
        help => 'toggle selection for current line',
        code => sub {
            my $self = shift;
            $self->selector->line($self->_cursor)->toggle;
        },
    },

    select_all => {
        help => 'select all lines',
        code => sub { $_->select for shift->selector->selectable_lines },
    },

    deselect_all => {
        help => 'deselect all lines',
        code => sub { $_->deselect for shift->selector->selectable_lines },
    },

    toggle_all => {
        help => 'toggle selection for all lines',
        code => sub { $_->toggle for shift->selector->selectable_lines },
    },

    help => {
        help => 'show help screen',
        code => sub { shift->_mode('help') },
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

my %keys_table = (
    exit                => [ $enter ],
    abort               => [ $esc, 'q' ],
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

sub _build_help_text {
    my @help_items = qw(
        exit abort
        -
        cursor_down cursor_up cursor_pgdn cursor_pgup cursor_top cursor_bottom
        -
        toggle_selection select_all deselect_all toggle_all
        -
        help
    );

    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my @help = (
        "uselect v$version",
        '',
    );

    for my $item (@help_items) {
        my $help_text = '';
        if ($item ne '-') {
            my $command = $command_table{select}->{$item};
            die "No help for $item" unless $command->{help};

            my $keys = join(', ', _command_keys($item));
            $help_text = sprintf('    %-20s', $keys) . $command->{help};
        }
        push(@help, $help_text);
    }

    push(@help, '');
    push(@help, 'https://github.com/sdt/App-USelect');

    return @help;
}

sub draw {
    my ($self) = @_;

    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->ui->_height - 1) {
        $self->_first_line($self->_cursor - $self->ui->_height + 2);
    }

    my $line_count = min($self->ui->_height - 1,
                         $self->selector->line_count - $self->_first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $self->_first_line;
        my $line = $self->selector->line($y + $self->_first_line);
        my $suffix = $line->is_selected ? 'selected' : 'unselected';
        my $color = ($line_no == $self->_cursor) ? "cursor_$suffix"
                  : $line->can_select            ? "selectable_$suffix"
                  :                                'unselectable'
                  ;

        my $prefix = $line->is_selected   ? '# '
                   : $line->can('select') ? '. '
                   :                        '  '
                   ;

        $self->ui->_print_line(0, $y, $color, $prefix . $line->text);
    }
    $self->ui->move_cursor_to($self->ui->_width-1,
                              $self->_cursor - $self->_first_line);
}

sub _move_cursor {              #XXX: select
    my ($self, $dir) = @_;

    my $curs = $self->_cursor;
    my $new_cursor = $self->selector->next_selectable($self->_cursor, $dir);
    $self->_set_cursor($new_cursor) or $self->_cursor_to_end($dir);
}

sub _page_up_down {             #XXX: select
    my ($self, $dir) = @_;

    my $slr = $self->selector;
    my $orig_cursor = $self->_cursor;

    # Multiplying by $dir makes this work both ways.
    my $page_size = ($self->ui->_height - 1) * $dir;

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

sub _cursor_to_end {                #XXX: select
    my ($self, $dir) = @_;
    my $slr = $self->selector;

    if ($dir < 0) {
        $self->_set_cursor($slr->next_selectable(-1, +1));
        $self->_first_line(0);
    }
    else {
        $self->_set_cursor($slr->next_selectable($slr->line_count, -1));
        $self->_first_line(max(0, $slr->line_count - $self->ui->_height + 1));
    }
}

sub _clamp {
    my ($self, $value) = @_;
    my ($min, $max) = (0, $self->selector->line_count - 1);
    return min(max($value, $min), $max);
}

#TODO: split this out per-mode
my %key_dispatch_table;
while (my ($command, $keys) = each %keys_table) {
    for my $key (@{ $keys }) {
        die "Conflicting key definitions for $command and " . $key_dispatch_table{$key}
            if exists $key_dispatch_table{$key};
        $key_dispatch_table{$key} = $command_table{$command}->{code};
    }
}

sub update {
    my ($self, $key) = @_;
    my $command = $key_dispatch_table{$key};
    return unless $command;
    $command->($self);
    return 1;
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
