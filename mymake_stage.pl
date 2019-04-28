#!/usr/bin/perl
use strict;
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t [$ENV{PWD}]\n";
print "---------------------------\n";
exit(0);
