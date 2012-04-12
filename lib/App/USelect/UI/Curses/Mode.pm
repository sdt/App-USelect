package App::USelect::UI::Curses::Mode;
use strict;
use warnings;

# ABSTRACT: Select mode for curses UI
# VERSION

use Any::Moose 'Role';
use namespace::autoclean;

requires qw( _build__key_table _build__command_table draw );

#TODO: move this key business into a module
use Curses qw( KEY_UP KEY_DOWN KEY_NPAGE KEY_PPAGE );
my $esc = chr(27);
my $enter = "\n";
sub _ctrl {
    my ($char) = @_;
    return chr(ord($char) - ord('a') + 1);
}
my %key_name = (
    $esc            => 'ESC',
    $enter          => 'ENTER',
    KEY_UP()        => 'UP',
    KEY_DOWN()      => 'DOWN',
    KEY_NPAGE()     => 'PGDN',
    KEY_PPAGE()     => 'PGUP',

    ( map { _ctrl($_) => '^' . uc($_) } 'a'..'z' ),
);

has ui => (
    is      => 'ro',
    isa     => 'App::USelect::UI::Curses',
);

has _key_table => (
    is          => 'ro',
    isa         => 'HashRef',
    lazy_build  => 1,
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

    while (my ($command, $keys) = each %{ $self->_key_table }) {
        for my $key (@{ $keys }) {
            die "Conflicting keys for $command and $key_command{$key}"
                if exists $key_command{$key};
            $key_command{$key} = $self->_command_table->{$command}->{code};
        }
    }
    return \%key_command;
}

sub _build_help_text {
    my ($self) = @_;
    my @help_items = qw(
        exit abort
        -
        cursor_down cursor_up cursor_pgdn cursor_pgup cursor_top cursor_bottom
        -
        toggle_selection select_all deselect_all toggle_all
        -
        help
    );

    my $version = $App::USelect::VERSION || 'DEVELOPMENT';
    my @help = (
        "uselect v$version",
        '',
    );

    for my $item (@help_items) {
        my $help_text = '';
        if ($item ne '-') {
            my $command = $self->command_table->{$item};
            die "No help for $item" unless $command->{help};

            my $keys = join(', ', $self->_command_keys($item));
            $help_text = sprintf('    %-20s', $keys) . $command->{help};
        }
        push(@help, $help_text);
    }

    push(@help, '');
    push(@help, 'https://github.com/sdt/App-USelect');

    return @help;
}

sub update {
    my ($self, $key) = @_;
    my $command = $self->_key_dispatch_table->{$key};
    return unless $command;
    $command->($self);
    return 1;
}

sub _command_keys {
    my ($self, $command) = @_;
    return map { $key_name{$_} // $_ } @{ $self->_keys_table->{$command} };
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
