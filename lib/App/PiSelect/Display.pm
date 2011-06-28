package App::PiSelect::Display;
use Moose;
#use namespace::autoclean;

use Modern::Perl;
use Curses;
use List::Util  qw/ min max /;
use Scalar::Util qw/ looks_like_number /;

use App::PiSelect::Selector;

has selector => (
    is      => 'ro',
    isa     => 'App::PiSelect::Selector',
);

has _first_line => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has _cursor => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has window => (
    is      => 'rw',
    isa     => 'Curses',
    default => sub { Curses->new },
);

has _width => (
    is      => 'rw',
    isa     => 'Int',
);

has _height => (
    is      => 'rw',
    isa     => 'Int',
);

has key_exit => (
    is      => 'rw',
    default => 'q',
);

has key_up => (
    is      => 'rw',
    default => KEY_UP,
);

has key_down => (
    is      => 'rw',
    default => KEY_DOWN,
);

has key_toggle_selection => (
    is      => 'rw',
    default => ' ',
);

has _debug_msg => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

open my $log, '>', '/tmp/piselect.out';

sub BUILD {
    my ($self, $args) = @_;

    start_color;
    init_pair(1, COLOR_YELLOW, COLOR_BLACK);
    init_pair(2, COLOR_WHITE,  COLOR_BLUE);
    init_pair(3, COLOR_WHITE,  COLOR_RED);
    init_pair(4, COLOR_GREEN,  COLOR_BLACK);
    noecho;
    raw;
    $self->window->keypad(1);
    curs_set(0);
}

sub print_line {
    my ($self, $x, $y, $attr, $str) = @_;

    my ($h, $w); $self->window->getmaxyx($h, $w);
    my $old_attr = $self->window->attron($attr);
    $self->window->addstr($y, $x, $str . (' ' x ($w - length($str))));
    $self->window->attrset($old_attr);
}

sub run {
    my ($self) = shift;

    $self->_on_resize;
    while ($self->_update) { }
    endwin;
}

sub _update {
    my ($self) = @_;

    my $in = $self->window->getch;

    when ($in eq KEY_RESIZE) {
       $self->_on_resize;
       return 1;
    }

    my $curs = $self->_cursor;
    my $line = $self->selector->line($self->_cursor);

    given ($in) {

        when ('q') {
            return;
        }

        when ('k') {
            my $new_curs = $self->selector->next_selectable($curs, -1);
            if ($curs == $new_curs) {
                $self->_scroll_to_top;
            }
            else {
                $self->_cursor($new_curs);
            }
            $self->_on_resize;
        }

        when ('j') {
            my $new_curs = $self->selector->next_selectable($curs, +1);
            if ($curs == $new_curs) {
                $self->_scroll_to_bottom;
            }
            else {
                $self->_cursor($new_curs);
            }
            $self->_on_resize;
        }

        when ('g') {
            $self->_scroll_to_top;
            $self->_on_resize;
        }

        when ('G') {
            $self->_scroll_to_bottom;
            $self->_on_resize;
        }

        when (' ') {
            if ($line->can_select) {
                $line->is_selected(not $line->is_selected);
            }
            $self->_redraw;
        }

        default {
            $self->_debug_msg("$in");
            $self->_redraw;
        }

    }
    return 1;
}

sub _redraw {
    my ($self) = @_;
    my $slr = $self->selector;
    my $line_count = min($self->_height - 1,
                         $slr->line_count - $self->_first_line);

    for my $y (0 .. $line_count - 1) {
        my $line_no = $y + $self->_first_line;
        my $line = $slr->line($y + $self->_first_line);
        my $attr = ($line_no == $self->_cursor) ? COLOR_PAIR(3)
                 : $line->can_select ? COLOR_PAIR(1) : 0;
        my $prefix = $line->can_select ?
                     $line->is_selected ?
                     '# ' : '. ' : '  ';
                     #'[*] ' : '[ ] ' : '    ';
        $self->print_line(0, $y, $attr, $prefix . $line->text);
    }
    $self->_draw_status_line;
    #$self->window->move($self->_width, $self->_height);
    $self->window->refresh;
}

sub _draw_status_line {
    my ($self) = @_;
    my $y = $self->_height - 1;
    my $attr = COLOR_PAIR(2);
    my $slr = $self->selector;

    my $selectable = $slr->grep(sub { $_->can_select  });
    my $selected   = $slr->grep(sub { $_->is_selected });

    my $lhs = ($selectable > 0)
            ? "Selected $selected of $selectable"
            : 'No lines selectable';

    my $rhs = $self->_debug_msg;
    my $len = length($lhs) + length($rhs);
    my $msg = $lhs . (' ' x (($self->_width - $len)/2)) . $rhs;

    $self->print_line(0, $y, $attr, "$rhs $lhs");
}

sub _on_resize {
    my ($self) = @_;
    my ($h, $w);
    $self->window->getmaxyx($h, $w);
    $self->_width($w);
    $self->_height($h);

    if ($self->_cursor < $self->_first_line) {
        $self->_first_line($self->_cursor);
    }
    if ($self->_cursor >= $self->_first_line + $self->_height - 1) {
        $self->_first_line($self->_cursor - $self->_height + 2);
    }

    $self->_redraw;
}

sub _scroll_to_top {
    my ($self) = @_;

    my $slr = $self->selector;
    $self->_cursor($slr->next_selectable(-1, +1));
    $self->_first_line(0);
    $self->_redraw;
}

sub _scroll_to_bottom {
    my ($self) = @_;

    my $slr = $self->selector;
    $self->_cursor($slr->next_selectable($slr->line_count, -1));
    $self->_first_line(max(0, $slr->line_count - $self->_height));
    $self->_redraw;
}


#__PACKAGE__->meta->make_immutable;
1;
