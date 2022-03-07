#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our @config_args;
our %autoconf_vars;
our %make_vars;
our @ltlibs;
our @programs;
our %dst_hash;
our @CONFIGS;
our $I_list;
our $L_list;
our @extra_make_rules;
our %special_targets;
our @extra_DEFS;
our @extra_INCLUDES;
our %config_cflags;
our %config_ldflags;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my $what=shift @ARGV;
if (!$what) {
    $what = "mpich";
}
print "-- mymake_makefile $what ...\n";

if (-e "mymake/opts") {
    open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
    while(<In>){
        if (/^(\S+): (.*)/) {
            $opts{$1} = $2;
        }
    }
    close In;
}
open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
while(<In>){
    if (/^(\w+):\s*(.+)/) {
        $opts{$1} = $2;
    }
}
close In;
%make_vars = ();
@ltlibs = ();
@programs = ();

$make_vars{LIBTOOL} = "./libtool";
if (!$opts{CC}) {
    $make_vars{CC} = "gcc";
}
else {
    $make_vars{CC} = $opts{CC};
}
if (!$opts{CXX}) {
    $make_vars{CXX} = "g++";
}
else {
    $make_vars{CXX} = $opts{CXX};
}
if (!$opts{F77}) {
    $make_vars{F77} = "gfortran";
}
else {
    $make_vars{F77} = $opts{F77};
}
if (!$opts{FC}) {
    $make_vars{FC} = "gfortran";
}
else {
    $make_vars{FC} = $opts{FC};
}
$make_vars{CCLD} = $make_vars{CC};
$make_vars{CXXLD} = $make_vars{CXX};
$make_vars{FCLD} = $make_vars{FC};
$make_vars{DEFS} = "-DHAVE_CONFIG_H";

$make_vars{CFLAGS} = $opts{cflags};
$make_vars{LDFLAGS} = $opts{ldflags};
$make_vars{FFLAGS} = '-O2';
$make_vars{FCFLAGS} = '-O2';

$make_vars{EXEEXT}="";
$make_vars{OBJEXT}="o";

$make_vars{"MODS"} = "-";
$make_vars{"MODDIR"} = "-";
$make_vars{"PREFIX"} = "-";

