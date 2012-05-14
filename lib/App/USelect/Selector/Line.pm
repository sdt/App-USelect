package App::USelect::Selector::Line;
use strict;
use warnings;

# ABSTRACT: uselect base class for text lines
# VERSION

use Mouse;
use namespace::autoclean;

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

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 ATTRIBUTES

=head2 text

The text itself.

=head1 METHODS

=head2 is_selected()

True if the the line has been selected.

=head2 can_select()

True if the line can be selected.

=cut
