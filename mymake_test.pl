#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my $pwd = getcwd();

my $cmd = "find test/mpi -name Makefile.am";
my @all_makefile_ams;
open In, "$cmd |" or die "Can't open $cmd |: $!\n";
while(<In>){
    if (/^test.mpi.(util|dtpools)/) {
    }
    elsif (/^(test.mpi.*Makefile.am)/) {
        push @all_makefile_ams, $1;
    }
}
close In;
foreach my $am (@all_makefile_ams) {
    if ($am=~/(.*)\/Makefile.am/) {
        my ($dir) = ($1);
        chdir $dir;
        my $type;
        my @prog_list;
        my (%prog_flags, %prog_source);
        open In, "Makefile.am" or die "Can't open Makefile.am: $!\n";
        while(<In>){
            if (/^include .*Makefile_single.mtest/) {
                $type = "single";
            }
            elsif (/^noinst_PROGRAMS\s*=(.*)/) {
                my @all;
                my $t = $1;
                while ($t=~/(.*)\\$/) {
                    push @all, $1;
                    $t = <In>;
                }
                push @all, $1;
                my $t = join ' ', @all;
                $t=~s/^\s+//g;
                $t=~s/\s+$//g;
                @prog_list = split /\s+/, $t;
            }
            elsif (/^(\w+)_CPPFLAGS\s*=\s*(.*)/) {
                $prog_flags{$1} = $2;
            }
            elsif (/^(\w+)_SOURCES\s*=\s*(.*)/) {
                $prog_source{$1} = $2;
            }
        }
        close In;
        if ($type) {
            print " --> $dir/Makefile\n";
            open Out, ">Makefile" or die "Can't write Makefile: $!\n";
            print Out "all: @prog_list\n\n";
            foreach my $a (@prog_list) {
                my $source = $prog_source{$a};
                if (!$source) {
                    $source = "$a.c";
                }
                print Out "$a: $source\n";
                print Out "\tmpicc -o $a $source\n\n";
            }
            close Out;
        }
        chdir $pwd;
    }
}
