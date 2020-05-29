#!/usr/bin/perl
use strict;

my %opt;
foreach my $a (@ARGV) {
    if ($a=~/(\w+)=(\S+)/) {
        $opt{$1}=$2;
    }
}

if (!$opt{netmod}) {
    $opt{netmod}="ch3:tcp";
}

if (!$opt{job}) {
    if ($opt{netmod}=~/(ch\d)/) {
        $opt{job}=$1;
    }
}

if (!-f $opt{conf}) {
    print "No config file exist, exit.\n";
    exit 0;
}

my @C=($opt{job}, $opt{compiler}, $opt{config}, $opt{netmod}, $opt{queue});
open In, "$opt{conf}" or die "Can't open $opt{conf}: $!\n";
while(<In>){
    if (/^\s*([^# ].*\S)\s*(sed .*)/) {
        my $cmd = $2;
        my @cond=split /\s+/, $1;
        my $mismatch;
        for (my $i = 0; $i<5; $i++) {
            if ($cond[$i] ne '*' && $cond[$i] ne $C[$i]) {
                $mismatch=1;
                last;
            }
        }
        if (!$mismatch) {
            $cmd=~s/ test\/mpi\// /;
            print " $cmd\n";
            system $cmd;
        }
    }
}
close In;
