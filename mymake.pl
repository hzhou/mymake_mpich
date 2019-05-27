#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir;
our $moddir;
our $prefix;
our $I_list;
our $L_list;
our %objects;
our @CONFIGS;
our %dst_hash;
our @programs;
our @ltlibs;
our %special_targets;
our @extra_make_rules;
sub get_list {
    my ($key) = @_;
    my @t;
    my $tlist = $objects{$key};
    foreach my $t (@{$objects{$key}}){
        if($t=~/^\$\((\w+)\)$/){
            my $L = get_list($1);
            push @t, @$L;
        }
        else{
            $t=~s/\$\((\w+)\)/get_object($1)/ge;
            push @t, $t;
        }
    }
    return \@t;
}

sub get_object {
    my ($key) = @_;
    my $arr = $objects{$key};
    if(defined $arr){
        my $t;
        if(ref($arr) eq "ARRAY"){
            $t = join(' ', @$arr);
        }
        else{
            $t = $arr;
        }
        $t=~s/\$\(am__v_[\w]+\)//g;
        $t=~s/\$\((\w+)\)/get_object($1)/ge;
        $t=~s/\s+/ /g;
        return $t;
    }
    else{
        return "";
    }
}

my $pwd=`pwd`;
chomp $pwd;
my $mymake;
if($0=~/^(\/.*)\//){
    $mymake = $1;
}
elsif($0=~/^(.*)\//){
    $mymake .= "$pwd/$1";
}
$mymake .="/mymake";
if(-d "pm"){
    system "perl $mymake\_hydra.pl @ARGV";
    exit(0);
}
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
        elsif($a=~/--(dis|en)able-.*tests/){
            push @test_config_args, $a;
        }
        elsif($a=~/--disable-(romio|cxx|fortran)/){
            $opts{"disable_$1"}=1;
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
    my $cmd = "mkdir $moddir";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $moddir -xf modules.tar.gz";
    print "$cmd\n";
    system $cmd;
    my $cmd = "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir,g\"";
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
if($opts{do}){
    system "perl $mymake\_$opts{do}.pl";
    exit(0);
}
if($srcdir ne "."){
    chdir $srcdir or die "can't chdir $srcdir\n";
}
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if(!-f 'src/util/cvar/mpir_cvars.c'){
    system "touch src/util/cvar/mpir_cvars.c";
}
push @extra_make_rules, "DO_stage = perl $mymake\_stage.pl";
push @extra_make_rules, "DO_clean = perl $mymake\_clean.pl";
push @extra_make_rules, "DO_errmsg = perl $mymake\_errmsg.pl";
push @extra_make_rules, "DO_cvars = perl $mymake\_cvars.pl";
push @extra_make_rules, "DO_logs = perl $mymake\_logs.pl";
push @extra_make_rules, "DO_hydra = perl $mymake\_hydra.pl";
push @extra_make_rules, "DO_test = perl $mymake\_test.pl";
push @extra_make_rules, "DO_mpi_h = perl $mymake\_mpi_h.pl";
push @extra_make_rules, "";
push @extra_make_rules, ".PHONY: test cvars errmsg";
push @extra_make_rules, "test:";
push @extra_make_rules, "\t\x24(DO_test)";
push @extra_make_rules, "";
push @extra_make_rules, "cvars:";
push @extra_make_rules, "\t\x24(DO_cvars)";
push @extra_make_rules, "";
push @extra_make_rules, "errmsg:";
push @extra_make_rules, "\t\x24(DO_errmsg)";
push @extra_make_rules, "";
if($need_save_args){
    my $t = join(' ', @ARGV);
    open Out, ">mymake/args" or die "Can't write mymake/args.\n";
    print Out $t;
    close Out;
    system "rm -f mymake/Makefile.orig";
    system "rm -f $moddir/mpl/include/mplconfig.h $moddir/openpa/src/opa_config.h";
}
print "srcdir: $srcdir\n";
print "moddir: $moddir\n";
print "prefix: $prefix\n";
if($opts{device}){
    print "device: $opts{device}\n";
}
my $mkfile="src/pm/hydra/Makefile";
my $add="$moddir/mpl/libmpl.la $moddir/hwloc/hwloc/libhwloc_embedded.la";
push @extra_make_rules, ".PHONY: hydra hydra-install";
push @extra_make_rules, "hydra: $mkfile $add";
push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) )";
push @extra_make_rules, "";
push @extra_make_rules, "hydra-install: $mkfile";
push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) install )";
push @extra_make_rules, "";
push @extra_make_rules, "$mkfile:";
push @extra_make_rules, "\t\x24(DO_hydra) --prefix=\x24(PREFIX)";
push @extra_make_rules, "";
if(!$opts{disable_cxx}){
    print ": buildiface - cxx\n";
    chdir "src/binding/cxx";
    system "perl buildiface -nosep -initfile=./cxx.vlist";
    chdir $pwd;
    $dst_hash{"src/binding/cxx/mpicxx.h"}="$prefix/include";
}
if(!$opts{disable_fortran}){
    print ": buildiface - mpif_h\n";
    chdir "src/binding/fortran/mpif_h";
    system "perl buildiface >/dev/null";
    chdir $pwd;
    print ": buildiface - use_mpi\n";
    chdir "src/binding/fortran/use_mpi";
    system "perl buildiface >/dev/null";
    chdir $pwd;
    print ": buildiface - use_mpi_f08\n";
    chdir "src/binding/fortran/use_mpi_f08";
    system "perl buildiface >/dev/null";
    chdir $pwd;
    $dst_hash{"src/binding/fortran/mpif_h/mpif.h"}="$prefix/include";
    print ": buildiface - use_mpi_f08/wrappers_c\n";
    chdir "src/binding/fortran/use_mpi_f08/wrappers_c";
    system "perl buildiface $pwd/src/include/mpi.h.in";
    system "perl buildiface $pwd/src/mpi/romio/include/mpio.h.in";
    chdir $pwd;
}
if(!-f "subsys_include.m4"){
    print "---------------------------\n";
    print "-     maint/gen_subcfg_m4\n";
    print "---------------------------\n";
    system "perl maint/gen_subcfg_m4";
}
if(!-f "configure"){
    system "rm -f mymake/Makefile.orig";
    print "---------------------------\n";
    print "-     Autoconf MPICH\n";
    print "---------------------------\n";
    my @mod_list;
    my $f = "configure.ac";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/AC_CONFIG_SUBDIRS/){
            next;
        }
        elsif($l=~/^\s*HWLOC_/){
            next;
        }
        elsif($l=~/^\s*src\/binding\//){
            next;
        }
        elsif($l=~/^(\s*)(PAC_CONFIG_SUBDIR.*)/){
            $l = "$1: \x23 $2\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    my $f = "src/Makefile.mk";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/^include .*\/binding\//){
            next;
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    my $f = "Makefile.am";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/ACLOCAL_AMFLAGS/){
            $l ="ACLOCAL_AMFLAGS = -I confdb\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    my $flag;
    my $f = "src/mpid/ch3/subconfigure.m4";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/AC_MSG_CHECKING.*OpenPA/){
            $flag=1;
        }
        elsif($flag and $l=~/AC_C_BIGENDIAN/){
            $flag=0;
        }
        elsif($flag){
            next;
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    if($opts{device}=~/ucx/){
        my $flag;
        my $f = "src/mpid/ch4/netmod/ucx/subconfigure.m4";
        my $f_ = $f;
        $f_=~s/[\.\/]/_/g;
        my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
        push @mod_list, \@m;
        system "mv $m[0] $m[1]";
        my @lines;
        {
            open In, "$m[1]" or die "Can't open $m[1].\n";
            @lines=<In>;
            close In;
        }
        my $flag_skip=0;
        open Out, ">$m[2]" or die "Can't write $m[2].\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines){
            if($l=~/^AM_COND_IF\(\[BUILD_CH4_NETMOD_UCX\]/){
                $flag = 1;
                next;
            }
            elsif($flag){
                if($l=~/^\]\)/){
                    $flag = 0;
                    next;
                }
                elsif($l=~/AC_DEFINE\(HAVE_UCP_\w+_NB,1/){
                }
                else{
                    next;
                }
            }
            if($flag_skip){
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
    if($opts{device}=~/ofi/){
        my $flag;
        my $f = "src/mpid/ch4/netmod/ofi/subconfigure.m4";
        my $f_ = $f;
        $f_=~s/[\.\/]/_/g;
        my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
        push @mod_list, \@m;
        system "mv $m[0] $m[1]";
        my @lines;
        {
            open In, "$m[1]" or die "Can't open $m[1].\n";
            @lines=<In>;
            close In;
        }
        my $flag_skip=0;
        open Out, ">$m[2]" or die "Can't write $m[2].\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines){
            if($l=~/^AM_COND_IF\(\[BUILD_CH4_NETMOD_OFI\]/){
                $flag = 1;
                next;
            }
            elsif($flag){
                if($l=~/^\]\).*AM_COND_IF\(BUILD_CH4_NETMOD_OFI/){
                    $flag = 0;
                    print Out "    AC_DEFINE([MPIDI_CH4_OFI_USE_SET_RUNTIME], [1], [Define to use runtime capability set])\n";
                    next;
                }
                else{
                    next;
                }
            }
            if($flag_skip){
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
    system "autoreconf -ivf";
    foreach my $m (@mod_list){
        system "cp $m->[1] $m->[0]";
    }
}
if(!-f "mymake/Makefile.orig"){
    print "---------------------------\n";
    print "-     Configure MPICH\n";
    print "---------------------------\n";
    system "rm -f Makefile";
    my $t = join ' ', @config_args;
    system "./configure --with-pm=no $t";
    system "mv Makefile mymake/Makefile.orig";
    my @mod_list;
    my $f = "libtool";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/^AR_FLAGS=/){
            $l = "AR_FLAGS=\"cr\"\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    system "chmod a+x libtool";
    foreach my $m (@mod_list){
        system "cp $m->[1] $m->[0]";
    }
}
open In, "src/include/mpichconf.h" or die "Can't open src/include/mpichconf.h.\n";
while(<In>){
    if(/^#define\s+HAVE_.*WEAK.* 1/){
        $opts{have_weak}=1;
    }
}
close In;
open In, "maint/version.m4" or die "Can't open maint/version.m4.\n";
while(<In>){
    if(/libmpi_so_version_m4.*\[([\d:]*)\]/){
        $opts{so_version}=$1;
    }
}
close In;
open In, "config.status" or die "Can't open config.status.\n";
while(<In>){
    if(/S\["WRAPPER_LIBS"\]="(.*)"/){
        $opts{WRAPPER_LIBS}=$1;
    }
}
close In;
if(!$opts{have_weak}){
    $special_targets{lib_libmpi_la}="\x24(LTCC) -DMPICH_MPI_FROM_PMPI";
}
my $bin="\x24(PREFIX)/bin";
if(-f "src/env/mpicc.bash"){
    my @lines;
    {
        open In, "src/env/mpicc.bash" or die "Can't open src/env/mpicc.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$prefix, EXEC_PREFIX=>"$prefix/bin", SYSCONFDIR=>"$prefix/etc", INCLUDEDIR=>"$prefix/include", LIBDIR=>"$prefix/lib");
    open Out, ">mymake/mpicc" or die "Can't write mymake/mpicc.\n";
    foreach my $l (@lines){
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpicc"}=$bin;
}
if(-f "src/env/mpicxx.bash"){
    my @lines;
    {
        open In, "src/env/mpicxx.bash" or die "Can't open src/env/mpicxx.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$prefix, EXEC_PREFIX=>"$prefix/bin", SYSCONFDIR=>"$prefix/etc", INCLUDEDIR=>"$prefix/include", LIBDIR=>"$prefix/lib");
    open Out, ">mymake/mpicxx" or die "Can't write mymake/mpicxx.\n";
    foreach my $l (@lines){
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpicxx"}=$bin;
}
if(-f "src/env/mpif77.bash"){
    my @lines;
    {
        open In, "src/env/mpif77.bash" or die "Can't open src/env/mpif77.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$prefix, EXEC_PREFIX=>"$prefix/bin", SYSCONFDIR=>"$prefix/etc", INCLUDEDIR=>"$prefix/include", LIBDIR=>"$prefix/lib");
    open Out, ">mymake/mpif77" or die "Can't write mymake/mpif77.\n";
    foreach my $l (@lines){
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpif77"}=$bin;
}
if(-f "src/env/mpifort.bash"){
    my @lines;
    {
        open In, "src/env/mpifort.bash" or die "Can't open src/env/mpifort.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$prefix, EXEC_PREFIX=>"$prefix/bin", SYSCONFDIR=>"$prefix/etc", INCLUDEDIR=>"$prefix/include", LIBDIR=>"$prefix/lib");
    open Out, ">mymake/mpifort" or die "Can't write mymake/mpifort.\n";
    foreach my $l (@lines){
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpifort"}=$bin;
}
$dst_hash{"LN_S-$bin/mpic++"}="$bin/mpicxx";
$dst_hash{"LN_S-$bin/mpif90"}="$bin/mpifort";
push @extra_make_rules, "examples/cpi: lib/libmpi.la";
push @extra_make_rules, "\t\x24(CC) -o examples/cpi examples/cpi.c lib/.libs/libmpi.a $opts{WRAPPER_LIBS}";
push @extra_make_rules, "";
push @extra_make_rules, "src/mpi/errhan/errutil.lo: src/mpi/errhan/defmsg.h";
push @extra_make_rules, "src/mpi/errhan/defmsg.h:";
push @extra_make_rules, "\t\x24(DO_errmsg)";
push @extra_make_rules, "";
push @CONFIGS, "src/include/mpir_cvars.h";
push @extra_make_rules, "src/include/mpir_cvars.h:";
push @extra_make_rules, "\t\x24(DO_cvars)";
push @extra_make_rules, "";
my @t = ("cd src/glue/romio");
push @t, "perl all_romio_symbols ../../mpi/romio/include/mpio.h.in";
push @extra_make_rules, "src/glue/romio/all_romio_symbols.c: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if(!-d "$moddir/mpl"){
    my $cmd = "cp -r src/mpl $moddir/mpl";
    print "$cmd\n";
    system $cmd;
    my $cmd = "cp -r confdb $moddir/mpl/";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$moddir/mpl/include";
$L_list .= " $moddir/mpl/libmpl.la";
push @CONFIGS, "$moddir/mpl/include/mplconfig.h";
my $config_args = "--disable-versioning --enable-embedded";
foreach my $t (@config_args){
    if($t=~/--enable-g/){
        $config_args.=" $t";
    }
}
my @t = ("cd $moddir/mpl");
push @t, "\x24(DO_stage) Configure MPL";
push @t, "autoreconf -ivf";
push @t, "./configure $config_args";
push @extra_make_rules, "$moddir/mpl/include/mplconfig.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $moddir/mpl");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$moddir/mpl/libmpl.la: $moddir/mpl/include/mplconfig.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if(!-d "$moddir/openpa"){
    my $cmd = "cp -r src/openpa $moddir/openpa";
    print "$cmd\n";
    system $cmd;
    my $cmd = "cp -r confdb $moddir/openpa/";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$moddir/openpa/src";
$L_list .= " $moddir/openpa/src/libopa.la";
push @CONFIGS, "$moddir/openpa/src/opa_config.h";
my @t = ("cd $moddir/openpa");
push @t, "\x24(DO_stage) Configure OpenPA";
push @t, "autoreconf -ivf";
push @t, "./configure --disable-versioning --enable-embedded";
push @extra_make_rules, "$moddir/openpa/src/opa_config.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $moddir/openpa");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$moddir/openpa/src/libopa.la: $moddir/openpa/src/opa_config.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if(!-d "$moddir/hwloc"){
    my $cmd = "cp -r src/hwloc $moddir/hwloc";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$moddir/hwloc/include";
$L_list .= " $moddir/hwloc/hwloc/libhwloc_embedded.la";
push @CONFIGS, "$moddir/hwloc/include/hwloc/autogen/config.h";
my @t = ("cd $moddir/hwloc");
push @t, "\x24(DO_stage) Configure HWLOC";
push @t, "sh autogen.sh";
push @t, "./configure --enable-embedded-mode --enable-visibility";
push @extra_make_rules, "$moddir/hwloc/include/hwloc/autogen/config.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $moddir/hwloc");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$moddir/hwloc/hwloc/libhwloc_embedded.la: $moddir/hwloc/include/hwloc/autogen/config.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if(!$opts{disable_romio}){
    system "rsync -r confdb/ src/mpi/romio/confdb/";
    system "cp maint/version.m4 src/mpi/romio/";
    my @t_env;
    push @t_env, "FROM_MPICH=yes";
    push @t_env, "master_top_srcdir=$pwd";
    push @t_env, "master_top_builddir=$pwd";
    push @t_env, "CPPFLAGS='-I$moddir/mpl/include'";
    $I_list .= " -Isrc/mpi/romio/include";
    $L_list .= " src/mpi/romio/libromio.la";
    push @CONFIGS, "src/mpi/romio/adio/include/romioconf.h";
    my @t = ("cd src/mpi/romio");
    push @t, "\x24(DO_stage) Configure ROMIO";
    push @t, "autoreconf -ivf";
    push @t, "@t_env ./configure";
    push @extra_make_rules, "src/mpi/romio/adio/include/romioconf.h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my @t = ("cd src/mpi/romio");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "src/mpi/romio/libromio.la: src/mpi/romio/adio/include/romioconf.h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    $dst_hash{"src/mpi/romio/include/mpio.h"} = "$prefix/include";
    $dst_hash{"src/mpi/romio/include/mpiof.h"} = "$prefix/include";
}
if($opts{device}=~/ucx/){
    if(!-d "$moddir/ucx"){
        my $cmd = "cp -r src/mpid/ch4/netmod/ucx/ucx $moddir/ucx";
        print "$cmd\n";
        system $cmd;
    }
    $I_list .= " -I$moddir/ucx/src";
    $L_list .= " $moddir/ucx/src/ucp/libucp.la";
    push @CONFIGS, "$moddir/ucx/config.h";
    my @t = ("cd $moddir/ucx");
    push @t, "\x24(DO_stage) Configure UCX";
    push @t, "mkdir -p config/m4 config/aux";
    push @t, "autoreconf -iv";
    push @t, "./configure --disable-shared --with-pic";
    push @extra_make_rules, "$moddir/ucx/config.h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my @t = ("cd $moddir/ucx");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$moddir/ucx/src/ucp/libucp.la: $moddir/ucx/config.h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
}
if($opts{device}=~/ofi/){
    if(!-d "$moddir/libfabric"){
        my $cmd = "cp -r src/mpid/ch4/netmod/ofi/libfabric $moddir/libfabric";
        print "$cmd\n";
        system $cmd;
    }
    $I_list .= " -I$moddir/libfabric/include";
    $L_list .= " $moddir/libfabric/src/libfabric.la";
    push @CONFIGS, "$moddir/libfabric/config.h";
    my @t = ("cd $moddir/libfabric");
    push @t, "\x24(DO_stage) Configure libfabric";
    push @t, "sh autogen.sh";
    push @t, "./configure --enable-embedded --enable-sockets=yes --enable-psm=no --enable-psm2=no --enable-verbs=no --enable-usnic=no --enable-mlx=no --enable-gni=no --enable-ugni=no --enable-rxm=no --enable-mrail=no --enable-rxd=no --enable-bgq=no --enable-rstream=no --enable-udp=no --enable-perf=no";
    push @extra_make_rules, "$moddir/libfabric/config.h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my @t = ("cd $moddir/libfabric");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$moddir/libfabric/src/libfabric.la: $moddir/libfabric/config.h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
}
my $lt_opt;
if($opts{V}==0){
    $lt_opt = "--quiet";
}
%objects=();
my $tlist;
open In, "mymake/Makefile.orig" or die "Can't open mymake/Makefile.orig.\n";
while(<In>){
    if(/^(\w+)\s*=\s*(.*)/){
        my ($a, $b) = ($1, $2);
        $tlist=[];
        $objects{$a} = $tlist;
        my $done=1;
        if($b=~/\\$/){
            $done = 0;
            $b=~s/\s*\\$//;
        }
        if($b){
            push @$tlist, split /\s+/, $b;
        }
        if($done){
            undef $tlist;
        }
    }
    elsif($tlist){
        if(/\s*(.*)/){
            my ($b) = ($1);
            my $done=1;
            if($b=~/\\$/){
                $done = 0;
                $b=~s/\s*\\$//;
            }
            if($b){
                push @$tlist, split /\s+/, $b;
            }
            if($done){
                undef $tlist;
            }
        }
    }
}
close In;
open Out, ">mymake/Makefile.custom" or die "Can't write mymake/Makefile.custom.\n";
print "  --> [mymake/Makefile.custom]\n";
print Out "export MODDIR=$moddir\n";
print Out "PREFIX=$prefix\n";
print Out "\n";
if(@CONFIGS){
    my $l = "CONFIGS = @CONFIGS";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    print Out "\n";
}
my $t = get_object("DEFS");
my $l = "DEFS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("DEFAULT_INCLUDES");
my $l = "DEFAULT_INCLUDES = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("INCLUDES");
my $l = "INCLUDES = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CPPFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
my $l = "AM_CPPFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CPPFLAGS");
$t=~s/-I.*\/(mpl|openpa|romio)\/\S+\s*//g;
$t .= $I_list;
my $l = "CPPFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
my $l = "AM_CFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CFLAGS");
my $l = "CFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_LDFLAGS");
my $l = "AM_LDFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LDFLAGS");
my $l = "LDFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LIBS");
my $l = "LIBS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
print Out "\n";
my $cc = get_object("CC");
my $ccld = get_object("CCLD");
my $LD="\x24(LINK)";
print Out "COMPILE = $cc \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) \x24(AM_CFLAGS) \x24(CFLAGS)\n";
print Out "LINK = $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
print Out "LTCC = /bin/sh ./libtool --mode=compile $lt_opt \x24(COMPILE)\n";
print Out "LTLD = /bin/sh ./libtool --mode=link $lt_opt \x24(LINK)\n";
print Out "\n";
my $tlist = get_list("lib_LTLIBRARIES");
foreach my $t (@$tlist){
    $dst_hash{$t} = "\x24(PREFIX)/lib";
}
my $tlist = get_list("bin_PROGRAMS");
foreach my $t (@$tlist){
    if($t=~/mpichversion/){
        next;
    }
    $dst_hash{$t} = "\x24(PREFIX)/bin";
}
my $tlist = get_list("PROGRAMS");
foreach my $t (@$tlist){
    if($t=~/mpichversion/){
        next;
    }
    push @programs, $t;
}
my $tlist = get_list("LTLIBRARIES");
foreach my $t (@$tlist){
    push @ltlibs, $t;
}
print Out "all: @ltlibs @programs\n";
print Out "\n";
my $cmd = "\x24(LTLD)";
if($opts{V}==0){
    $cmd = "\@echo LTLD \$\@ && $cmd";
}
foreach my $p (@ltlibs){
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my ($deps, $objs);
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if($special_targets{$a}){
        foreach my $t (@tlist){
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else{
        foreach my $t (@tlist){
            $t=~s/[^\/]+-//;
        }
    }
    my @t;
    foreach my $t (@tlist){
        if($t=~/^-l\w+/){
            $objs.=" $t";
        }
        elsif($t=~/^-L\S+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        my $l = "    $t \\";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
    }
    my $l = "    $last_item";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LIBADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/\bsrc\/(mpl|openpa)\/\S+\s*//g;
        $t=~s/\bsrc\/mpi\/romio\/\S+\s*//g;
        $t=~s/\@ucxlib\@\s*//g;
        $t=~s/\@ofilib\@\s*//g;
        $t.= $L_list;
        $t=~s/^\s+//;
        my @tlist = split /\s+/, $t;
        my @t;
        foreach my $t (@tlist){
            if($t=~/^-l\w+/){
                $objs.=" $t";
            }
            elsif($t=~/^-L\S+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            my $l = "    $t \\";
            $l=~s/$moddir/\x24(MODDIR)/g;
            print Out "$l\n";
        }
        my $l = "    $last_item";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
        if(@CONFIGS and "$add"=~/_OBJECTS$/){
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
    }
    $objs = "$deps $objs \x24(LIBS)";
    if($dst_hash{$p}=~/\/lib$/){
        my $opt="-rpath $dst_hash{$p}";
        if($opts{so_version}){
            $opt.=" -version-info $opts{so_version}";
        }
        $objs = "$opt $objs";
    }
    print Out "$p: $deps\n";
    print Out "\t$cmd -o \$\@ $objs\n";
    print Out "\n";
}
my $cmd = "\x24(LTLD)";
if($opts{V}==0){
    $cmd = "\@echo LTLD \$\@ && $cmd";
}
foreach my $p (@programs){
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my ($deps, $objs);
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if($special_targets{$a}){
        foreach my $t (@tlist){
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else{
        foreach my $t (@tlist){
            $t=~s/[^\/]+-//;
        }
    }
    my @t;
    foreach my $t (@tlist){
        if($t=~/^-l\w+/){
            $objs.=" $t";
        }
        elsif($t=~/^-L\S+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        my $l = "    $t \\";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
    }
    my $l = "    $last_item";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LDADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/^\s+//;
        my @tlist = split /\s+/, $t;
        my @t;
        foreach my $t (@tlist){
            if($t=~/^-l\w+/){
                $objs.=" $t";
            }
            elsif($t=~/^-L\S+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            my $l = "    $t \\";
            $l=~s/$moddir/\x24(MODDIR)/g;
            print Out "$l\n";
        }
        my $l = "    $last_item";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
        if(@CONFIGS and "$add"=~/_OBJECTS$/){
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
    }
    if($objects{"${a}_CFLAGS"}){
        $cmd.= ' '. get_object("${a}_CFLAGS");
        $cmd .= " \x24(CFLAGS)";
    }
    if($objects{"${a}_LDFLAGS"}){
        $cmd.= ' '. get_object("${a}_LDFLAGS");
        $cmd .= " \x24(LDFLAGS)";
    }
    $objs = "$deps $objs \x24(LIBS)";
    if($dst_hash{$p}=~/\/lib$/){
        my $opt="-rpath $dst_hash{$p}";
        if($opts{so_version}){
            $opt.=" -version-info $opts{so_version}";
        }
        $objs = "$opt $objs";
    }
    print Out "$p: $deps\n";
    print Out "\t$cmd -o \$\@ $objs\n";
    print Out "\n";
}
print Out "\x23 --------------------\n";
foreach my $l (@extra_make_rules){
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
}
print Out "\x23 --------------------\n";
print Out "%.o: %.c\n";
if($opts{V}==0){
    print Out "\t\@echo CC \$\@ && \x24(COMPILE) -c -o \$\@ \$<\n";
}
else{
    print Out "\t\x24(COMPILE) -c -o \$\@ \$<\n";
}
print Out "\n";
print Out "%.lo: %.c\n";
if($opts{V}==0){
    print Out "\t\@echo LTCC \$\@ && \x24(LTCC) -c -o \$\@ \$<\n";
}
else{
    print Out "\t\x24(LTCC) -c -o \$\@ \$<\n";
}
print Out "\n";
while (my ($k, $v) = each %special_targets){
    print Out "%.$k.lo: %.c\n";
    if($opts{V}==0){
        print Out "\t\@echo LTCC \$\@ && $v -c -o \$\@ \$<\n";
    }
    else{
        print Out "\t$v -c -o \$\@ \$<\n";
    }
    print Out "\n";
}
my $t1 = get_list("include_HEADERS");
my $t2 = get_list("nodist_include_HEADERS");
if(@$t1 or @$t2){
    foreach my $t (@$t1, @$t2){
        $dst_hash{$t} = "$prefix/include";
    }
}
my (%dirs, @install_list, @install_deps, @lns_list);
while (my ($k, $v) = each %dst_hash){
    if($k=~/^LN_S-(.*)/){
        push @lns_list, "rm -f $1 && ln -s $v $1";
    }
    elsif($v){
        if(!$dirs{$v}){
            $dirs{$v} = 1;
        }
        if($v=~/\/lib$/){
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
            push @install_deps, $k;
        }
        elsif($v=~/\/bin$/){
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
            push @install_deps, $k;
        }
        elsif($v=~/\/include$/){
            push @install_list, "cp $k $v";
        }
    }
}
my @install_list = sort @install_list;
foreach my $d (keys %dirs){
    unshift @install_list, "mkdir -p $d";
}
push @install_list, sort @lns_list;
if(@install_list){
    print Out "\x23 --------------------\n";
    print Out ".PHONY: install\n";
    print Out "install: @install_deps\n";
    foreach my $l (@install_list){
        print Out "\t$l\n";
    }
    print Out "\n";
}
print Out "\x23 --------------------\n";
print Out ".PHONY: clean realclean realrealclean\n";
print Out "clean:\n";
print Out "\t(find . -name '*.o' -o -name '*.lo' -o -name '*.a' -o -name '*.la' |xargs rm -f)\n";
print Out "\n";
print Out "realclean: clean\n";
print Out "\t\x24(DO_clean)\n";
print Out "\n";
close Out;
system "rm -f Makefile";
system "ln -s mymake/Makefile.custom Makefile";
