package App::USelect;

# ABSTRACT: main application class.
# VERSION

use Modern::Perl;
use App::USelect::Selector;
use App::USelect::UI::Curses;
use Getopt::Long qw( GetOptionsFromArray );
use Pod::Usage qw( pod2usage );
use Try::Tiny;
use autodie;

# VERSION

# Some debugging aids when things go weird
#use Carp::Always;
#open(STDERR, '>', '/tmp/uselect.log');

sub run {
    my ($class, @ARGV) = @_;

    my %opt = (
        include_blanks  => 0,
        select_code     => '1',
    );

    _process_options(\%opt, \@ARGV);
    my $select_sub = _make_select_sub(\%opt);

    chomp(my @lines = @ARGV ? @ARGV : <STDIN>);

    my $selector = App::USelect::Selector->new(
            text          => \@lines,
            is_selectable => $select_sub,
        );

    if ($selector->selectable_lines == 0) {
        say STDERR 'No selectable lines.';
        exit 2;
    }

    my $ui = App::USelect::UI::Curses->new(
            selector => $selector
        );
    $ui->run();

    if ($ui->has_errors) {
        say STDERR 'ERROR:', $ui->errors;
        exit 3;
    }
    say $_->text for $selector->selected_lines;
    exit ($selector->selected_lines == 0);
}

#-------------------------------------------------------------------------------

sub _process_options {
    my ($opt, $argv) = @_;
    my @options_spec = (
        "blank_lines|b"     => \$opt->{include_blanks},
        "help|h|?"          => sub { pod2usage(0) },
        "select|s=s"        => \$opt->{select_code},
        "version|v"         => sub {
            say "uselect v$App::USelect::VERSION"; exit 0 },
    );

    if (not GetOptionsFromArray($argv, @options_spec)) {
        pod2usage(1);
    }
}

sub _make_select_sub {
    my ($opt) = @_;

    # Try evaluating the user code on its own first - we can tailor a better
    # error message this way.
    local $_ = ''; # silence warnings about $_ being uninitialised
    my $usercode = eval($opt->{select_code}); ## no critic ProhibitStringyEval
    if ($@) {
        # Attempt to replace the default error message with something more
        # contextual. Not sure how robust this is.
        my $msg = $@;
        $msg =~ s/at \(eval \d+\) line \d+/in '$opt->{select_code}'/g;
        say STDERR $msg;
        exit 4;
    }

    if (not $opt->{include_blanks}) {
        $opt->{select_code} = '/\S/ and (' . $opt->{select_code} . ')';
    }

    my $select_sub = eval('sub { $_ = shift; ' . $opt->{select_code} . '}'); ## no critic ProhibitStringyEval
    pod2usage($@) if $@;    # this may still occur even if the first parse succeeded

    return $select_sub;
}

1;
__END__

=pod

=head1 SYNOPSIS

uselect [options] [select text]

  options:
     --blank_lines, -b
        Force blank lines to be selectable.

    --help, -h, -?
        Show this help.

    --select <perl expression>, -s <perl expression>
        Select only those lines for which given perl expression evaluates to
        true. The input lines are passed as $_.

    --version, -v
        Print the version and exit.

  Input lines can be specified on the command line after the options, otherwise
  they will be read from stdin.

=head1 DESCRIPTION

uselect is a reimplementation of iselect by Ralf S. Engelschall

    http://www.ossp.org/pkg/tool/iselect/

uselect is intended to be used as an interactive unix filter. Input lines are
displayed to the user, and selected lines are written to stderr.

=head1 SERVING SUGGESTIONS

fv() { vim $( find . -type f | sort | fgrep "$@" | uselect ); }

gv() { vim $( ack --heading --break "$@" | uselect -s '!/^\d+:/ ); }

=cut

1;

__END__

=pod

=head1 METHODS

=head2 run( @ARGV )

Runs the application

=cut
