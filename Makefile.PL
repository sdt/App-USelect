use inc::Module::Install;

name     'App-USelect';
all_from 'bin/uselect';
author   q{Stephen Thirlwall <sdt@dr.com>};
license  'perl';

build_requires 'Test::More';

requires        'autodie';
requires        'Curses';
requires        'List::Util';
requires        'Modern::Perl';
requires        'Moose';

install_script  'bin/uselect';
auto_install;

WriteAll;

