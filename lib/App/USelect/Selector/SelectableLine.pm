package App::USelect::Selector::SelectableLine;

# VERSION

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

1;

# ABSTRACT: selectable line class
