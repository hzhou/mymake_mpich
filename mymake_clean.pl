#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir;
our $moddir;
our $prefix;
my $pwd=`pwd`;
chomp $pwd;
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
if($opts{CC}){
    $ENV{CC}=$opts{CC};
}
if($opts{CXX}){
    $ENV{CXX}=$opts{CXX};
}
if($opts{F77}){
    $ENV{F77}=$opts{F77};
}
if($opts{FC}){
    $ENV{FC}=$opts{FC};
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
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
elsif(-d "modules"){
    $moddir = "$pwd/modules";
}
elsif(-e "modules.tar.gz"){
    $moddir = "$pwd/modules";
    system "mkdir $moddir";
    system "tar -C $moddir xf modules.tar.gz";
    system "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir,g\"";
}
else{
    die "moddir not set\n";
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
if(!$srcdir){
    die "srcdir not set\n";
}
if(!$prefix){
    $prefix="$pwd/_inst";
    system "mkdir -p $prefix";
}
my @realclean_list;
push @realclean_list, "subsys_include.m4";
push @realclean_list, "configure";
push @realclean_list, "Makefile";
push @realclean_list, "mymake/Makefile.*";
if(-d "$moddir/mpl"){
    push @realclean_list, "$moddir/mpl/include/mplconfig.h";
}
if(-d "$moddir/openpa"){
    push @realclean_list, "$moddir/openpa/src/opa_config.h";
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
push @realclean_list, "src/mpi/errhan/defmsg.h";
push @realclean_list, "src/include/mpir_cvars.h";
foreach my $t (@realclean_list){
    system "rm -fv $t";
}
