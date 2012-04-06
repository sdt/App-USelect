package App::USelect;

# ABSTRACT: main application class.
# VERSION

use Any::Moose;
use namespace::autoclean;

use Modern::Perl;
use List::Util  qw/ min max /;

has ui => (
    is       => 'rw',
    isa      => 'App::USelect::UI',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 METHODS

=head2 new( selector => $selector, ui $ui )

Constructor.

=head2 run

Runs the application

=cut
