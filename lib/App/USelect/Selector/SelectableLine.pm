package App::USelect::Selector::SelectableLine;
use strict;
use warnings;

# ABSTRACT: selectable line class
# VERSION

use Any::Moose;
use namespace::autoclean;

extends 'App::USelect::Selector::Line';

has is_selected => (
    is          => 'ro',
    isa         => 'Bool',
    default     => 0,
    traits      => ['Bool'],
    handles     => {
        select      => 'set',
        deselect    => 'unset',
        toggle      => 'toggle',
    },
);

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 ATTRIBUTES

=head2 is_selected

True if the line is selected.

=head1 METHODS

=head2 select

Select the line.

=head2 deselect

Deselect the line.

=head2 toggle

Toggle the selection state of the line.

=cut
