#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\w+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
my $dir = "test/mpi";
my $srcdir="../..";
chdir $dir or die "Can't chdir $dir\n";
if (!-d "mymake") {
    mkdir "mymake" or die "Can't mkdir mymake\n";
}

my $cmd = "rsync -r $srcdir/confdb/ confdb/";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $cmd = "rsync -r $srcdir/confdb/ dtpools/confdb/";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $cmd = "cp $srcdir/maint/version.m4 .";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $cmd = "sh autogen.sh";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $cmd = "autoreconf -ivf";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $config_args = "";
foreach my $t (split /\s+/, $opts{config_args}) {
    if ($t=~/--(dis|en)able-.*tests/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-device=(.*)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--(dis|en)able-(fortran|cxx|romio)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-(thread-package|argobots)/) {
        $config_args .= " $t";
    }
}
my $cmd = "./configure $config_args";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";

my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system($cmd) == 0 or die "    Command failed.\n";
if ($ENV{skip_test} eq "custom") {
    my $dir=".";
    if ($0=~/(.*)\//) {
        $dir=$1;
    }
    my $cmd = "perl $dir/runtests.pl -tests=testlist.custom -junitfile=summary.junit.xml";
    print ": $cmd\n";
    system($cmd) == 0 or die "    Command failed.\n";
}
else {
}
