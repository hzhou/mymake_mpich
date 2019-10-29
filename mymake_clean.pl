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
    chomp $t;
    @ARGV = split /\s+/, $t;
    print "loading last ARGV: @ARGV\n";
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
        elsif($a=~/^--with-pm=(.*)/){
            $opts{pm}=$1;
        }
        elsif($a=~/--(dis|en)able-.*tests/){
            push @test_config_args, $a;
        }
        elsif($a=~/--disable-(romio|cxx|fortran)/){
            $opts{"disable_$1"}=1;
            $opts{"enable_$1"}=0;
            push @config_args, $a;
            push @test_config_args, $a;
        }
        elsif($a=~/--enable-fortran=(\w+)/){
            $opts{disable_fortran}=0;
            $opts{enable_fortran}=$1;
            push @config_args, $a;
            push @test_config_args, $a;
        }
        elsif($a=~/--with-atomic-primitives=(.*)/){
            $opts{openpa_primitives} = $1;
        }
        elsif($a=~/--enable-strict/){
            $opts{enable_strict} = 1;
            push @config_args, $a;
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
my $mod_tarball;
if($ENV{MODTARBALL}){
    $mod_tarball = $ENV{MODTARBALL};
}
elsif(-e "modules.tar.gz"){
    $mod_tarball = "modules.tar.gz";
}
elsif(-e "mymake/modules.tar.gz"){
    $mod_tarball = "mymake/modules.tar.gz";
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
elsif(-d "mymake/hwloc"){
    $moddir = "$pwd/mymake";
}
elsif(-e $mod_tarball){
    $moddir = "$pwd/mymake";
    my $cmd = "mkdir -p $moddir";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $moddir -xf $mod_tarball";
    print "$cmd\n";
    system $cmd;
    my $cmd = "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir/ucx,g\"";
    print "$cmd\n";
    system $cmd;
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
    push @realclean_list, "$moddir/izem/src/include/zm_config.h";
}
if(-d "$moddir/ucx"){
    push @realclean_list, "$moddir/ucx/config.h";
}
if(-d "$moddir/libfabric"){
    push @realclean_list, "$moddir/libfabric/config.h";
}
if(-d "src/mpi/romio"){
    push @realclean_list, "src/mpi/romio/adio/include/romioconf.h";
}
if(-d "modules/jsonc"){
    push @realclean_list, "";
}
push @realclean_list, "src/pm/hydra/mymake/Makefile.orig";
push @realclean_list, "src/mpi/errhan/defmsg.h";
push @realclean_list, "src/include/mpir_cvars.h";
foreach my $t (@realclean_list){
    system "rm -fv $t";
}
