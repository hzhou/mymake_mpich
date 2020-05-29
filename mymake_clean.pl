#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if /^(\w+): (.*)/;
        $opts{$1} = $2;
}
close In;

my @realclean_list;
push @realclean_list, "subsys_include.m4";
push @realclean_list, "configure";
push @realclean_list, "Makefile";
push @realclean_list, "mymake/Makefile.*";
if (-d "$opts{moddir}/mpl") {
    push @realclean_list, "$opts{moddir}/mpl/include/mplconfig.h";
}
if (-d "$opts{moddir}/openpa") {
    push @realclean_list, "$opts{moddir}/openpa/src/opa_config.h";
}
if (-d "$opts{moddir}/hwloc") {
    push @realclean_list, "$opts{moddir}/hwloc/include/hwloc/autogen/config.h";
}
if (-d "$opts{moddir}/izem") {
    push @realclean_list, "$opts{moddir}/izem/src/include/zm_config.h";
}
if (-d "$opts{moddir}/ucx") {
    push @realclean_list, "$opts{moddir}/ucx/config.h";
}
if (-d "$opts{moddir}/libfabric") {
    push @realclean_list, "$opts{moddir}/libfabric/config.h";
}
if (-d "src/mpi/romio") {
    push @realclean_list, "src/mpi/romio/adio/include/romioconf.h";
}
if (-d "$opts{moddir}/json-c") {
    push @realclean_list, "$opts{moddir}/json-c/json.h";
}
push @realclean_list, "src/pm/hydra/mymake/Makefile.orig";
push @realclean_list, "src/mpi/errhan/defmsg.h";
push @realclean_list, "src/include/mpir_cvars.h";
foreach my $t (@realclean_list) {
    system "rm -fv $t";
}
