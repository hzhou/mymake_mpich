#!/usr/bin/perl
use strict;

our $mark = "/* MPIR_FUNC */";

my ($log, $rank) = ($ARGV[0], $ARGV[1]);
my $indent = 0;
my @stack;
open In, "$log" or die "Can't open $log: $!\n";
while(<In>){
    if (/^\[$rank\] Entering (\w+)(.*)/) {
        my ($name, $tail) = ($1, $2);
        print ". " x $indent , "Entering $name$tail\n";
        $indent++;
        push @stack, $name;
    }
    elsif (/^\[$rank\] Exit\s+(\w+)(.*)/) {
        my ($name, $tail) = ($1, $2);
        while(@stack){
            $indent--;
            my $t = pop @stack;
            if ($t eq $name) {
                last;
            }
        }
        print ". " x $indent , "Exit     $name$tail\n";
    }
    elsif (/^\[$rank\] (.*)/) {
        print '. ' x $indent, "$1\n";
    }
    elsif (/^\[\d+\]/) {
    }
    else {
        print '. ' x $indent, $_;
    }
}
close In;
