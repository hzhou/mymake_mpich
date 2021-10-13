#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my $t = join(' ', @ARGV);
print "---------------------------\n";
print "-     $t\n";
print "---------------------------\n";
exit(0);
