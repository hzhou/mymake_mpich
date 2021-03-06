#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;
if (-f "mymake/opts") {
    open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
    while(<In>){
        if (/^(\S+): (.*)/) {
            $opts{$1} = $2;
        }
    }
    close In;
}

my @realclean_list;
push @realclean_list, "subsys_include.m4";
push @realclean_list, "src/mpi/errhan/defmsg.h";
push @realclean_list, "src/include/mpir_cvars.h";
push @realclean_list, "src/include/mpichconf.h";
push @realclean_list, "Makefile";
push @realclean_list, "src/pm/hydra/mymake";
push @realclean_list, "src/pm/hydra/Makefile";

push @realclean_list, "configure";
push @realclean_list, "mymake/t-*";
push @realclean_list, "mymake/Makefile.*";

push @realclean_list, "mymake/mpl";
if (-d "src/openpa") {
    push @realclean_list, "mymake/openpa";
}

if (-d $opts{prefix}) {
    push @realclean_list, "$opts{prefix}/lib/libmpi*";
}

push @realclean_list, "src/binding/c/*/*.c";
push @realclean_list, "src/mpid/ch4/netmod/include/netmod.h";

foreach my $t (@realclean_list) {
    print "rm -rf $t\n";
    system "rm -rf $t";
}
