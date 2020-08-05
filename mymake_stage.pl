#!/usr/bin/perl
use strict;
use Cwd;

my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t\n";
print "---------------------------\n";
exit(0);
