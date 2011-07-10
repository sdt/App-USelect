package App::USelect;
use Mouse;
use namespace::autoclean;

use version; our $VERSION = qv('2011.07.10.1');

use Modern::Perl;
use List::Util  qw/ max /;

has selector => (
    is       => 'ro',
    isa      => 'App::USelect::Selector',
    required => 1,
);

has ui => (
    is       => 'rw',
    isa      => 'App::USelect::UI',
    required => 1,
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

has _help_text => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_help_text',
);

sub _has_int  { _has_var('Int',  @_) }
sub _has_str  { _has_var('Str',  @_) }
sub _has_bool { _has_var('Bool', @_) }

_has_int  _first_line => 0;
_has_int  _cursor     => 0;
_has_str  _mode       => 'select';
_has_bool _exit_requested => 0;

sub _build_command_table {
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

        cursor_top => {
            help => 'first selectable line',
            code => sub { $self->_scroll_to_end(-1) },
        },

        cursor_bottom => {
            help => 'last selectable line',
            code => sub { $self->_scroll_to_end(+1) },
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

sub _build_help_text {
    my ($self) = @_;

    my @help_items = qw(
        exit abort - cursor_down cursor_up cursor_top cursor_bottom -
        toggle_selection select_all deselect_all toggle_all - help
    );

    my @help = (
        "uselect v$VERSION",
        '',
    );

    for my $item (@help_items) {
        my $help_text = '';
        if ($item ne '-') {
            my $command = $self->_command_table->{select}->{$item};
            die "No help for $item" unless $command->{help};

            my $keys = join(', ', $self->ui->command_keys($item));
            $help_text = sprintf('    %-12s', $keys) . $command->{help};
        }
        push(@help, $help_text);
    }

    push(@help, '');
    push(@help, 'https://github.com/sdt/App-USelect');

    return \@help;
}

sub run {
    my ($self) = shift;

    $self->_draw();
    while (not $self->_exit_requested) {
        $self->_update;
    }
}

sub _update {
    my ($self) = @_;

    my $command = $self->ui->update;

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
    if ($self->_cursor >= $self->_first_line + $self->ui->height - 1) {
        $self->_first_line($self->_cursor - $self->ui->height + 2);
    }

    given ($self->_mode) {

        when ('select') {
            $self->ui->draw($self->selector, $self->_first_line,
                            $self->_cursor);
        }

        when('help') {
            $self->ui->draw_help($self->selector, $self->_help_text);
        }

    }
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
        $self->_first_line(max(0, $slr->line_count - $self->ui->height + 1));
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


__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

App::USelect.pm main application class.

=head1 METHODS

=head2 new( selector => $selector, ui $ui )

Constructor.

=head2 run

Runs the pplication

=head1 AUTHOR

Stephen Thirlwall <sdt@dr.com>

=cut