if ($what eq "mpich") {
    $make_vars{DEFAULT_INCLUDES} = ("-I. -I./src/include");

    push @extra_make_rules, "DO_stage = perl $opts{mymake}_stage.pl";
    push @extra_make_rules, "DO_clean = perl $opts{mymake}_clean.pl";
    push @extra_make_rules, "DO_errmsg = perl $opts{mymake}_errmsg.pl";
    push @extra_make_rules, "DO_cvars = perl $opts{mymake}_cvars.pl";
    push @extra_make_rules, "DO_logs = perl $opts{mymake}_logs.pl";
    push @extra_make_rules, "DO_config = perl $opts{mymake}_config.pl";
    push @extra_make_rules, "DO_makefile = perl $opts{mymake}_makefile.pl";
    push @extra_make_rules, "";
    push @extra_make_rules, ".PHONY: test cvars errmsg realclean";
    push @extra_make_rules, "cvars:";
    push @extra_make_rules, "\t\x24(DO_cvars)";
    push @extra_make_rules, "";
    push @extra_make_rules, "errmsg:";
    push @extra_make_rules, "\t\x24(DO_errmsg)";
    push @extra_make_rules, "";
    push @extra_make_rules, "test:";
    push @extra_make_rules, "\t\x24(DO_config) dtpools && \x24(DO_makefile) dtpools && \x24(DO_config) test && \x24(DO_makefile) test";
    push @extra_make_rules, "";

    push @extra_make_rules, "realclean: clean";
    push @extra_make_rules, "\t\x24(DO_clean)";
    push @extra_make_rules, "";
    my $add="src/mpl/libmpl.la \x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la src/pm/hydra/Makefile";
    push @extra_make_rules, ".PHONY: hydra hydra-install";
    push @extra_make_rules, "";
    push @extra_make_rules, "src/pm/hydra/Makefile:";
    push @extra_make_rules, "\t\x24(DO_config) hydra && \x24(DO_makefile) hydra";
    push @extra_make_rules, "";
    push @extra_make_rules, "hydra: $add";
    push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) )";
    push @extra_make_rules, "";
    push @extra_make_rules, "hydra-install: $add";
    push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) install )";
    push @extra_make_rules, "";

    $opts{so_version}="0:0:0";
    if (!$opts{quick} && !-d "src/mpl/confdb") {
        my $cmd = "cp -r confdb src/mpl/";
        print "$cmd\n";
        system $cmd;
    }
    my $L=$opts{"with-mpl"};
    if ($L and -d $L) {
        $I_list .= " -I$L/include";
        $L_list .= " -L$L/lib -lmpl";
    }
    else {
        push @CONFIGS, "src/mpl/include/mplconfig.h";
        $I_list .= " -Isrc/mpl/include";
        $L_list .= " src/mpl/libmpl.la";
    }
    my $configure = "./configure --disable-versioning --enable-embedded";
    foreach my $t (@config_args) {
        if ($t=~/--enable-(g|strict)/) {
            $configure.=" $t";
        }
        elsif ($t=~/--with(out)?-(mpl|thread-package|argobots|uti|cuda)/) {
            $configure.=" $t";
        }
    }
    my $subdir="src/mpl";
    my $lib_la = "src/mpl/libmpl.la";
    my $config_h = "src/mpl/include/mplconfig.h";
    push @extra_make_rules, "$config_h:";
    push @extra_make_rules, "\t\x24(DO_config) mpl && \x24(DO_makefile) mpl";
    push @extra_make_rules, "";
    my @t = ("cd $subdir");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$lib_la: $config_h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my $L=$opts{"with-hwloc"};
    if ($L and -d $L) {
        $I_list .= " -I$L/include";
        $L_list .= " -L$L/lib -lhwloc";
    }
    else {
        push @CONFIGS, "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
        $I_list .= " -I\x24(MODDIR)/hwloc/include";
        $L_list .= " \x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
    }
    my $configure = "./configure --enable-embedded-mode --enable-visibility";
    my $subdir="\x24(MODDIR)/hwloc";
    my $lib_la = "\x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
    my $config_h = "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
    my $L=$opts{"with-yaksa"};
    if ($L and -d $L) {
        $I_list .= " -I$L/include";
        $L_list .= " -L$L/lib -lyaksa";
    }
    else {
        push @CONFIGS, "\x24(MODDIR)/yaksa/src/frontend/include/yaksa_config.h";
        $I_list .= " -I\x24(MODDIR)/yaksa/src/frontend/include";
        $L_list .= " \x24(MODDIR)/yaksa/libyaksa.la";
    }
    my $configure = "./configure";
    my $subdir="\x24(MODDIR)/yaksa";
    my $lib_la = "\x24(MODDIR)/yaksa/libyaksa.la";
    my $config_h = "\x24(MODDIR)/yaksa/src/frontend/include/yaksa_config.h";
    if (-f "maint/tuning/coll/json_gen.sh") {
        system "bash maint/tuning/coll/json_gen.sh";
        my $L=$opts{"with-jsonc"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -ljsonc";
        }
        else {
            push @CONFIGS, "\x24(MODDIR)/json-c/json.h";
            $I_list .= " -I\x24(MODDIR)/json-c";
            $L_list .= " \x24(MODDIR)/json-c/libjson-c.la";
        }
        my $configure = "./configure";
        my $subdir="\x24(MODDIR)/json-c";
        my $lib_la = "\x24(MODDIR)/json-c/libjson-c.la";
        my $config_h = "\x24(MODDIR)/json-c/json.h";
    }
    if ($opts{enable_izem}) {
        my $L=$opts{"with-izem"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lizem";
        }
        else {
            push @CONFIGS, "\x24(MODDIR)/izem/src/include/zm_config.h";
            $I_list .= " -I\x24(MODDIR)/izem/src/include";
            $L_list .= " \x24(MODDIR)/izem/src/libzm.la";
        }
        my $configure = "./configure --enable-embedded";
        my $subdir="\x24(MODDIR)/izem";
        my $lib_la = "\x24(MODDIR)/izem/src/libzm.la";
        my $config_h = "\x24(MODDIR)/izem/src/include/zm_config.h";
    }

    if (-f "src/pmi/configure.ac") {
        system "rsync -r confdb/ src/pmi/confdb/";
        system "cp maint/version.m4 src/pmi/";
        my $L=$opts{"with-pmi"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lpmi";
        }
        else {
            push @CONFIGS, "src/pmi/include/pmi_config.h";
            $I_list .= " -Isrc/pmi/include";
            $L_list .= " src/pmi/libpmi.la";
        }
        my @t_env;
        push @t_env, "FROM_MPICH=yes";
        push @t_env, "main_top_srcdir=$pwd";
        push @t_env, "main_top_builddir=$pwd";
        push @t_env, "CPPFLAGS='-I$opts{moddir}/src/mpl/include'";
        if ($opts{argobots}) {
            $t_env[-1] =~s/'$/ -I$opts{argobots}\/include'/;
        }
        my $configure = "@t_env ./configure --enable-embedded";
        my $subdir="src/pmi";
        my $lib_la = "src/pmi/libpmi.la";
        my $config_h = "src/pmi/include/pmi_config.h";
        push @extra_make_rules, "$config_h:";
        push @extra_make_rules, "\t\x24(DO_config) pmi && \x24(DO_makefile) pmi";
        push @extra_make_rules, "";
        my @t = ("cd $subdir");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$lib_la: $config_h";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
    }

    if (!$opts{disable_romio}) {
        system "rsync -r confdb/ src/mpi/romio/confdb/";
        system "cp maint/version.m4 src/mpi/romio/";
        my $L=$opts{"with-romio"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lromio";
        }
        else {
            push @CONFIGS, "src/mpi/romio/adio/include/romioconf.h";
            $I_list .= " -Isrc/mpi/romio/include";
            $L_list .= " src/mpi/romio/libromio.la";
        }
        my @t_env;
        push @t_env, "FROM_MPICH=yes";
        push @t_env, "main_top_srcdir=$pwd";
        push @t_env, "main_top_builddir=$pwd";
        push @t_env, "CPPFLAGS='-I$opts{moddir}/src/mpl/include'";
        if ($opts{argobots}) {
            $t_env[-1] =~s/'$/ -I$opts{argobots}\/include'/;
        }
        my $configure = "@t_env ./configure";
        my $subdir="src/mpi/romio";
        my $lib_la = "src/mpi/romio/libromio.la";
        my $config_h = "src/mpi/romio/adio/include/romioconf.h";

        $dst_hash{"src/mpi/romio/include/mpio.h"} = "$opts{prefix}/include";
        $dst_hash{"src/mpi/romio/include/mpiof.h"} = "$opts{prefix}/include";
    }
    if ($opts{device}=~/:ucx/ and (!$opts{"with-ucx"} or $opts{"with-ucx"} eq "embedded")) {
        my $ucxdir="$opts{moddir}/ucx";
        if (-e "$ucxdir/need_sed") {
            print "Patch $ucxdir ...\n";
            system "find $ucxdir -name '*.la' | xargs sed -i \"s,MODDIR,$ucxdir,g\"";
            system "find $ucxdir -name '*.la*' | xargs sed -i \"s,/MODPREFIX,$opts{prefix},g\"";
            system "mkdir -p $opts{prefix}/lib/ucx";
            $ENV{LIBRARY_PATH}="$opts{prefix}/lib:$opts{prefix}/lib/ucx:$ENV{LIBRARY_PATH}";
            foreach my $m ("ucm", "ucs", "uct", "ucp") {
                system "$ucxdir/libtool --mode=install --quiet install $ucxdir/src/$m/lib$m.la $opts{prefix}/lib";
            }
            my @tlist = glob("$ucxdir/modules/*.la");
            foreach my $m (@tlist) {
                open In, "$m" or die "Can't open $m: $!\n";
                while(<In>){
                    if (/relink_command="\(cd \S+ucx.(src.\S+);/) {
                        my $dir = "$1";
                        $m=~s/modules/$dir/;
                    }
                }
                close In;
                system "$ucxdir/libtool --mode=install --quiet install $m $opts{prefix}/lib/ucx";
            }
            unlink "$ucxdir/need_sed";
        }

        if (!$opts{quick}) {
        }

        if ($ENV{compiler} =~ /pgi|sun/) {
            my @lines;
            open In, "$opts{moddir}/ucx/src/ucs/type/status.h" or die "Can't open $opts{moddir}/ucx/src/ucs/type/status.h: $!\n";
            while(<In>){
                s/UCS_S_PACKED\s*ucs_status_t/ucs_status_t/;
                push @lines, $_;
            }
            close In;
            open Out, ">$opts{moddir}/ucx/src/ucs/type/status.h" or die "Can't write $opts{moddir}/ucx/src/ucs/type/status.h: $!\n";
            print Out @lines;
            close Out;
        }
        my $L=$opts{"with-ucx"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lucx";
        }
        else {
            push @CONFIGS, "\x24(MODDIR)/ucx/config.h";
            $I_list .= " -I\x24(MODDIR)/ucx/src";
            $L_list .= " \x24(PREFIX)/lib/libucp.la";
        }
        my $configure = "./configure --prefix=\x24(PREFIX) --disable-static";
        my $subdir="\x24(MODDIR)/ucx";
        my $lib_la = "\x24(MODDIR)/ucx/src/ucp/libucp.la";
        my $config_h = "\x24(MODDIR)/ucx/config.h";
    }
    elsif ($opts{device}=~/ch4:ofi/ and (!$opts{"with-libfabric"} or $opts{"with-libfabric"} eq "embedded")) {
        my $L=$opts{"with-ofi"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lofi";
        }
        else {
            push @CONFIGS, "\x24(MODDIR)/libfabric/config.h";
            $I_list .= " -I\x24(MODDIR)/libfabric/include";
            $L_list .= " \x24(MODDIR)/libfabric/src/libfabric.la";
        }
        my $configure = "./configure --enable-embedded";
        my $subdir="\x24(MODDIR)/libfabric";
        my $lib_la = "\x24(MODDIR)/libfabric/src/libfabric.la";
        my $config_h = "\x24(MODDIR)/libfabric/config.h";
    }
    elsif ($opts{device}=~/ch3.*:ofi/ and (!$opts{"with-ofi"} or $opts{"with-ofi"} eq "embedded")) {
        my $L=$opts{"with-ofi"};
        if ($L and -d $L) {
            $I_list .= " -I$L/include";
            $L_list .= " -L$L/lib -lofi";
        }
        else {
            push @CONFIGS, "\x24(MODDIR)/libfabric/config.h";
            $I_list .= " -I\x24(MODDIR)/libfabric/include";
            $L_list .= " \x24(MODDIR)/libfabric/src/libfabric.la";
        }
        my $configure = "./configure --enable-embedded";
        my $subdir="\x24(MODDIR)/libfabric";
        my $lib_la = "\x24(MODDIR)/libfabric/src/libfabric.la";
        my $config_h = "\x24(MODDIR)/libfabric/config.h";
    }

    push @extra_make_rules, "cpi: ";
    push @extra_make_rules, "\tmpicc -o cpi examples/cpi.c";
    push @extra_make_rules, "";
    if ($opts{device} =~/ch4/) {
        push @extra_make_rules, "send_OBJECTS = \\";
        foreach my $a ("send", "isend", "rsend", "irsend", "ssend", "issend", "send_init", "rsend_init", "ssend_init", "bsend_init", "sendrecv", "sendrecv_rep", "bsendutil") {
            push @extra_make_rules, "    src/mpi/pt2pt/$a.lo \\";
        }
        foreach my $a ("coll/helper_fn", "request/cancel", "init/init_async") {
            push @extra_make_rules, "    src/mpi/$a.lo \\";
        }
        $extra_make_rules[-1] =~s/\s\\$//;
        push @extra_make_rules, "";

        my $dep = "src/mpid/ch4/src/ch4_send.h";
        if ($opts{device}=~/ofi/) {
            $dep .= " src/mpid/ch4/netmod/ofi/ofi_send.h";
        }
        push @extra_make_rules, "\x24(send_OBJECTS): $dep";
        push @extra_make_rules, "";
        push @extra_make_rules, "recv_OBJECTS = \\";
        foreach my $a ("recv", "irecv", "mrecv", "imrecv", "recv_init", "sendrecv", "sendrecv_rep") {
            push @extra_make_rules, "    src/mpi/pt2pt/$a.lo \\";
        }
        foreach my $a ("coll/helper_fn", "request/cancel", "request/mpir_request", "init/init_async") {
            push @extra_make_rules, "    src/mpi/$a.lo \\";
        }
        $extra_make_rules[-1] =~s/\s\\$//;
        push @extra_make_rules, "";

        my $dep = "src/mpid/ch4/src/ch4_recv.h";
        if ($opts{device}=~/ofi/) {
            $dep .= " src/mpid/ch4/netmod/ofi/ofi_recv.h";
        }
        push @extra_make_rules, "\x24(recv_OBJECTS): $dep";
        push @extra_make_rules, "";
        push @extra_make_rules, "probe_OBJECTS = \\";
        foreach my $a ("probe", "iprobe", "mprobe", "improbe") {
            push @extra_make_rules, "    src/mpi/pt2pt/$a.lo \\";
        }
        foreach my $a ("coll/helper_fn") {
            push @extra_make_rules, "    src/mpi/$a.lo \\";
        }
        $extra_make_rules[-1] =~s/\s\\$//;
        push @extra_make_rules, "";

        my $dep = "src/mpid/ch4/src/ch4_probe.h";
        if ($opts{device}=~/ofi/) {
            $dep .= " src/mpid/ch4/netmod/ofi/ofi_probe.h";
        }
        push @extra_make_rules, "\x24(probe_OBJECTS): $dep";
        push @extra_make_rules, "";
    }

    push @extra_make_rules, "src/mpi/errhan/errutil.lo: src/mpi/errhan/defmsg.h";
    push @extra_make_rules, "src/mpi/errhan/defmsg.h:";
    push @extra_make_rules, "\t\x24(DO_errmsg)";
    push @extra_make_rules, "";
    push @CONFIGS, "src/include/mpichconf.h";
    push @CONFIGS, "src/include/mpir_cvars.h";
    push @extra_make_rules, "src/include/mpir_cvars.h:";
    push @extra_make_rules, "\t\x24(DO_cvars)";
    push @extra_make_rules, "";
    if (-f "src/include/autogen.h.in") {
        push @CONFIGS, "src/include/autogen.h";
        push @extra_make_rules, "src/include/autogen.h: src/include/autogen.h.in";
        push @extra_make_rules, "\tperl maint/gen_init.pl";
        push @extra_make_rules, "";
    }

    my @t = ("cd src/glue/romio");
    push @t, "perl all_romio_symbols ../../mpi/romio/include/mpio.h.in";
    push @extra_make_rules, "src/glue/romio/all_romio_symbols.c: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";

    if ($ENV{EXTRA_LIB}) {
        $L_list .= " $ENV{EXTRA_LIB}";
    }

    if ($opts{do_pmpi}) {
        $special_targets{lib_libmpi_la}="\x24(LTCC) -DMPICH_MPI_FROM_PMPI";
    }

    my $bin="\x24(PREFIX)/bin";
    $dst_hash{"mymake/mpicc"}=$bin;

    $autoconf_vars{MPILIBNAME} = "mpi";
    $autoconf_vars{MPIFCLIBNAME} = "mpifort";
    $autoconf_vars{MPICXXLIBNAME} = "mpicxx";

    $autoconf_vars{VISIBILITY_CFLAGS} = "-fvisibility=hidden";

    if (!$opts{"disable-ch4-netmod-inline"}) {
        if ($opts{device} =~/ch4:ofi/) {
            $make_vars{CPPFLAGS} = "-DNETMOD_INLINE=__netmod_inline_ofi__ ";
        }
        elsif ($opts{device} =~/ch4:ucx/) {
            $make_vars{CPPFLAGS} = "-DNETMOD_INLINE=__netmod_inline_ucx__ ";
        }
    }

    $make_vars{CPPFLAGS}.="-D_REENTRANT ";

    my %conds;
    open In, "mymake/make_conds.mpich" or die "Can't open mymake/make_conds.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*([01])/) {
            $conds{$1} = $2;
        }
    }
    close In;
    load_automake("Makefile.am", \%conds);

    if (!$opts{disable_cxx}) {
        $dst_hash{"src/binding/cxx/mpicxx.h"}="$opts{prefix}/include";
    }
    if (!$opts{disable_fortran}) {
        push @extra_make_rules, "src/binding/fortran/use_mpi/mpi.lo: src/binding/fortran/use_mpi/mpi_constants.lo src/binding/fortran/use_mpi/mpi_sizeofs.lo src/binding/fortran/use_mpi/mpi_base.lo";
        push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_base.lo: src/binding/fortran/use_mpi/mpi_constants.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_sizeofs.lo: src/binding/fortran/use_mpi/mpifnoext.h", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_constants.lo: src/binding/fortran/use_mpi/mpifnoext.h", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi/mpifnoext.h: src/binding/fortran/mpif_h/mpif.h";
        push @extra_make_rules, "\tsed -e 's/^C/!/g' -e '/EXTERNAL/d' -e '/MPI_WTICK/d' \$< > \$@";
        push @extra_make_rules, "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_c_interface.lo: src/binding/fortran/use_mpi_f08/mpi_c_interface_nobuf.lo src/binding/fortran/use_mpi_f08/mpi_c_interface_cdesc.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_c_interface_nobuf.lo: src/binding/fortran/use_mpi_f08/mpi_c_interface_glue.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_c_interface_glue.lo: src/binding/fortran/use_mpi_f08/mpi_f08.lo", "";

        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_f08.lo: src/binding/fortran/use_mpi_f08/pmpi_f08.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/pmpi_f08.lo: src/binding/fortran/use_mpi_f08/mpi_f08_callbacks.lo src/binding/fortran/use_mpi_f08/mpi_f08_link_constants.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_f08_callbacks.lo: src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo: src/binding/fortran/use_mpi_f08/mpi_f08_types.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_f08_link_constants.lo: src/binding/fortran/use_mpi_f08/mpi_f08_types.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_f08_types.lo: src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/mpi_c_interface_cdesc.lo: src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo src/binding/fortran/use_mpi_f08/mpi_f08_link_constants.lo", "";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/wrappers_f/f_sync_reg_f08ts.lo: src/binding/fortran/use_mpi_f08/mpi_f08.lo";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/wrappers_f/pf_sync_reg_f08ts.lo: src/binding/fortran/use_mpi_f08/mpi_f08.lo";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/wrappers_f/f08ts.lo: src/binding/fortran/use_mpi_f08/mpi_f08.lo";
        push @extra_make_rules, "src/binding/fortran/use_mpi_f08/wrappers_f/pf08ts.lo: src/binding/fortran/use_mpi_f08/mpi_f08.lo";
        $dst_hash{"src/binding/fortran/mpif_h/mpif.h"}="$opts{prefix}/include";
        my $U="src/binding/fortran";
        $make_vars{AM_FCFLAGS} = "-I$U/use_mpi";
        my @mods;
        push @mods, "$U/use_mpi/mpi.mod";
        push @mods, "$U/use_mpi/mpi_sizeofs.mod";
        push @mods, "$U/use_mpi/mpi_constants.mod";
        push @mods, "$U/use_mpi/mpi_base.mod";
        if ($opts{f08}) {
            push @mods, "$U/use_mpi/pmpi_f08.mod";
            push @mods, "$U/use_mpi/mpi_f08.mod";
            push @mods, "$U/use_mpi/mpi_f08_callbacks.mod";
            push @mods, "$U/use_mpi/mpi_f08_compile_constants.mod";
            push @mods, "$U/use_mpi/mpi_f08_link_constants.mod";
            push @mods, "$U/use_mpi/mpi_f08_types.mod";
            push @mods, "$U/use_mpi/mpi_c_interface_cdesc.mod";
            push @mods, "$U/use_mpi/mpi_c_interface_glue.mod";
            push @mods, "$U/use_mpi/mpi_c_interface_nobuf.mod";
            push @mods, "$U/use_mpi/mpi_c_interface_types.mod";
        }
        $make_vars{modinc_HEADERS} = join(' ', @mods);
    }

    if (1) {
        $make_vars{lib_libmpi_la_LIBADD} .= " $L_list";
    }

    if ($opts{"with-xpmem"}) {
        my $p = $opts{"with-xpmem"};
        if ($p=~/\w+\//) {
            $make_vars{CPPFLAGS} .= " -I$p/include";
            $make_vars{LDFLAGS} .= " -L$p/lib64";
        }
        $make_vars{LIBS} .= " -lxpmem";
    }

    dump_makefile("Makefile", "mymake");
}
elsif ($what eq "mpl") {
    $autoconf_vars{MPLLIBNAME} = "mpl";

    my %conds;
    $conds{MPL_EMBEDDED_MODE} = 1;
    if ($opts{"with-cuda"}) {
        my $p = $opts{"with-cuda"};
        $conds{MPL_HAVE_CUDA} = 1;
        $make_vars{CPPFLAGS} .= " -I$p/include";
        $make_vars{LDFLAGS} .= " -L$p/lib64";
        $make_vars{LIBS} .= " -lcudart -lcuda";
    }
    load_automake("src/mpl/Makefile.am", \%conds);
    @programs=();
    dump_makefile("src/mpl/Makefile");
}
elsif ($what eq "pmi") {

    my %conds;
    $conds{EMBEDDED_MODE} = 1;
    $autoconf_vars{mpl_includedir} = "-I../mpl/include";

    load_automake("src/pmi/Makefile.am", \%conds);
    @programs=();
    dump_makefile("src/pmi/Makefile");
}
elsif ($what eq "opa") {
    $autoconf_vars{OPALIBNAME} = "opa";
    $make_vars{DEFAULT_INCLUDES} = "-I.";
    my %conds;
    $conds{EMBEDDED} = 1;
    load_automake("mymake/openpa/src/Makefile.am", \%conds);
    @programs=();
    dump_makefile("mymake/openpa/src/Makefile");
}
elsif ($what eq "hydra") {
    my $L=$opts{"with-mpl_hydra"};
    if ($L and -d $L) {
        $I_list .= " -I$L/include";
        $L_list .= " -L$L/lib -lmpl_hydra";
    }
    else {
        push @CONFIGS, "../../../src/mpl/include/mplconfig.h";
        $I_list .= " -I../../../src/mpl/include";
        $L_list .= " ../../../src/mpl/libmpl.la";
    }
    push @extra_make_rules, "../../../src/mpl/libmpl.la:";
    push @extra_make_rules, "\t\x24(MAKE) -C ../../.. src/mpl/libmpl.la";
    my $L=$opts{"with-hwloc"};
    if ($L and -d $L) {
        $I_list .= " -I$L/include";
        $L_list .= " -L$L/lib -lhwloc";
    }
    else {
        push @CONFIGS, "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
        $I_list .= " -I\x24(MODDIR)/hwloc/include";
        $L_list .= " \x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
    }
    my $configure = "./configure --enable-embedded-mode --enable-visibility";
    my $subdir="\x24(MODDIR)/hwloc";
    my $lib_la = "\x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
    my $config_h = "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
    my %conds;
    $conds{HYDRA_HAVE_HWLOC}=1;
    $conds{hydra_have_hwloc}=1;
    $conds{hydra_bss_external}=1;
    $conds{hydra_bss_persist}=1;
    $conds{hydra_have_poll}=1;
    $conds{hydra_have_select}=1;
    $conds{hydra_have_port}=1;
    $conds{hydra_pm_pmiserv}=1;
    $conds{hydra_ui_mpich}=1;

    $make_vars{DEFAULT_INCLUDES} = ("-I. -I./include");
    load_automake("src/pm/hydra/Makefile.am", \%conds);

    $make_vars{libhydra_la_LIBADD} .= " $L_list";
    foreach my $a ("hydra_nameserver", "hydra_persist", "hydra_pmi_proxy", "mpiexec_hydra") {
        $make_vars{"${a}_LDADD"} =~s/-l(hydra|pm)/lib$1.la/g;
    }
    my $bin="\x24(PREFIX)/bin";
    $dst_hash{"LN_S-$bin/mpiexec"}="$bin/mpiexec.hydra";
    $dst_hash{"LN_S-$bin/mpirun"}="$bin/mpiexec.hydra";

    dump_makefile("src/pm/hydra/Makefile", "../../../mymake");
}
elsif ($what eq "test") {
    my %conds;
    $autoconf_vars{threadlib} = "-lpthread";
    my @all_am = glob("test/mpi/*/Makefile.am");
    push @all_am, glob("test/mpi/threads/*/Makefile.am");
    push @all_am, glob("test/mpi/errors/*/Makefile.am");
    push @all_am, glob("test/mpi/impls/mpich/comm/Makefile.am");
    foreach my $a (@all_am) {
        my $dir;
        if ($a =~ /test\/mpi\/(.*)\/Makefile.am/) {
            $dir = $1;
            my @t = glob("test/mpi/$dir/*/Makefile.am");
            if (@t) {
                next;
            }
        }
        else {
            next;
        }

        %make_vars = ();
        @ltlibs = ();
        @programs = ();

        $make_vars{LIBTOOL} = "./libtool";
        if (!$opts{CC}) {
            $make_vars{CC} = "gcc";
        }
        else {
            $make_vars{CC} = $opts{CC};
        }
        if (!$opts{CXX}) {
            $make_vars{CXX} = "g++";
        }
        else {
            $make_vars{CXX} = $opts{CXX};
        }
        if (!$opts{F77}) {
            $make_vars{F77} = "gfortran";
        }
        else {
            $make_vars{F77} = $opts{F77};
        }
        if (!$opts{FC}) {
            $make_vars{FC} = "gfortran";
        }
        else {
            $make_vars{FC} = $opts{FC};
        }
        $make_vars{CCLD} = $make_vars{CC};
        $make_vars{CXXLD} = $make_vars{CXX};
        $make_vars{FCLD} = $make_vars{FC};
        $make_vars{DEFS} = "-DHAVE_CONFIG_H";

        $make_vars{CFLAGS} = $opts{cflags};
        $make_vars{LDFLAGS} = $opts{ldflags};
        $make_vars{FFLAGS} = '-O2';
        $make_vars{FCFLAGS} = '-O2';

        $make_vars{EXEEXT}="";
        $make_vars{OBJEXT}="o";

        $make_vars{"MODS"} = "-";
        $make_vars{"MODDIR"} = "-";
        $make_vars{"PREFIX"} = "-";
        my $top_srcdir = $dir;
        $top_srcdir=~s/[^\/]+/../g;
        $make_vars{top_srcdir}=$top_srcdir;
        load_automake("test/mpi/$dir/Makefile.am", \%conds);

        @extra_make_rules=();
        push @extra_make_rules, "$top_srcdir/dtpools/src/libdtpools.la:";
        push @extra_make_rules, "\t(cd $top_srcdir/dtpools/src && \x24(MAKE) libdtpools.la)";
        push @extra_make_rules, "";
        push @extra_make_rules, "$top_srcdir/util/libmtest_single.la:";
        push @extra_make_rules, "\t(cd $top_srcdir/util && \x24(MAKE) libmtest_single.la)";
        push @extra_make_rules, "";
        push @extra_make_rules, "$top_srcdir/util/libdtypes.la:";
        push @extra_make_rules, "\t(cd $top_srcdir/util && \x24(MAKE) libdtypes.la)";
        push @extra_make_rules, "";

        if ($opts{"with-cuda"}) {
            my $p = $opts{"with-cuda"};
            $conds{HAVE_CUDA} = 1;
            $make_vars{CPPFLAGS} .= " -I$p/include";
            $make_vars{LDFLAGS} .= " -L$p/lib64";
            $make_vars{LIBS} .= " -lcudart -lcuda";
        }

        $make_vars{LIBTOOL} = "$top_srcdir/libtool";
        $make_vars{CC} = "mpicc";
        $make_vars{CCLD} = "mpicc";
        dump_makefile("test/mpi/$dir/Makefile");
    }
}
elsif ($what eq "dtpools") {
    my %conds;
    $autoconf_vars{DTP_DATATYPES} = "MPI_INT,MPI_INT:4+MPI_DOUBLE:8";
    load_automake("test/mpi/dtpools/src/Makefile.am", \%conds);

    $make_vars{INCLUDES} = "-I../include";
    $make_vars{LIBTOOL} = "/bin/sh ../libtool";

    dump_makefile("test/mpi/dtpools/src/Makefile");
}
else {
    die "[$what] not implemented\n";
}

