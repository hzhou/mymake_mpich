#!/usr/bin/perl
use strict;
use Cwd;

my $pwd;
if ($ENV{PWD}) {
    $pwd = $ENV{PWD};
}
else {
    $pwd=getcwd();
}
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t\n";
print "---------------------------\n";
exit(0);
