package App::USelect::Selector::Line;
use Mouse;

has text => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

sub is_selected { 0 }

sub can_select {
    my ($self) = @_;
    return $self->can('select');
}

package App::USelect::Selector::SelectableLine;
use Mouse;
extends 'App::USelect::Selector::Line';

has is_selected => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
    traits      => ['Bool'],
    handles     => {
        select      => 'set',
        deselect    => 'unset',
        toggle      => 'toggle',
    },
);

package App::USelect::Selector;
use Mouse;
use Modern::Perl;

has _text => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
    init_arg    => 'text',
);

has is_selectable => (
    is          => 'ro',
    isa         => 'CodeRef',
    required    => 1,
);

has lines => (
    is          => 'ro',
    isa         => 'ArrayRef[App::USelect::Selector::Line]',
    init_arg    => undef,
    lazy        => 1,
    builder     => '_build_lines',
    traits      => ['Array'],
    handles     => {
        line        => 'get',
        line_count  => 'count',
        grep        => 'grep',
    },
);

sub _build_lines {
    my ($self) = @_;
    my $build_line = sub {
        my ($text) = @_;
        return $self->is_selectable->($text)
                ?  App::USelect::Selector::SelectableLine->new(text => $text)
                :  App::USelect::Selector::Line->new(text => $text);
    };
    return [ map { $build_line->($_) } @{ $self->_text } ];
}

sub selectable_lines {
    my ($self) = @_;
    return $self->grep(sub { $_->can_select });
}

sub selected_lines {
    my ($self) = @_;
    return $self->grep(sub { $_->is_selected });
}

sub next_selectable {
    my ($self, $line_no, $dir) = @_;
    my $line_count = $self->line_count;

    for (my $i = $line_no + $dir; ($i >= 0) && ($i < $line_count); $i += $dir) {
        return $i if $self->line($i)->can_select;
    }
    return;
}

1;