# ---- subroutines --------------------------------------------
sub load_automake {
    my ($file, $cond_hash) = @_;
    my $cwd;
    if ($file=~/^(.*)\/Makefile.am/) {
        my ($dir) = ($1);
        $cwd = Cwd::getcwd();
        chdir $dir or die "load_automake: can't chdir $dir\n";
        $file="Makefile.am";
    }

    my @lines;
    my ($skip, @stack);
    open In, "$file" or die "Can't open $file: $!\n";
    while(<In>){
        if (/^if\s+(\w+)/) {
            push @stack, $skip;
            if (!$skip) {
                $skip = !$cond_hash->{$1};
            }
            next;
        }
        elsif (/^else\b/) {
            if (!$stack[-1]) {
                $skip = !$skip;
            }
            next;
        }
        if (/^endif\b/) {
            $skip = pop @stack;
            next;
        }

        if (!$skip) {
            push @lines, $_;
        }
    }
    close In;
    if (!$make_vars{top_srcdir}) {
        $make_vars{top_srcdir} = ".";
    }
    my $prev;
    foreach (@lines) {
        s/\x24\(top_srcdir\)/$make_vars{top_srcdir}/g;
        s/\x24\(top_builddir\)/$make_vars{top_srcdir}/g;
        s/\@(\w+)\@/$autoconf_vars{$1}/g;
        if (/(.*)\\$/) {
            $prev .= "$1 ";
            next;
        }
        if ($prev) {
            $_ = "$prev $_";
            s/\s+/ /g;
            $prev = "";
        }

        if (/^include\s+(\S+)/) {
            load_automake($1, $cond_hash);
        }
        elsif (/^(\w+)_LTLIBRARIES\s*\+?=\s*(.*)/) {
            my ($dir, $t) = ($1, $2);
            foreach my $a (split /\s+/, $t) {
                push @ltlibs, $t;
                if ($dir ne "noinst") {
                    $dst_hash{$t} = "\x24(PREFIX)/$dir";
                }
            }
        }
        elsif (/^(\w+)_PROGRAMS\s*\+?=\s*(.*)/) {
            my ($dir, $t) = ($1, $2);
            foreach my $a (split /\s+/, $t) {
                push @programs, $a;
                if ($dir ne "noinst") {
                    $dst_hash{$a} = "\x24(PREFIX)/$dir";
                }
            }
        }
        elsif (/^(\w+)\s*\+?=\s*(.*)/) {
            $make_vars{$1}.="$2 ";
        }
    }

    if ($cwd) {
        chdir $cwd or die "Can't chdir [$cwd]\n";
    }
}

