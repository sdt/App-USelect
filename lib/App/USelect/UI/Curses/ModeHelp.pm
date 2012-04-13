package App::USelect::UI::Curses::ModeHelp;
use strict;
use warnings;

# ABSTRACT: Help role for curses UI modes
# VERSION

use Any::Moose 'Role';
use namespace::autoclean;

use App::USelect::UI::Curses::Keys qw( key_name );

requires qw(
    _build__help_items
);

has help_text => (
    is          => 'ro',
    isa         => 'ArrayRef',
    lazy_build  => 1,
);

has _help_items => (
    is          => 'ro',
    isa         => 'ArrayRef',
    lazy_build  => 1,
);

sub _build_help_text {
    my ($self) = @_;

    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my @help = (
        "uselect v$version",
        '',
    );

    for my $cmd (@{ $self->_help_items }) {
        my $help_text = '';
        if (defined $cmd) {
            die "No help for $cmd" unless $cmd->{help};

            my $keys = join(', ', map { key_name($_) }
                @{ $cmd->{keys} });
            $help_text = sprintf('    %-20s', $keys) . $cmd->{help};
        }
        push(@help, $help_text);
    }

    push(@help, '');
    push(@help, 'https://github.com/sdt/App-USelect');

    return \@help;
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
