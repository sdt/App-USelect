package App::USelect::Selector::SelectableLine;

#ABSTRACT: selectable line class

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
