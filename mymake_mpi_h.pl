#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\w+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
