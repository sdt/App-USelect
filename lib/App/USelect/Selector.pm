package App::USelect::Selector;
use strict;
use warnings;

# ABSTRACT: manages lines
# VERSION

use Any::Moose;
use namespace::autoclean;

use App::USelect::Selector::Line;
use App::USelect::Selector::SelectableLine;

has _text => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
    init_arg    => 'text',
);

has _is_selectable => (
    is          => 'ro',
    isa         => 'CodeRef',
    required    => 1,
    init_arg    => 'is_selectable',
);

has _lines => (
    is          => 'ro',
    isa         => 'ArrayRef[App::USelect::Selector::Line]',
    init_arg    => undef,
    lazy        => 1,
    builder     => '_build__lines',
    traits      => ['Array'],
    handles     => {
        line        => 'get',
        line_count  => 'count',
        _grep       => 'grep',
    },
);

sub _build__lines {
    my ($self) = @_;
    my $build_line = sub {
        my ($text) = @_;
        return $self->_is_selectable->($text)
                ?  App::USelect::Selector::SelectableLine->new(text => $text)
                :  App::USelect::Selector::Line->new(text => $text);
    };
    return [ map { $build_line->($_) } @{ $self->_text } ];
}

sub selectable_lines {
    my ($self) = @_;
    return $self->_grep(sub { $_->can_select });
}

sub selected_lines {
    my ($self) = @_;
    return $self->_grep(sub { $_->is_selected });
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

__END__
=pod

=head1 ATTRIBUTES

=head2 lines

Array of selectable and non-selectable lines.

=head1 ACCESSORS

=head2 line( $index )

Get the line at $index.

=head2 line_count

Get the number of lines.

=head2 grep( \&coderef )

Get the lines filtered by &coderef.

=head2 selectable_lines

Get the lines which are selectable.

=head2 selected_lines

Get the lines which are selected.

=head2 next_selectable ( $line_no, $dir )

Given an existing line number and a direction, return the next selectable
line in that direction. Returns undef if no more lines in that direction.
Direction is positive for down and negative for up.

=cut
