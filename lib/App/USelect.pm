package App::USelect;

# ABSTRACT: main application class.
# VERSION

use Any::Moose;
use namespace::autoclean;

use App::USelect::Selector;
use App::USelect::UI::Curses;

use Modern::Perl;
use Try::Tiny;

has _selector => (
    is => 'ro',
    isa => 'App::USelect::Selector',
    handles => {
        selectable_line_count => 'selectable_lines',
        selected_lines => 'selected_lines',
        selected_line_count => 'selected_lines',
    }
);

has _errors => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_errors',
    writer => '_set_errors',
);

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;

    my $selector = App::USelect::Selector->new(
            text => $args{text},
            is_selectable => $args{is_selectable},
        );

    return $class->$orig(_selector => $selector);
};

sub run {
    my ($self) = @_;

    my $ui = App::USelect::UI::Curses->new(selector => $self->_selector);
    $ui->run;
    $self->_set_errors($ui->errors)
        if $ui->has_errors;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 METHODS

=head2 new( selector => $selector, ui => $ui )

Constructor.

=head2 run

Runs the application

=cut
