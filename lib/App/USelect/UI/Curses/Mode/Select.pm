package App::USelect::UI::Curses::Mode::Select;
use strict;
use warnings;

# ABSTRACT: Select mode for curses UI
# VERSION

use Any::Moose;
use namespace::autoclean;

with 'App::USelect::UI::Curses::Mode';
with 'App::USelect::UI::Curses::ModeHelp';

use App::USelect::UI::Curses::Keys qw( esc enter up down pgup pgdn ctrl );
use List::Util qw( min max );
use Try::Tiny;

has '+ui' => (
    required => 1,
);

has _selector => (
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

sub _build__command_table {
    return {
        exit => {
            help => 'select current line and exit',
            keys => [ enter ],
            code => sub {
                my $self = shift;
                $self->_selector->line($self->_cursor)->select
                    if not $self->_selector->selected_lines;
                $self->ui->_exit_requested(1);
            },
        },

        abort => {
            help => 'abort with no selection',
            keys => [ esc, 'q' ],
            code => sub {
                my $self = shift;
                $_->deselect for $self->_selector->selectable_lines;
                $self->ui->_exit_requested(1);
            },
        },

        cursor_up => {
            help => 'prev selectable line',
            keys => [ up, 'k' ],
            code => sub { shift->_move_cursor(-1) },
        },

        cursor_down => {
            help => 'next selectable line',
            keys => [ down, 'j' ],
            code => sub { shift->_move_cursor(+1) },
        },

        cursor_pgup => {
            help => 'page up',
            keys => [ pgup, ctrl('b'), ctrl('u') ],
            code => sub { shift->_page_up_down(-1) },
        },

        cursor_pgdn => {
            help => 'page dn',
            keys => [ pgdn, ctrl('f'), ctrl('d') ],
            code => sub { shift->_page_up_down(+1) },
        },

        cursor_top => {
            help => 'first selectable line',
            keys => [ 'g' ],
            code => sub { shift->_cursor_to_end(-1) },
        },

        cursor_bottom => {
            help => 'last selectable line',
            keys => [ 'G' ],
            code => sub { shift->_cursor_to_end(+1) },
        },

        toggle_selection => {
            help => 'toggle selection for current line',
            keys => [ ' ' ],
            code => sub {
                my $self = shift;
                $self->_selector->line($self->_cursor)->toggle;
            },
        },

        select_all => {
            help => 'select all lines',
            keys => [ 'a', '*' ],
            code => sub { $_->select for shift->_selector->selectable_lines },
        },

        deselect_all => {
            help => 'deselect all lines',
            keys => [ 'A', '-' ],
            code => sub { $_->deselect for shift->_selector->selectable_lines },
        },

        toggle_all => {
            help => 'toggle selection for all lines',
            keys => [ 't' ],
            code => sub { $_->toggle for shift->_selector->selectable_lines },
        },

        help => {
            help => 'show help screen',
            keys => [ 'h', '?' ],
            code => sub {
                my $self = shift;
                $self->ui->push_mode('Help',
                    help_text => $self->help_text,
                )
            },
        },
    };
}

after update => sub {
    my $self = shift;

    # If the cursor has moved off the screen, scroll so it is visible
    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->ui->_height - 1) {
        $self->_first_line($self->_cursor - $self->ui->_height + 2);
    }
};

sub draw {
    my ($self) = @_;

    my $line_count = min($self->ui->_height - 1,
                         $self->_selector->line_count - $self->_first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $self->_first_line;
        my $line = $self->_selector->line($y + $self->_first_line);
        my $suffix = $line->is_selected ? 'selected' : 'unselected';
        my $color = ($line_no == $self->_cursor) ? "cursor_$suffix"
                  : $line->can_select            ? "selectable_$suffix"
                  :                                'unselectable'
                  ;

        my $prefix = $line->is_selected   ? '# '
                   : $line->can('select') ? '. '
                   :                        '  '
                   ;

        $self->ui->print_line(0, $y, $color, $prefix . $line->text);
    }
    $self->ui->move_cursor_to($self->ui->_width-1,
                              $self->_cursor - $self->_first_line);
}

sub _move_cursor {
    my ($self, $dir) = @_;

    my $curs = $self->_cursor;
    my $new_cursor = $self->_selector->next_selectable($self->_cursor, $dir);
    $self->_set_cursor($new_cursor) or $self->_cursor_to_end($dir);
}

sub _page_up_down {
    my ($self, $dir) = @_;

    my $slr = $self->_selector;
    my $orig_cursor = $self->_cursor;

    # Multiplying by $dir makes this work both ways.
    my $page_size = ($self->ui->_height - 1) * $dir;

    # Move the cursor one page (clamped)
    $self->_cursor($self->_clamp($self->_cursor + $page_size));

    # If that line is selectable, we're good
    return if $slr->line($self->_cursor)->can_select;

    # Otherwise, try the next selectable, then the previous.
    if (!$self->_set_cursor($slr->next_selectable($self->_cursor, $dir))) {
        $self->_set_cursor($slr->next_selectable($self->_cursor, -$dir));
    }

    # If we haven't moved, try scrolling the screen to show the remainder.
    $self->_cursor_to_end($dir) if ($self->_cursor == $orig_cursor);
}

sub _cursor_to_end {
    my ($self, $dir) = @_;
    my $slr = $self->_selector;

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
    my ($min, $max) = (0, $self->_selector->line_count - 1);
    return min(max($value, $min), $max);
}

sub _selection_index {
    my ($self) = @_;
    my $cursor = $self->_cursor;

    # This is a little inelegant...
    my $sel = 1;
    while (defined ($cursor = $self->_selector->next_selectable($cursor, -1))) {
        $sel++;
    }
    return $sel;
}

sub get_status_text {
    my ($self) = @_;

    my $selectable = $self->_selector->selectable_lines;
    my $selected   = $self->_selector->selected_lines;
    my $selection  = $self->_selection_index;

    return (
        "$selection of $selectable, $selected selected",
        'h or ? for help',
    );
}

sub _build__help_items {
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

    return [
        map { $_ eq '-' ? undef : $self->_command_table->{$_} } @help_items
    ];
}

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 METHODS

=head2 draw

Draw method for this mode.

=head2 get_status_text

Returns a two-element array of text for the lhs and rhs of the status bar.

=cut
