package App::USelect::Selector::SelectableLine;

# ABSTRACT: selectable line class
# VERSION

use Any::Moose;
use namespace::autoclean;

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

__PACKAGE__->meta->make_immutable;
1;
