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
