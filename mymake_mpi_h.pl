#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd;
if ($ENV{PWD}) {
    $pwd = $ENV{PWD};
}
else {
    $pwd=getcwd();
}
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\w+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
