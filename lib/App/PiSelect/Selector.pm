package App::PiSelect::Selector;
use Moose;
use namespace::autoclean;

use Modern::Perl;

has 'lines' => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
    traits      => ['Array'],
    handles     => {
        line_count => 'count',
        get_line   => 'get',
        all_lines  => 'elements',
    },
);

has 'is_selectable' => (
    is          => 'ro',
    isa         => 'CodeRef',
    default     => sub { 1 },
    required    => 1,
);

has 'line_selectable' => (
    is          => 'ro',
    isa         => 'ArrayRef[Bool]',
    init_arg    => undef,
    builder     => '_build_line_selectable',
    lazy        => 1,
    traits      => ['Array'],
    handles     => {
        can_select => 'get',
    },
);

sub _build_line_selectable {
    my ($self) = @_;
    return [ map { $self->is_selectable->($_) } $self->all_lines ];
}

has 'line_selected' => (
    is          => 'ro',
    isa         => 'ArrayRef[Bool]',
    init_arg    => undef,
    builder     => '_build_line_selected',
    lazy        => 1,
    traits      => ['Array'],
    handles     => {
        is_selected => 'get',
        selected    => 'accessor',
    },
);

sub _build_line_selected {
    my ($self) = @_;
    return [ (0) x $self->all_lines ];
}

sub selection {
    my ($self) = @_;
    return map  { $_->[1] }
           grep { $_->[0] }
           map  { [ $self->selected($_), $self->get_line($_) ] }
           (0 .. $self->line_count - 1);
}

sub toggle_selection {
    my ($self, $line_no) = @_;

    croak('Line ' . $line_no . ' not selectable')
        unless $self->can_select($line_no);
    $self->selected($line_no, not $self->selected($line_no));
}

sub selectable_count {
    my ($self) = @_;
    return scalar grep { $_ } @{ $self->line_selectable };
}

sub selected_count {
    my ($self) = @_;
    return scalar grep { $_ } @{ $self->line_selected };
}

sub next_selectable {
    my ($self, $line_no, $dir) = @_;

    for (my $i = $line_no + $dir; ($i >= 0) and ($i < $self->line_count); $i += $dir) {
        return $i if $self->can_select($i);
    }
    return $line_no;
}

__PACKAGE__->meta->make_immutable;
1;
