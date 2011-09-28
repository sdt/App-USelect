package App::USelect::Selector::Line;

# VERSION

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

1;

# ABSTRACT: uselect line base class
