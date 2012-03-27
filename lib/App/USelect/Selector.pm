package App::USelect::Selector;

# ABSTRACT: manages lines
# VERSION

use Any::Moose;
use namespace::autoclean;

use Modern::Perl;

use App::USelect::Selector::Line;
use App::USelect::Selector::SelectableLine;

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

__PACKAGE__->meta->make_immutable;
1;
