#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir = "$ENV{HOME}/work/mpich";
our $moddir = "$ENV{HOME}/work/modules";
our $prefix = "$ENV{HOME}/MPI";
$opts{V}=0;
my $need_save_args;
if(!@ARGV && -f "mymake/args"){
    my $t;
    {
        open In, "mymake/args" or die "Can't open mymake/args.\n";
        local $/;
        $t=<In>;
        close In;
    }
    @ARGV = split /\s+/, $t;
}
elsif(@ARGV){
    $need_save_args = 1;
}
foreach my $a (@ARGV){
    if($a=~/^--(prefix)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^(\w+)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^--/){
        if($a=~/^--with-device=(.*)/){
            $opts{device}=$1;
            push @config_args, $a;
        }
        elsif($a=~/--(dis|en)able-.*tests/){
            push @test_config_args, $a;
        }
        elsif($a=~/--diable-(romio|fortran)/){
            push @config_args, $a;
            push @test_config_args, $a;
        }
        else{
            push @config_args, $a;
        }
    }
    elsif($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/){
        $opts{do}=$1;
    }
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
if(-f "./maint/version.m4"){
    $srcdir = ".";
}
elsif(-f "../maint/version.m4"){
    $srcdir = "..";
}
elsif(-f "../../maint/version.m4"){
    $srcdir = "../..";
}
elsif(-f "../../../maint/version.m4"){
    $srcdir = "../../..";
}
if($opts{srcdir}){
    $srcdir = $opts{srcdir};
}
if($opts{moddir}){
    $moddir = $opts{moddir};
}
if($opts{prefix}){
    $prefix = $opts{prefix};
}
my $dir = "test/mpi";
my $srcdir="../..";
chdir $dir or die "Can't chdir $dir\n";
if(!-d "mymake"){
    mkdir "mymake" or die "Can't mkdir mymake\n";
}
my $cmd = "rsync -r $srcdir/confdb/ confdb/";
print ": $cmd\n";
system $cmd;
my $cmd = "cp $srcdir/maint/version.m4 .";
print ": $cmd\n";
system $cmd;
my $cmd = "sh autogen.sh";
print ": $cmd\n";
system $cmd;
my $cmd = "autoreconf -ivf";
print ": $cmd\n";
system $cmd;
my $t = join(' ', @test_config_args);
my $cmd = "./configure $t";
print ": $cmd\n";
system $cmd;
my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system $cmd;
my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system $cmd;
if($ENV{skip_test} eq "custom"){
    my $dir=".";
    if($0=~/(.*)\//){
        $dir=$1;
    }
    my $cmd = "perl $dir/run_tests.pl -tests=testlist.custom -junitfile=summary.junit.xml";
    print ": $cmd\n";
    system $cmd;
}
else{
    my $cmd = "make testing";
    print ": $cmd\n";
    system $cmd;
}
