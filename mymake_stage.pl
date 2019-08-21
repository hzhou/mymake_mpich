#!/usr/bin/perl
use strict;

my $pwd=`pwd`;
chomp $pwd;
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t\n";
print "---------------------------\n";
exit(0);
