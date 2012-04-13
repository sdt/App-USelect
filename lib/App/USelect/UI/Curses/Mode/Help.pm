package App::USelect::UI::Curses::Mode::Help;
use strict;
use warnings;

# ABSTRACT: Help mode for curses UI
# VERSION

use Any::Moose;
use namespace::autoclean;

with 'App::USelect::UI::Curses::Mode';

use App::USelect::UI::Curses::Keys qw( esc );
use Try::Tiny;

has help_text => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
);

sub _build__command_table {
    return {
        exit => {
            code => sub { shift->ui->pop_mode },
            keys => [ esc, 'q' ],
            help => 'exit this help',
        },
    };
}

sub draw {
    my ($self) = @_;

    my $x = 4;
    my $y = 2;
    for my $item (@{ $self->help_text }) {
        $self->ui->print_line($x, $y, 'help', $item);
        $y++;
    }
}

sub get_status_text {
    my ($self) = @_;
    return ( 'q or esc to exit help', '' );
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