sub dump_makefile {
    my ($makefile, $moddir) = @_;

    my ($lt, $lt_opt);
    $lt = get_make_var("LIBTOOL");
    if (!$opts{V}) {
        $lt_opt = "--quiet";
    }

    open Out, ">$makefile" or die "Can't write $makefile: $!\n";
    print "  --> [$makefile]\n";
    print Out "PREFIX=$opts{prefix}\n";
    if ($moddir) {
        print Out "MODDIR=$moddir\n";
    }
    print Out "\n";
    print Out "CONFIGS = @CONFIGS\n";
    print Out "\n";
    my $t = get_make_var_unique("DEFS");
    $t .= " @extra_DEFS";
    print Out "DEFS = $t\n";
    my $t = get_make_var_unique("DEFAULT_INCLUDES");
    print Out "DEFAULT_INCLUDES = $t\n";
    my $t = get_make_var_unique("INCLUDES");
    $t .= " @extra_INCLUDES";
    print Out "INCLUDES = $t\n";
    my $t = get_make_var_unique("AM_CPPFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    if ($makefile eq "Makefile") {
        $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
        $t=~s/-I\S+\/ucx\/src//g;
        $t=~s/-I\S+\/json-c//g;
    }
    elsif ($makefile =~/hydra/) {
        $t=~s/-I\S+\/(mpl)\/\S+\s*//g;
    }
    print Out "AM_CPPFLAGS = $t\n";
    my $t = get_make_var_unique("CPPFLAGS");
    if ($opts{"with-cuda"}) {
        my $p = $opts{"with-cuda"};
        $I_list .= " -I$p/include";
    }
    $t=~s/\@HWLOC_\S+\@\s*//;
    if ($makefile eq "Makefile") {
        $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
        $t=~s/-I\S+\/ucx\/src//g;
        $t=~s/-I\S+\/json-c//g;
    }
    elsif ($makefile =~/hydra/) {
        $t=~s/-I\S+\/(mpl)\/\S+\s*//g;
    }
    $t .= $I_list;
    print Out "CPPFLAGS = $t\n";
    my $t = get_make_var_unique("AM_CFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    print Out "AM_CFLAGS = $t\n";
    my $t = get_make_var_unique("CFLAGS");
    if (%config_cflags) {
        my @tlist = split /\s+/, $t;
        foreach my $a (@tlist) {
            if ($a=~/-O(\d+)/) {
                if (!defined $config_cflags{O}) {
                    $config_cflags{O} = $1;
                }
            }
            elsif (!$config_cflags{$a}) {
                $config_cflags{$a} = 1;
            }
        }
        my @tlist;
        foreach my $a (keys %config_cflags) {
            if ($a eq "O") {
                push @tlist, "-O$config_cflags{O}";
            }
            else {
                push @tlist, $a;
            }
        }
        $t = join(' ', sort @tlist);
        print(STDOUT "  -->  CFLAGS = $t\n");
    }
    print Out "CFLAGS = $t\n";
    my $t = get_make_var_unique("AM_LDFLAGS");
    print Out "AM_LDFLAGS = $t\n";
    my $t = get_make_var_unique("LDFLAGS");
    if (%config_ldflags) {
        my @tlist = split /\s+/, $t;
        foreach my $a (@tlist) {
            if (!$config_ldflags{$a}) {
                $config_ldflags{$a} = 1;
            }
        }
        $t = join ' ', sort keys %config_ldflags;
        print(STDOUT "  -->  LDFLAGS = $t\n");
    }
    print Out "LDFLAGS = $t\n";
    my $t = get_make_var_unique("LIBS");
    print Out "LIBS = $t\n";
    print Out "\n";

    my $cc = get_make_var("CC");
    my $ccld = get_make_var("CCLD");

    print Out "COMPILE = $cc \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) \x24(AM_CFLAGS) \x24(CFLAGS)\n";
    print Out "LINK = $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    if ($lt) {
        print Out "LTCC = $lt --mode=compile $lt_opt \x24(COMPILE)\n";
        print Out "LTLD = $lt --mode=link $lt_opt \x24(LINK)\n";
    }
    print Out "\n";
    if (!$opts{disable_cxx}) {
        my $cxx = get_make_var("CXX");
        my $cxxld = get_make_var("CXXLD");
        my $flags = get_make_var("CXXFLAGS");
        my $am_flags = get_make_var("AM_CXXFLAGS");
        print Out "CXXCOMPILE = $cxx \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) $flags $am_flags\n";
        print Out "CXXLINK = $cxxld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        if ($lt) {
            print Out "LTCXX = $lt --mode=compile $lt_opt --tag=CXX \x24(CXXCOMPILE)\n";
            print Out "CXXLD = $lt --mode=link $lt_opt --tag=CXX $cxxld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        }
        print Out "\n";
    }
    if (!$opts{disable_fortran}) {
        my $fc = get_make_var("FC");
        my $flags = get_make_var("FCFLAGS");
        my $am_flags = get_make_var("AM_FCFLAGS");
        $flags.=" $am_flags";
        if ($flags=~/-I(\S+)/) {
            my ($modpath) = ($1);
            if ($fc =~/^(pgfortran|ifort)/) {
                $flags.=" -module $modpath";
            }
            elsif ($fc =~/^sunf\d+/) {
                $flags.=" -moddir=$modpath";
            }
            elsif ($fc =~/^af\d+/) {
                $flags.=" -YMOD_OUT_DIR=$modpath";
            }
            else {
                $flags.=" -J$modpath";
            }
        }
        print Out "FCCOMPILE = $fc $flags\n";
        if ($lt) {
            print Out "LTFC = $lt --mode=compile $lt_opt --tag=FC \x24(FCCOMPILE)\n";

            my $ld = get_make_var("FCLD");
            print Out "FCLD = $lt --mode=link $lt_opt --tag=FC $ld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        }
        print Out "\n";
    }

    foreach my $target (@ltlibs, @programs) {
        if ($target=~/^(lib|bin)\//) {
            $dst_hash{$target} = "\x24(PREFIX)/$1";
        }
    }

    print Out "all: @ltlibs @programs\n";
    print Out "\n";
    my %rules_ADD;
    if (@ltlibs) {
        foreach my $p (@ltlibs) {
            my $ld = "LINK";
            if ($lt) {
                $ld = "LTLD";
            }
            if ($p=~/libmpifort.la/) {
                $ld = "FCLD";
            }
            elsif ($p=~/libmpicxx.la/) {
                $ld = "CXXLD";
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/[\.\/]/_/g;

            my ($deps, $objs);
            my $t_cppflags = get_make_var("${a}_CPPFLAGS");
            my $o= "${a}_OBJECTS";
            my $tlist = get_make_objects($p);
            if ($special_targets{$a}) {
                foreach my $t (@$tlist) {
                    $t=~s/\.(l?o)$/.$a.$1/;
                }
            }

            my @t;
            foreach my $t (@$tlist) {
                if ($t=~/^-l\w+/) {
                    $objs.=" $t";
                }
                elsif ($t=~/^-L\S+/) {
                    $objs.=" $t";
                }
                else {
                    if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                        my $obj=$1;
                        if ($obj ne $a) {
                            $obj .= "_$a";
                            $t = "$obj.o";
                        }
                        print Out "$t: $1.c\n";
                        print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                    }
                    push @t, $t;
                }
            }

            if ($rules_ADD{$o}) {
                $deps .= " \x24($o)";
            }
            elsif ($#t > 1) {

                my $last_item = pop @t;
                if ($last_item) {
                    print Out "$o = \\\n";
                    foreach my $t (@t) {
                        if ($t) {
                            print Out "    $t \\\n";
                        }
                    }
                    print Out "    $last_item\n";
                }
                else {
                    print Out "$o =\n";
                }
                print Out "\n";

                if (@CONFIGS and "$o"=~/_OBJECTS$/) {
                    print Out "\x24($o): \x24(CONFIGS)\n";
                }
                $rules_ADD{$o} = 1;
                $deps .= " \x24($o)";
            }
            else {
                if ($o=~/_OBJECTS/) {
                    foreach my $t (@t) {
                        print Out "$t: \x24(CONFIGS)\n";
                    }
                }
                $deps .= " @t";
            }
            my $add = $a."_LIBADD";
            my $t = get_make_var($add);
            if (!$t) {
                $add = "LIBADD";
                $t = get_make_var($add);
            }

            if ($t) {
                $t=~s/^\s+//;
                my @tlist = split /\s+/, $t;
                my @t;
                foreach my $t (@tlist) {
                    if ($t=~/^-l\w+/) {
                        $objs.=" $t";
                    }
                    elsif ($t=~/^-L\S+/) {
                        $objs.=" $t";
                    }
                    else {
                        if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                            my $obj=$1;
                            if ($obj ne $a) {
                                $obj .= "_$a";
                                $t = "$obj.o";
                            }
                            print Out "$t: $1.c\n";
                            print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                        }
                        push @t, $t;
                    }
                }

                if ($rules_ADD{$add}) {
                    $deps .= " \x24($add)";
                }
                elsif ($#t > 1) {

                    my $last_item = pop @t;
                    if ($last_item) {
                        print Out "$add = \\\n";
                        foreach my $t (@t) {
                            if ($t) {
                                print Out "    $t \\\n";
                            }
                        }
                        print Out "    $last_item\n";
                    }
                    else {
                        print Out "$add =\n";
                    }
                    print Out "\n";

                    if (@CONFIGS and "$add"=~/_OBJECTS$/) {
                        print Out "\x24($add): \x24(CONFIGS)\n";
                    }
                    $rules_ADD{$add} = 1;
                    $deps .= " \x24($add)";
                }
                else {
                    if ($add=~/_OBJECTS/) {
                        foreach my $t (@t) {
                            print Out "$t: \x24(CONFIGS)\n";
                        }
                    }
                    $deps .= " @t";
                }
            }

            $objs = "$deps $objs \x24(LIBS)";

            if ($dst_hash{$p}=~/\/lib$/) {
                my $opt="-rpath $dst_hash{$p}";
                if ($opts{so_version}) {
                    $opt.=" -version-info $opts{so_version}";
                }
                $objs = "$opt $objs";
            }

            print Out "$p: $deps\n";
            print Out "\t$cmd -o \$\@ $objs\n";
            print Out "\n";
        }

    }
    if (@programs) {
        foreach my $p (@programs) {
            my $ld = "LINK";
            if ($lt) {
                $ld = "LTLD";
            }
            if ($p=~/libmpifort.la/) {
                $ld = "FCLD";
            }
            elsif ($p=~/libmpicxx.la/) {
                $ld = "CXXLD";
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/[\.\/]/_/g;

            my ($deps, $objs);
            my $t_cppflags = get_make_var("${a}_CPPFLAGS");
            my $o= "${a}_OBJECTS";
            my $tlist = get_make_objects($p, 1);
            if ($special_targets{$a}) {
                foreach my $t (@$tlist) {
                    $t=~s/\.(l?o)$/.$a.$1/;
                }
            }

            my @t;
            foreach my $t (@$tlist) {
                if ($t=~/^-l\w+/) {
                    $objs.=" $t";
                }
                elsif ($t=~/^-L\S+/) {
                    $objs.=" $t";
                }
                else {
                    if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                        my $obj=$1;
                        if ($obj ne $a) {
                            $obj .= "_$a";
                            $t = "$obj.o";
                        }
                        print Out "$t: $1.c\n";
                        print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                    }
                    push @t, $t;
                }
            }

            if ($rules_ADD{$o}) {
                $deps .= " \x24($o)";
            }
            elsif ($#t > 1) {

                my $last_item = pop @t;
                if ($last_item) {
                    print Out "$o = \\\n";
                    foreach my $t (@t) {
                        if ($t) {
                            print Out "    $t \\\n";
                        }
                    }
                    print Out "    $last_item\n";
                }
                else {
                    print Out "$o =\n";
                }
                print Out "\n";

                if (@CONFIGS and "$o"=~/_OBJECTS$/) {
                    print Out "\x24($o): \x24(CONFIGS)\n";
                }
                $rules_ADD{$o} = 1;
                $deps .= " \x24($o)";
            }
            else {
                if ($o=~/_OBJECTS/) {
                    foreach my $t (@t) {
                        print Out "$t: \x24(CONFIGS)\n";
                    }
                }
                $deps .= " @t";
            }
            my $add = $a."_LDADD";
            my $t = get_make_var($add);
            if (!$t) {
                $add = "LDADD";
                $t = get_make_var($add);
            }

            if ($t) {
                $t=~s/^\s+//;
                my @tlist = split /\s+/, $t;
                my @t;
                foreach my $t (@tlist) {
                    if ($t=~/^-l\w+/) {
                        $objs.=" $t";
                    }
                    elsif ($t=~/^-L\S+/) {
                        $objs.=" $t";
                    }
                    else {
                        if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                            my $obj=$1;
                            if ($obj ne $a) {
                                $obj .= "_$a";
                                $t = "$obj.o";
                            }
                            print Out "$t: $1.c\n";
                            print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                        }
                        push @t, $t;
                    }
                }

                if ($rules_ADD{$add}) {
                    $deps .= " \x24($add)";
                }
                elsif ($#t > 1) {

                    my $last_item = pop @t;
                    if ($last_item) {
                        print Out "$add = \\\n";
                        foreach my $t (@t) {
                            if ($t) {
                                print Out "    $t \\\n";
                            }
                        }
                        print Out "    $last_item\n";
                    }
                    else {
                        print Out "$add =\n";
                    }
                    print Out "\n";

                    if (@CONFIGS and "$add"=~/_OBJECTS$/) {
                        print Out "\x24($add): \x24(CONFIGS)\n";
                    }
                    $rules_ADD{$add} = 1;
                    $deps .= " \x24($add)";
                }
                else {
                    if ($add=~/_OBJECTS/) {
                        foreach my $t (@t) {
                            print Out "$t: \x24(CONFIGS)\n";
                        }
                    }
                    $deps .= " @t";
                }
            }
            my $t = get_make_var("${a}_CFLAGS");
            if ($t) {
                $cmd.= " $t";
                $cmd .= " \x24(CFLAGS)";
            }
            my $t = get_make_var("${a}_LDFLAGS");
            if ($t) {
                $cmd.= " $t";
                $cmd .= " \x24(LDFLAGS)";
            }

            $objs = "$deps $objs \x24(LIBS)";

            if ($dst_hash{$p}=~/\/lib$/) {
                my $opt="-rpath $dst_hash{$p}";
                if ($opts{so_version}) {
                    $opt.=" -version-info $opts{so_version}";
                }
                $objs = "$opt $objs";
            }

            print Out "$p: $deps\n";
            print Out "\t$cmd -o \$\@ $objs\n";
            print Out "\n";
        }

    }

    print Out "\x23 --------------------\n";
    foreach my $l (@extra_make_rules) {
        print Out "$l\n";
    }
    print Out "\x23 --------------------\n";
    print Out "%.o: %.c\n";
    if ($opts{V}==0) {
        print Out "\t\@echo CC \$\@ && \x24(COMPILE) -c -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(COMPILE) -c -o \$\@ \$<\n";
    }
    print Out "\n";
    print Out "%.i: %.c\n";
    if ($opts{V}==0) {
        print Out "\t\@echo CC -E \$\@ && \x24(COMPILE) -E -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(COMPILE) -E -o \$\@ \$<\n";
    }
    print Out "\n";
    if ($lt) {
        print Out "%.lo: %.c\n";
        if ($opts{V}==0) {
            print Out "\t\@echo LTCC \$\@ && \x24(LTCC) -c -o \$\@ \$<\n";
        }
        else {
            print Out "\t\x24(LTCC) -c -o \$\@ \$<\n";
        }
        print Out "\n";
        if (!$opts{disable_cxx}) {
            print Out "%.lo: %.cxx\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTCXX \$\@ && \x24(LTCXX) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTCXX) -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
        if (!$opts{disable_fortran}) {
            print Out "%.lo: %.f\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTFC \$\@ && \x24(LTFC) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTFC) -c -o \$\@ \$<\n";
            }
            print Out "\n";
            print Out "%.lo: %.f90\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTFC \$\@ && \x24(LTFC) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTFC) -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
        while (my ($k, $v) = each %special_targets) {
            print Out "%.$k.lo: %.c\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTCC \$\@ && $v -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t$v -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
    }
    my $t1 = get_make_var_list("include_HEADERS");
    my $t2 = get_make_var_list("nodist_include_HEADERS");
    my $t3 = get_make_var_list("modinc_HEADERS");
    if (@$t1 or @$t2 or @$t3) {
        foreach my $t (@$t1, @$t2, @$t3) {
            $t=~s/use_mpi_f08/use_mpi/;
            $dst_hash{$t} = "\x24(PREFIX)/include";
        }
    }

    my (%dirs, @install_list, @install_deps, @lns_list);
    foreach my $k (sort keys %dst_hash) {
        my $v = $dst_hash{$k};
        if ($k=~/^LN_S-(.*)/) {
            push @lns_list, "rm -f $1 && ln -s $v $1";
        }
        elsif ($v=~/noinst/) {
        }
        elsif ($v) {
            if (!$dirs{$v}) {
                $dirs{$v} = 1;
            }
            if ($v=~/\/lib$/) {
                push @install_list, "$lt --mode=install $lt_opt install $k $v";
                push @install_deps, $k;
            }
            elsif ($v=~/\/bin$/) {
                push @install_list, "$lt --mode=install $lt_opt install $k $v";
                push @install_deps, $k;
            }
            elsif ($v=~/\/include$/) {
                push @install_list, "cp $k $v";
            }
        }
    }

    foreach my $d (keys %dirs) {
        unshift @install_list, "mkdir -p $d";
    }
    push @install_list, sort @lns_list;

    if (@install_list) {
        print Out "\x23 --------------------\n";
        print Out ".PHONY: install\n";
        print Out "install: @install_deps\n";
        foreach my $l (@install_list) {
            print Out "\t$l\n";
        }
        print Out "\n";
    }
    print Out "\x23 --------------------\n";
    print Out ".PHONY: clean\n";
    print Out "clean:\n";
    print Out "\t(find src -name '*.o' -o -name '*.lo' -o -name '*.a' -o -name '*.la' |xargs rm -f)\n";
    print Out "\n";
    close Out;

}

sub get_make_var {
    my ($name) = @_;
    my $t = $make_vars{$name};
    if ($t eq "-") {
        return "\x24($name)";
    }
    elsif (defined $t) {
        $t=~s/\$\((\w+)\)/get_make_var($1)/ge;
        $t=~s/\s+/ /g;
        return $t;
    }
    else {
        my %dflt=(CC=>"gcc", CXX=>"g++", FC=>"gfortran");
        return $dflt{$name};
    }
}

sub get_make_var_unique {
    my ($name) = @_;
    my (@t, %cache);
    foreach my $k (split /\s+/, get_make_var($name)) {
        if (!$cache{$k}) {
            $cache{$k} = 1;
            push @t, $k;
        }
    }
    return join(' ', @t);
}

sub get_make_objects {
    my ($p, $is_program) = @_;
    my $a = $p;
    $a=~s/[\.\/]/_/g;

    my $t = get_make_var("${a}_SOURCES");
    $t .= get_make_var("dist_${a}_SOURCES");
    $t .= get_make_var("nodist_${a}_SOURCES");
    if (!$t) {
        $t = "$p.c";
    }
    my @tlist;
    foreach my $a (split /\s+/, $t) {
        if ($a=~/(.*)\.(c|f90)$/) {
            if ($is_program) {
                push @tlist, "$1.o";
            }
            else {
                push @tlist, "$1.lo";
            }
        }
    }
    @tlist = sort @tlist;
    return \@tlist;
}

sub get_make_var_list {
    my ($name) = @_;
    my (@tlist, %cache);
    foreach my $k (split /\s+/, get_make_var($name)) {
        if (!$k) {
            next;
        }
        if (!$cache{$k}) {
            $cache{$k} = 1;
            push @tlist, $k;
        }
    }
    return \@tlist;
}

