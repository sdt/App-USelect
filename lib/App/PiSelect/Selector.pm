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
                {
                    text       => $_,
                    selected   => 0,
                    can_select => $args{is_selectable}->($_),
                }
            } @{ $args{lines} } ],
    };
    bless($self, $class);
    return $self;
}

sub selection {
    my ($self) = @_;
    return map { $_->{text} }
            grep { $_->{selected} }
             @{ $self->{lines} };
}

sub _get_line {
    my ($self, $line_no) = @_;
    croak('Line ' . $line_no . ' out of range')
        if ($line_no < 0) or ($line_no >= scalar @{ $self->{lines} });
    return $self->{lines}->[$line_no];
}

sub toggle_selection {
    my ($self, $line_no) = @_;
    my $line = $self->_get_line($line_no);
    $line->{selected} = not $line->{selected};
    croak('Line ' . $line_no . ' not selectable')
        unless $line->{can_select};
    return $line->{selected};
}

sub selectable_count {
    my ($self) = @_;
    return scalar grep { $_->{can_select} } @{ $self->{lines} };
}

sub selected_count {
    my ($self) = @_;
    return scalar grep { $_->{selected} } @{ $self->{lines} };
}

sub next_selectable {
    my ($self, $line_no, $dir) = @_;
    my $line_count = scalar @{ $self->{lines} };

    for (my $i = $line_no + $dir; ($i >= 0) and ($i < $line_count); $i += $dir) {
        return $i if $self->{lines}->[$i]->{can_select};
    }
    return $line_no;
}

sub line_count {
    my ($self) = @_;
    return scalar @{ $self->{lines} };
}

sub get_line {
    my ($self, $line_no) = @_;
    return $self->_get_line($line_no)->{text};
}

sub can_select {
    my ($self, $line_no) = @_;
    return $self->_get_line($line_no)->{can_select};
}

sub is_selected {
    my ($self, $line_no) = @_;
    return $self->_get_line($line_no)->{selected};
}

1;
