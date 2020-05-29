#!/usr/bin/perl
use strict;
use Cwd;

my $pwd=getcwd();
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t\n";
print "---------------------------\n";
exit(0);
