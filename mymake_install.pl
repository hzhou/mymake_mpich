#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my ($obj, $dst) = @ARGV;
if ($dst=~/\/lib$/) {
    if ($obj=~/(.*)\/libmpi.la/) {
        my ($dir) = ($1);
        my ($name1, $name2, $name3);
        open In, "$obj" or die "Can't open $obj: $!\n";
        while(<In>){
            if (/library_names='(\S+) (\S+) (\S+)'/) {
                ($name1, $name2, $name3) = ($1, $2, $3);
            }
        }
        close In;

        system "cp $obj $dst";
        my $cwd = getcwd();
        system "ln -sf $cwd/$dir/.libs/$name1 $dst";
        system "ln -sf $name1 $dst/$name2";
        system "ln -sf $name1 $dst/$name3";
    }
    else {
        system "./libtool --mode=install --silent install $obj $dst";
    }
}
elsif ($dst=~/\/bin$/) {
    system "./libtool --mode=install --silent install $obj $dst";
}
elsif ($dst=~/\/include$/) {
    system "cp $obj $dst";
}
