package App::USelect::Selector::Line;
use Moose;
use Modern::Perl;

has text => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has can_select => (
    is          => 'ro',
    isa         => 'Bool',
    required    => 1,
);

has is_selected => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);

package App::USelect::Selector;
use Moose;
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
        return App::USelect::Selector::Line->new(
                text       => $_[0],
                can_select => $self->is_selectable->($_[0])
            )
        };
    return [ map { $build_line->($_) } @{ $self->_text } ];
}

sub selection {
    my ($self) = @_;
    return map { $_->text } $self->grep(sub { $_->is_selected });
}

sub next_selectable {
    my ($self, $line_no, $dir) = @_;
    my $line_count = $self->line_count;

    for (my $i = $line_no + $dir; ($i >= 0) && ($i < $line_count); $i += $dir) {
        return $i if $self->line($i)->can_select;
    }
    return $line_no;
}

sub select_all {
    my ($self, $is_selected) = @_;

    for my $line ($self->grep( sub { $_->can_select } )) {
        $line->is_selected($is_selected);
    }
}

1;
