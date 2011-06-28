package App::PiSelect::Selector::Line;
use Moose;

has text => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has can_select => (
    is          => 'ro',
    isa         => 'Bool',
    required    => 1,
);

has is_selected => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);

package App::PiSelect::Selector;
use Modern::Perl;

use Params::Validate (qw/ validate :types /);

sub new {
    my $class = shift;
    my %args = validate(@_, {
            lines => {
                type => ARRAYREF,
            },
            is_selectable => {
                type => CODEREF,
            },
        });

    my $self = {
        lines => [ map {
                        App::PiSelect::Selector::Line->new(
                            text       => $_,
                            can_select => $args{is_selectable}->($_),
                        )
                  } @{ $args{lines} } ],
    };
    bless($self, $class);
    return $self;
}

sub line {
    my ($self, $line_no) = @_;
    croak('Line ' . $line_no . ' out of range')
        if ($line_no < 0) or ($line_no >= scalar @{ $self->{lines} });
    return $self->{lines}->[$line_no];
}

sub selection {
    my ($self) = @_;
    return map { $_->text }
            grep { $_->is_selected }
             @{ $self->{lines} };
}

sub _get_line {
    my ($self, $line_no) = @_;
    croak('Line ' . $line_no . ' out of range')
        if ($line_no < 0) or ($line_no >= scalar @{ $self->{lines} });
    return $self->{lines}->[$line_no];
}

sub selectable_count {
    my ($self) = @_;
    return scalar grep { $_->can_select } @{ $self->{lines} };
}

sub selected_count {
    my ($self) = @_;
    return scalar grep { $_->is_selected } @{ $self->{lines} };
}

sub next_selectable {
    my ($self, $line_no, $dir) = @_;
    my $line_count = scalar @{ $self->{lines} };

    for (my $i = $line_no + $dir; ($i >= 0) and ($i < $line_count); $i += $dir) {
        return $i if $self->{lines}->[$i]->can_select;
    }
    return $line_no;
}

sub line_count {
    my ($self) = @_;
    return scalar @{ $self->{lines} };
}

1;
