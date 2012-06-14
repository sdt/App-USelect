# NAME

uselect - interactive selection filter

# VERSION

version 0.012

# SYNOPSIS

uselect \[options\] \[select text\]

    options:
       --blank_lines, -b
          Force blank lines to be selectable.

    --help, -h, -?
        Show this help.

    --message <message, -m <message>
        Specify a message to display in the status line

    --select <perl expression>, -s <perl expression>
        Select only those lines for which given perl expression evaluates to
        true. The input lines are passed as $_.

    --single, -1
        Single selection mode

    --version, -v
        Print the version and exit.

    Input lines can be specified on the command line after the options, otherwise
    they will be read from stdin.

# DESCRIPTION

uselect is a reimplementation of iselect by Ralf S. Engelschall

    http://www.ossp.org/pkg/tool/iselect/

uselect is intended to be used as an interactive unix filter. Input lines are
displayed to the user, and selected lines are written to stderr.

# SERVING SUGGESTIONS

fv() { vim $( find . -type f | sort | fgrep "$@" | uselect ); }

gv() { vim $( ack --heading --break "$@" | uselect -s '!/^\\d+:/ ); }

# AUTHOR

Stephen Thirlwall <sdt@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Stephen Thirlwall.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
