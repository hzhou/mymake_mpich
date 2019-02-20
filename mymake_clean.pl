#!/usr/bin/perl
use strict;
our (%opts, @config_args);
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
    elsif($a=~/^(--.*)/){
        push @config_args, $1;
        if($a=~/^--with-device=(.*)/){
            $opts{device}=$1;
        }
    }
}
if(-f "maint/version.m4"){
    $srcdir = ".";
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
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
if($srcdir ne "."){
    chdir $srcdir or die "can't chdir $srcdir\n";
}
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if($need_save_args){
    my $t = join(' ', @ARGV);
    open Out, ">mymake/args" or die "Can't write mymake/args.\n";
    print Out $t;
    close Out;
    system "rm -f mymake/Makefile.orig";
    system "rm -f src/mpl/include/mplconfig.h src/openpa/src/opa_config.h";
}
my @realclean_list;
push @realclean_list, "subsys_include.m4";
push @realclean_list, "configure";
push @realclean_list, "Makefile";
push @realclean_list, "mymake/Makefile.*";
if(-d "src/mpl"){
    push @realclean_list, "src/mpl/include/mplconfig.h";
}
if(-d "src/openpa"){
    push @realclean_list, "src/openpa/src/opa_config.h";
}
if(-d "$moddir/hwloc"){
    push @realclean_list, "$moddir/hwloc/include/hwloc/autogen/config.h";
}
if(-d "$moddir/izem"){
    push @realclean_list, "$moddir/izem/src/include/izem/src/include/zm_config.h";
}
if(-d "$moddir/ucx"){
    push @realclean_list, "$moddir/ucx/config.h";
}
if(-d "$moddir/libfabric"){
    push @realclean_list, "$moddir/libfabric/config.h";
}
push @realclean_list, "src/pm/hydra/mymake/Makefile.orig";
foreach my $t (@realclean_list){
    system "rm -fv $t";
}
