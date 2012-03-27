package App::USelect::Selector::Line;

# ABSTRACT: uselect line base class
# VERSION

use Any::Moose;
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
