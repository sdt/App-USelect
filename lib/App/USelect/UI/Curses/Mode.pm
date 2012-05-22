package App::USelect::UI::Curses::Mode;
use strict;
use warnings;

# ABSTRACT: Select mode for curses UI
# VERSION

use Mouse::Role;

use Carp qw( croak );

requires qw(
    _build__command_table
    draw
    get_status_text
);

has ui => (
    is      => 'ro',
    isa     => 'App::USelect::UI::Curses',
);

has _command_table => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
);

has _key_dispatch_table => (
    is          => 'ro',
    isa         => 'HashRef',
    builder     => '_build__key_dispatch_table',
);

sub _build__key_dispatch_table {
    my ($self) = @_;

    my %key_command;
    while (my ($name, $cmd) = each %{ $self->_command_table }) {
        $cmd->{name} = $name;
        for my $key (@{ $cmd->{keys} }) {
            if (exists $key_command{$key}) {
                croak "Conflicting key $key for $key_command{$key}->{name} and $cmd->{name}";
            }
            $key_command{$key} = $cmd;
        }
    }
    return \%key_command;
}

sub update {
    my ($self, $key) = @_;
    my $command = $self->_key_dispatch_table->{$key};
    return unless $command;
    $command->{code}->($self);
    return 1;
}

1;

__END__
=pod

=head1 REQUIREMENTS

head2 _build__command_table

Builder method for the command table. Should return a hashref of name => command
pairs. Commands are hashrefs containing a keys arrayref, a code coderef, and
an optional help string.

TODO: should the command be a class?

=head2 draw

Render the current state of the UI mode.

=head2 get_status_text

Return a two-element arrayref with strings to put in the left and right hand side
of the status bar.

=head1 ATTRIBUTES

=head2 ui

App::USelect::UI::Curses instance

=head1 METHODS

=head2 update

Process one input keystroke. Returns true if the keystroke
corresponded to a command action.


=cut
