package App::USelect::UI::Curses::Mode;
use strict;
use warnings;

# ABSTRACT: Select mode for curses UI
# VERSION

use Any::Moose 'Role';
use namespace::autoclean;

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
    lazy_build  => 1,
);

sub _build__key_dispatch_table {
    my ($self) = @_;

    my %key_command;

    while (my ($name, $cmd) = each %{ $self->_command_table }) {
        for my $key (@{ $cmd->{keys} }) {
            die "Conflicting keys for $name and $key_command{$key}"
                if exists $key_command{$key};
            $key_command{$key} = $cmd->{code};
        }
    }
    return \%key_command;
}

sub update {
    my ($self, $key) = @_;
    my $command = $self->_key_dispatch_table->{$key};
    return unless $command;
    $command->($self);
    return 1;
}

1;

__END__
=pod

=head1 METHODS

=head2 run

Run the application.

=head2 has_errors

True if there were errors.

=head2 errors

String describing any errors.

=cut
