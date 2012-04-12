package App::USelect::UI::Curses::Mode::Help;
use strict;
use warnings;

# ABSTRACT: Help mode for curses UI
# VERSION

use Any::Moose;
use namespace::autoclean;

use Try::Tiny;

has ui => (
    is      => 'ro',
    isa     => 'App::USelect::UI::Curses',
);

my %command_table = (
    exit => {
        code => sub { shift->ui->pop_mode },
    },
);

my $esc = chr(27);
my $enter = "\n";
sub _ctrl {
    my ($char) = @_;
    return chr(ord($char) - ord('a') + 1);
}

my %keys_table = (
    exit => [ $esc, 'q' ],
);

#TODO: split this out per-mode
my %key_dispatch_table;
while (my ($command, $keys) = each %keys_table) {
    for my $key (@{ $keys }) {
        die "Conflicting key definitions for $command and " . $key_dispatch_table{$key}
            if exists $key_dispatch_table{$key};
        $key_dispatch_table{$key} = $command_table{$command}->{code};
    }
}

sub update {
    my ($self, $key) = @_;
    my $command = $key_dispatch_table{$key};
    return unless $command;
    $command->($self);
    return 1;
}

sub draw {
    my ($self) = @_;

    my $x = 4;
    my $y = 2;
    my $help = [qw( one two three )];
    for my $item (@{ $help }) {
        $self->ui->print_line($x, $y, 'help', $item);
        $y++;
    }
}

__PACKAGE__->meta->make_immutable;
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
