#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our @config_args;
our %hash_defines;
our %hash_undefs;
our %hash_define_val;
our $srcdir;
our $moddir;
our $prefix;
our $I_list;
our $L_list;
our %objects;
our @CONFIGS;
our @extra_DEFS;
our @extra_INCLUDES;
our %config_cflags;
our %dst_hash;
our @programs;
our @ltlibs;
our %special_targets;
our @extra_make_rules;
our %config_defines;
our %make_vars;

my $pwd=getcwd();
if ($0=~/^(\/.*)\//) {
    $opts{mymake} = $1;
}
elsif ($0=~/^(.*)\//) {
    $opts{mymake} .= "$pwd/$1";
}
$opts{mymake} .="/mymake";
if (-d "pm") {
    system "perl $opts{mymake}_hydra.pl @ARGV";
    exit(0);
}

foreach my $a (@ARGV) {
    if ($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/) {
        system "perl $opts{mymake}_$1.pl";
        exit(0);
    }
}
$hash_defines{"disable-ch4-ofi-ipv6"} = "MPIDI_CH4_OFI_SKIP_IPV6";
$hash_defines{"enable-ofi-domain"} = "MPIDI_OFI_VNI_USE_DOMAIN";
$hash_defines{"enable-legacy-ofi"} = "MPIDI_ENABLE_LEGACY_OFI";
$hash_defines{"enable-ch4-am-only"} = "MPIDI_ENABLE_AM_ONLY";

$hash_define_val{"with-ch4-max-vcis"} = "MPIDI_CH4_MAX_VCIS";

$hash_undefs{"disable-ofi-domain"} = "MPIDI_OFI_VNI_USE_DOMAIN";
$opts{V}=0;
$opts{ucx}="embedded";
$opts{libfabric}="embedded";
my $cnt_else = 0;
foreach my $a (@ARGV) {
    print "[$a]\n";
    if ($a=~/V=1/) {
        $opts{V} = 1;
    }
    elsif ($a=~/--enable-thread-cs=(.*)/) {
        my $cs = "GLOBAL";
        if ($1 eq "per-object" or $1 eq "per_object") {
            $cs = "POBJ";
        }
        elsif ($1 eq "per-vci" or $1 eq "per_vci") {
            $cs = "VCI";
        }
        $config_defines{MPICH_THREAD_GRANULARITY} = "MPICH_THREAD_GRANULARITY__$cs";
    }
    elsif ($a=~/--with-posix-mutex=(.*)/) {
        $config_defines{MPL_POSIX_MUTEX_NAME} = "MPL_POSIX_MUTEX_".uc($1);
    }
    elsif ($a=~/--enable-ch4-vci-method=(.*)/) {
        $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__".uc($1);
        if ($1 eq "communicator") {
            $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__COMM";
        }
    }
    elsif ($a=~/--enable-ch4-mt=(\w+)/) {
        if ($1 eq "direct") {
            $config_defines{MPIDI_CH4_USE_MT_DIRECT} = 1;
        }
        elsif ($1 eq "handoff") {
            $config_defines{MPIDI_CH4_USE_MT_HANDOFF} = 1;
        }
        elsif ($1 eq "runtime") {
            $config_defines{MPIDI_CH4_USE_MT_RUNTIME} = 1;
        }
    }
    elsif ($a=~/--((with|enable)-.*)=(.*)/ && $hash_define_val{$1}) {
        $config_defines{$hash_define_val{$1}} = $3;
    }
    elsif ($a=~/--((disable|enable)-.*)/ && ($hash_defines{$1} || $hash_undefs{$1})) {
        if ($hash_defines{$1}) {
            $config_defines{$hash_defines{$1}} = 1;
        }
        else {
            $config_defines{$hash_undefs{$1}} = undef;
        }
    }
    elsif ($a=~/--enable-g=(\S+)/) {
        my ($g) = ($1);
        if ($1 eq "most") {
            $g="dbg,log,mem,meminit,mutex,handle,handlealloc";
        }
        elsif ($1 eq "all") {
            $g="dbg,log,mem,meminit,mutex,handle,handlealloc,memarena";
        }
        foreach my $t (split /,/, $g) {
            if ($t eq "dbg" || $t eq "debug") {
                $config_cflags{"-g"} = 1;
            }
            elsif ($t eq "log") {
                $config_defines{MPL_USE_DBG_LOGGING} = 1;
            }
            elsif ($t eq "mem" or $t eq "memarena") {
                $config_defines{MPL_USE_MEMORY_TRACING} = 1;
                $config_defines{USE_MEMORY_TRACING} = 1;
                if ($t eq "memarena") {
                    $config_defines{MPICH_DEBUG_MEMARENA} = 1;
                }
            }
            elsif ($t eq "meminit") {
                $config_defines{MPICH_DEBUG_MEMINIT} = 1;
            }
            elsif ($t eq "mutex") {
                $config_defines{MPICH_DEBUG_MUTEX} = 1;
            }
            elsif ($t eq "handle") {
                $config_defines{MPICH_DEBUG_HANDLES} = 1;
            }
            elsif ($t eq "handlealloc") {
                $config_defines{MPICH_DEBUG_HANDLEALLOC} = 1;
            }
        }
    }
    elsif ($a=~/--enable-fast=(\S+)/) {
        my ($g) = ($1);
        if ($g =~ /O(\S)/) {
            $config_cflags{O} = $1;
        }
        if ($g=~/ndebug/) {
            $config_cflags{-DNDEBUG} = 1;
        }
        elsif ($g=~/all|yes/) {
            $config_cflags{-DNDEBUG} = 1;
            $config_cflags{O} = 2;
        }
        elsif ($g=~/no|none/) {
            $config_cflags{O} = 0;
        }
    }
    else {
        $cnt_else++;
    }
}

print "[filter_ARGV] $cnt_else ARGS\n";
if (!$cnt_else) {
    @ARGV = ();
}
my $need_save_args;
if (!@ARGV && -f "mymake/args") {
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
elsif (@ARGV) {
    $need_save_args = 1;
}
foreach my $a (@ARGV) {
    if ($a=~/^--(prefix)=(.*)/) {
        $opts{$1}=$2;
    }
    elsif ($a=~/^(\w+)=(.*)/) {
        $opts{$1}=$2;
    }
    elsif ($a=~/^--/) {
        if ($a=~/^--with-device=(.*)/) {
            $opts{device}=$1;
            push @config_args, $a;
        }
        elsif ($a=~/^--with-pm=(.*)/) {
            $opts{pm}=$1;
        }
        elsif ($a=~/--disable-(romio|cxx|fortran)/) {
            $opts{"disable_$1"}=1;
            $opts{"enable_$1"}=0;
            push @config_args, $a;
        }
        elsif ($a=~/--enable-fortran=(\w+)/) {
            $opts{disable_fortran}=0;
            $opts{enable_fortran}=$1;
            push @config_args, $a;
        }
        elsif ($a=~/--with-atomic-primitives=(.*)/) {
            $opts{openpa_primitives} = $1;
        }
        elsif ($a=~/--enable-strict/) {
            $opts{enable_strict} = 1;
            push @config_args, $a;
        }
        elsif ($a=~/--enable-izem-queue/) {
            $opts{enable_izem}=1;
            push @config_args, $a;
        }
        elsif ($a=~/--with-(ucx|libfabric|argobots)=(.*)/) {
            $opts{$1}=$2;
            push @config_args, $a;
        }
        elsif ($a=~/--enable-thread-cs=(.*)/) {
            my $cs = "GLOBAL";
            if ($1 eq "per-object" or $1 eq "per_object") {
                $cs = "POBJ";
            }
            elsif ($1 eq "per-vci" or $1 eq "per_vci") {
                $cs = "VCI";
            }
            $config_defines{MPICH_THREAD_GRANULARITY} = "MPICH_THREAD_GRANULARITY__$cs";
        }
        elsif ($a=~/--with-posix-mutex=(.*)/) {
            $config_defines{MPL_POSIX_MUTEX_NAME} = "MPL_POSIX_MUTEX_".uc($1);
        }
        elsif ($a=~/--enable-ch4-vci-method=(.*)/) {
            $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__".uc($1);
            if ($1 eq "communicator") {
                $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__COMM";
            }
        }
        elsif ($a=~/--enable-ch4-mt=(\w+)/) {
            if ($1 eq "direct") {
                $config_defines{MPIDI_CH4_USE_MT_DIRECT} = 1;
            }
            elsif ($1 eq "handoff") {
                $config_defines{MPIDI_CH4_USE_MT_HANDOFF} = 1;
            }
            elsif ($1 eq "runtime") {
                $config_defines{MPIDI_CH4_USE_MT_RUNTIME} = 1;
            }
        }
        elsif ($a=~/--((with|enable)-.*)=(.*)/ && $hash_define_val{$1}) {
            $config_defines{$hash_define_val{$1}} = $3;
        }
        elsif ($a=~/--((disable|enable)-.*)/ && ($hash_defines{$1} || $hash_undefs{$1})) {
            if ($hash_defines{$1}) {
                $config_defines{$hash_defines{$1}} = 1;
            }
            else {
                $config_defines{$hash_undefs{$1}} = undef;
            }
        }
        elsif ($a=~/--enable-g=(\S+)/) {
            my ($g) = ($1);
            if ($1 eq "most") {
                $g="dbg,log,mem,meminit,mutex,handle,handlealloc";
            }
            elsif ($1 eq "all") {
                $g="dbg,log,mem,meminit,mutex,handle,handlealloc,memarena";
            }
            foreach my $t (split /,/, $g) {
                if ($t eq "dbg" || $t eq "debug") {
                    $config_cflags{"-g"} = 1;
                }
                elsif ($t eq "log") {
                    $config_defines{MPL_USE_DBG_LOGGING} = 1;
                }
                elsif ($t eq "mem" or $t eq "memarena") {
                    $config_defines{MPL_USE_MEMORY_TRACING} = 1;
                    $config_defines{USE_MEMORY_TRACING} = 1;
                    if ($t eq "memarena") {
                        $config_defines{MPICH_DEBUG_MEMARENA} = 1;
                    }
                }
                elsif ($t eq "meminit") {
                    $config_defines{MPICH_DEBUG_MEMINIT} = 1;
                }
                elsif ($t eq "mutex") {
                    $config_defines{MPICH_DEBUG_MUTEX} = 1;
                }
                elsif ($t eq "handle") {
                    $config_defines{MPICH_DEBUG_HANDLES} = 1;
                }
                elsif ($t eq "handlealloc") {
                    $config_defines{MPICH_DEBUG_HANDLEALLOC} = 1;
                }
            }
        }
        elsif ($a=~/--enable-fast=(\S+)/) {
            my ($g) = ($1);
            if ($g =~ /O(\S)/) {
                $config_cflags{O} = $1;
            }
            if ($g=~/ndebug/) {
                $config_cflags{-DNDEBUG} = 1;
            }
            elsif ($g=~/all|yes/) {
                $config_cflags{-DNDEBUG} = 1;
                $config_cflags{O} = 2;
            }
            elsif ($g=~/no|none/) {
                $config_cflags{O} = 0;
            }
        }
        else {
            push @config_args, $a;
        }
    }
}

if ($opts{CC}) {
    $ENV{CC}=$opts{CC};
}
if ($opts{CXX}) {
    $ENV{CXX}=$opts{CXX};
}
if ($opts{F77}) {
    $ENV{F77}=$opts{F77};
}
if ($opts{FC}) {
    $ENV{FC}=$opts{FC};
}
if ($opts{srcdir}) {
    $srcdir = $opts{srcdir};
}
if ($opts{moddir}) {
    $moddir = $opts{moddir};
}
if ($opts{prefix}) {
    $prefix = $opts{prefix};
}
if (!$opts{prefix}) {
    $opts{prefix}="$pwd/_inst";
    system "mkdir -p $opts{prefix}";
}
my $mod_tarball;
if ($ENV{MODTARBALL}) {
    $mod_tarball = $ENV{MODTARBALL};
}
elsif (-e "modules.tar.gz") {
    $mod_tarball = "modules.tar.gz";
}
elsif (-e "mymake/modules.tar.gz") {
    $mod_tarball = "mymake/modules.tar.gz";
}
if ($ENV{MODDIR}) {
    $opts{moddir} = $ENV{MODDIR};
}
elsif (-d "mymake/hwloc") {
    $opts{moddir} = "$pwd/mymake";
}
elsif (-e $mod_tarball) {
    $opts{moddir} = "$pwd/mymake";
    my $cmd = "mkdir -p $opts{moddir}";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $opts{moddir} -xf $mod_tarball";
    print "$cmd\n";
    system $cmd;
}
else {
    die "moddir not set\n";
}
if (-f "./maint/version.m4") {
    $srcdir = ".";
}
elsif (-f "../maint/version.m4") {
    $srcdir = "..";
}
elsif (-f "../../maint/version.m4") {
    $srcdir = "../..";
}
elsif (-f "../../../maint/version.m4") {
    $srcdir = "../../..";
}
if (!$srcdir) {
    die "srcdir not set\n";
}
if ($srcdir ne ".") {
    chdir $srcdir or die "can't chdir $srcdir\n";
}
if (!-d "mymake") {
    mkdir "mymake" or die "can't mkdir mymake\n";
}
my $cvars_c = "src/util/mpir_cvars.c";
if (-f "src/util/cvar/Makefile.mk") {
    $cvars_c = "src/util/cvar/mpir_cvars.c";
}
if (!-f $cvars_c) {
    system "touch $cvars_c";
}
push @extra_make_rules, "DO_stage = perl $opts{mymake}_stage.pl";
push @extra_make_rules, "DO_clean = perl $opts{mymake}_clean.pl";
push @extra_make_rules, "DO_errmsg = perl $opts{mymake}_errmsg.pl";
push @extra_make_rules, "DO_cvars = perl $opts{mymake}_cvars.pl";
push @extra_make_rules, "DO_logs = perl $opts{mymake}_logs.pl";
push @extra_make_rules, "DO_hydra = perl $opts{mymake}_hydra.pl";
push @extra_make_rules, "DO_test = perl $opts{mymake}_test.pl";
push @extra_make_rules, "DO_mpi_h = perl $opts{mymake}_mpi_h.pl";
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

if ($need_save_args) {
    my $t = join(' ', @ARGV);
    open Out, ">mymake/args" or die "Can't write mymake/args: $!\n";
    print Out $t, "\n";
    close Out;
    system "rm -f mymake/Makefile.orig";
    system "rm -f $opts{moddir}/mpl/include/mplconfig.h $opts{moddir}/openpa/src/opa_config.h";

    $opts{config_args} = join(' ', @config_args);
    open Out, ">mymake/opts" or die "Can't write mymake/opts: $!\n";
    foreach my $k (sort keys %opts) {
        print Out "$k: $opts{$k}\n";
    }
    close Out;
}
print "srcdir: $srcdir\n";
print "moddir: $moddir\n";
print "prefix: $prefix\n";
if ($opts{device}) {
    print "device: $opts{device}\n";
}

if ($opts{pm} eq "gforker") {
    push @extra_make_rules,  "libmpiexec_la_OBJECTS = \\";
    foreach my $a (qw(cmnargs process ioloop pmiserv labelout env newsession rm pmiport dbgiface)) {
        push @extra_make_rules,  "    src/pm/util/$a.lo \\";
    }
    push @extra_make_rules,  "    src/pm/util/simple_pmiutil2.lo";
    push @extra_make_rules, "";

    my $objs = "\x24(libmpiexec_la_OBJECTS) \x24(MODDIR)/mpl/libmpl.la";
    push @extra_make_rules,  "libmpiexec.la: $objs";
    push @extra_make_rules,  "\t\@echo LTLD \$\@ && \x24(LTLD) -o \$\@ $objs";
    push @extra_make_rules, "";

    my $objs = "src/pm/gforker/mpiexec.o libmpiexec.la";
    push @extra_make_rules,  "mpiexec.gforker: $objs";
    push @extra_make_rules,  "\t\@echo LTLD \$\@ && \x24(LTLD) -o \$\@ $objs";
    push @extra_make_rules, "";

    push @extra_make_rules,  ".PHONY: gforker-install";
    push @extra_make_rules,  "gforker-install: mpiexec.gforker";
    my $bin = "\x24(PREFIX)/bin";
    push @extra_make_rules,  "\tinstall -d $bin";
    push @extra_make_rules,  "\t/bin/sh ./libtool --mode=install --quiet install mpiexec.gforker $bin";
    push @extra_make_rules,  "\trm -f $bin/mpiexec  && ln -s $bin/mpiexec.gforker $bin/mpiexec";
    push @extra_make_rules,  "\trm -f $bin/mpirun  && ln -s $bin/mpiexec.gforker $bin/mpirun";
    push @extra_make_rules, "";

    push @extra_INCLUDES, "-Isrc/pm/util";
    push @extra_DEFS, "-DHAVE_GETTIMEOFDAY -DUSE_SIGACTION";
}
elsif ($opts{pm} eq "remshell") {
    push @extra_make_rules,  "libmpiexec_la_OBJECTS = \\";
    foreach my $a (qw(cmnargs process ioloop pmiserv labelout env newsession rm pmiport dbgiface)) {
        push @extra_make_rules,  "    src/pm/util/$a.lo \\";
    }
    push @extra_make_rules,  "    src/pm/util/simple_pmiutil2.lo";
    push @extra_make_rules, "";

    my $objs = "\x24(libmpiexec_la_OBJECTS) \x24(MODDIR)/mpl/libmpl.la";
    push @extra_make_rules,  "libmpiexec.la: $objs";
    push @extra_make_rules,  "\t\@echo LTLD \$\@ && \x24(LTLD) -o \$\@ $objs";
    push @extra_make_rules, "";

    my $objs = "src/pm/remshell/mpiexec.o libmpiexec.la";
    push @extra_make_rules,  "mpiexec.remshell: $objs";
    push @extra_make_rules,  "\t\@echo LTLD \$\@ && \x24(LTLD) -o \$\@ $objs";
    push @extra_make_rules, "";

    push @extra_make_rules,  ".PHONY: remshell-install";
    push @extra_make_rules,  "remshell-install: mpiexec.remshell";
    my $bin = "\x24(PREFIX)/bin";
    push @extra_make_rules,  "\tinstall -d $bin";
    push @extra_make_rules,  "\t/bin/sh ./libtool --mode=install --quiet install mpiexec.remshell $bin";
    push @extra_make_rules,  "\trm -f $bin/mpiexec  && ln -s $bin/mpiexec.remshell $bin/mpiexec";
    push @extra_make_rules,  "\trm -f $bin/mpirun  && ln -s $bin/mpiexec.remshell $bin/mpirun";
    push @extra_make_rules, "";

    push @extra_INCLUDES, "-Isrc/pm/util";
    push @extra_DEFS, "-DHAVE_GETTIMEOFDAY -DUSE_SIGACTION";
}
else {
    my $mkfile="src/pm/hydra/Makefile";
    my $add="$opts{moddir}/mpl/libmpl.la $opts{moddir}/hwloc/hwloc/libhwloc_embedded.la";
    push @extra_make_rules, ".PHONY: hydra hydra-install";
    push @extra_make_rules, "hydra: $mkfile $add";
    push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) )";
    push @extra_make_rules, "";
    push @extra_make_rules, "hydra-install: $mkfile";
    push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) install )";
    push @extra_make_rules, "";
    push @extra_make_rules, "$mkfile:";
    my $config_args = "--prefix=\x24(PREFIX)";
    if ($opts{argobots}) {
        $config_args .= " --with-argobots=$opts{argobots}";
    }
    push @extra_make_rules, "\t\x24(DO_hydra) $config_args";
    push @extra_make_rules, "";
    if ($opts{pm} eq "hydra2") {
        my $mkfile="src/pm/hydra2/Makefile";
        my $add="$opts{moddir}/mpl/libmpl.la $opts{moddir}/hwloc/hwloc/libhwloc_embedded.la";
        push @extra_make_rules, ".PHONY: hydra2 hydra2-install";
        push @extra_make_rules, "hydra2: $mkfile $add";
        push @extra_make_rules, "\t(cd src/pm/hydra2 && \x24(MAKE) )";
        push @extra_make_rules, "";
        push @extra_make_rules, "hydra2-install: $mkfile";
        push @extra_make_rules, "\t(cd src/pm/hydra2 && \x24(MAKE) install )";
        push @extra_make_rules, "";
        push @extra_make_rules, "$mkfile:";
        my $config_args = "--prefix=\x24(PREFIX)";
        if ($opts{argobots}) {
            $config_args .= " --with-argobots=$opts{argobots}";
        }
        $config_args .= " --with-pm=hydra2";
        push @extra_make_rules, "\t\x24(DO_hydra) $config_args";
        push @extra_make_rules, "";
    }
}
if ($opts{enable_izem}) {
    if (!-d "$opts{moddir}/izem") {
        my $cmd = "cp -r src/izem $opts{moddir}/izem";
        print "$cmd\n";
        system $cmd;
    }
    $I_list .= " -I$opts{moddir}/izem/src/include";
    $L_list .= " $opts{moddir}/izem/src/libzm.la";
    push @CONFIGS, "$opts{moddir}/izem/src/include/zm_config.h";
    my @t = ("cd $opts{moddir}/izem");
    push @t, "\x24(DO_stage) Configure IZEM";
    push @t, "sh autogen.sh";
    push @t, "./configure --enable-embedded";
    push @extra_make_rules, "$opts{moddir}/izem/src/include/zm_config.h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my @t = ("cd $opts{moddir}/izem");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$opts{moddir}/izem/src/libzm.la: $opts{moddir}/izem/src/include/zm_config.h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
}

if (!-d "$opts{moddir}/mpl") {
    my $cmd = "cp -r src/mpl $opts{moddir}/mpl";
    print "$cmd\n";
    system $cmd;
    my $cmd = "cp -r confdb $opts{moddir}/mpl/";
    print "$cmd\n";
    system $cmd;
}
if (-d "src/openpa") {
    if (!-d "$opts{moddir}/openpa") {
        my $cmd = "cp -r src/openpa $opts{moddir}/openpa";
        print "$cmd\n";
        system $cmd;
        my $cmd = "cp -r confdb $opts{moddir}/openpa/";
        print "$cmd\n";
        system $cmd;
    }
}

if (!$opts{disable_cxx}) {
    $opts{enable_cxx}=1;
    if (!-f "configure") {
        print ": buildiface - cxx\n";
        chdir "src/binding/cxx";
        system "perl buildiface -nosep -initfile=./cxx.vlist";
        chdir $pwd;
    }
    $dst_hash{"src/binding/cxx/mpicxx.h"}="$opts{prefix}/include";
}
else {
    system "touch src/binding/cxx/mpicxx.h.in";
}

if (!$opts{disable_fortran}) {
    if (!-f "configure") {
        print ": buildiface - mpif_h\n";
        chdir "src/binding/fortran/mpif_h";
        system "perl buildiface >/dev/null";
        chdir $pwd;
    }
    if (!-f "configure") {
        print ": buildiface - use_mpi\n";
        chdir "src/binding/fortran/use_mpi";
        system "perl buildiface >/dev/null";
        system "perl ../mpif_h/buildiface -infile=cf90t.h -deffile=./cf90tdefs";
        chdir $pwd;
    }
    push @extra_make_rules, "src/binding/fortran/use_mpi/mpi.lo: src/binding/fortran/use_mpi/mpi_constants.lo src/binding/fortran/use_mpi/mpi_sizeofs.lo src/binding/fortran/use_mpi/mpi_base.lo";
    push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_base.lo: src/binding/fortran/use_mpi/mpi_constants.lo", "";
    push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_sizeofs.lo: src/binding/fortran/use_mpi/mpifnoext.h", "";
    push @extra_make_rules, "src/binding/fortran/use_mpi/mpi_constants.lo: src/binding/fortran/use_mpi/mpifnoext.h", "";
    push @extra_make_rules, "src/binding/fortran/use_mpi/mpifnoext.h: src/binding/fortran/mpif_h/mpif.h";
    push @extra_make_rules, "\tsed -e 's/^C/!/g' -e '/EXTERNAL/d' -e '/MPI_WTICK/d' \$< > \$@";
    push @extra_make_rules, "";
    if (!-f "configure") {
        print ": buildiface - use_mpi_f08\n";
        chdir "src/binding/fortran/use_mpi_f08";
        system "perl buildiface >/dev/null";
        chdir $pwd;
        print ": buildiface - use_mpi_f08/wrappers_c\n";
        chdir "src/binding/fortran/use_mpi_f08/wrappers_c";
        system "rm -f Makefile.mk";
        system "perl buildiface $pwd/src/include/mpi.h.in";
        system "perl buildiface $pwd/src/mpi/romio/include/mpio.h.in";
        chdir $pwd;
    }
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

    $dst_hash{"src/binding/fortran/mpif_h/mpif.h"}="$opts{prefix}/include";
}
else {
    system "touch src/binding/fortran/mpif_h/Makefile.mk";
    system "touch src/binding/fortran/use_mpi/Makefile.mk";
    system "touch src/binding/fortran/use_mpi_f08/Makefile.mk";
    system "touch src/binding/fortran/mpif_h/mpif.h.in";
    system "touch src/binding/fortran/mpif_h/setbotf.h.in";
    system "touch src/binding/fortran/mpif_h/setbot.c.in";
    system "touch src/binding/fortran/use_mpi/mpi_sizeofs.f90.in";
    system "touch src/binding/fortran/use_mpi/mpi_base.f90.in";
    system "touch src/binding/fortran/use_mpi/mpi_constants.f90.in";
    system "touch src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.f90.in";
    system "touch src/binding/fortran/use_mpi_f08/mpi_c_interface_types.f90.in";
}
my $t = `uname -m`;
if ($t=~/x86_64/) {
    $ENV{FORTRAN_MPI_OFFSET}="integer*8";
}
if (!-f "subsys_include.m4") {
    print "---------------------------\n";
    print "-     maint/gen_subcfg_m4\n";
    print "---------------------------\n";
    system "perl maint/gen_subcfg_m4";
}
if (!-f "configure") {
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/AC_CONFIG_SUBDIRS/) {
            next;
        }
        elsif ($l=~/^\s*HWLOC_/) {
            next;
        }
        elsif ($l=~/^(\s*)(PAC_CONFIG_SUBDIR|PAC_CONFIG_ALL_SUBDIRS)/) {
            $l = "$1: \x23 $2\n";
        }
        elsif ($l=~/^(\s*PAC_SUBDIR_MPL)/) {
            $l = "$1([$opts{moddir}/mpl])";
        }
        elsif ($l=~/^(\s*PAC_SUBDIR_OPA)/) {
            $l = "$1([$opts{moddir}/openpa])";
        }
        elsif ($l=~/^(\s*PAC_SUBDIR_HWLOC)/) {
            $l = "$1([$opts{moddir}/hwloc])";
        }
        if ($flag_skip) {
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/ACLOCAL_AMFLAGS/) {
            $l ="ACLOCAL_AMFLAGS = -I confdb\n";
        }
        if ($flag_skip) {
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/AC_MSG_CHECKING.*OpenPA/) {
            $flag=1;
        }
        elsif ($flag and $l=~/AC_C_BIGENDIAN/) {
            $flag=0;
        }
        elsif ($flag) {
            next;
        }
        if ($flag_skip) {
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    if ($opts{device}=~/ucx/) {
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
        open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines) {
            if ($l=~/^AM_COND_IF\(\[BUILD_CH4_NETMOD_UCX\]/) {
                $flag = 1;
                next;
            }
            elsif ($flag) {
                if ($l=~/^\]\)/) {
                    $flag = 0;
                    next;
                }
                elsif ($l=~/AC_DEFINE\(HAVE_UCP_\w+_NB,1/) {
                }
                else {
                    next;
                }
            }
            if ($flag_skip) {
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
    if ($opts{device}=~/ofi/) {
        if ($opts{device}=~/ch3:nemesis:ofi/) {
            my $flag;
            my $f = "src/mpid/ch3/channels/nemesis/netmod/ofi/subconfigure.m4";
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
            open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
            print "  --> [$m[2]]\n";
            foreach my $l (@lines) {
                if ($l=~/^AM_COND_IF\(\[BUILD_NEMESIS_NETMOD_OFI\]/) {
                    $flag = 1;
                    next;
                }
                elsif ($flag) {
                    if ($l=~/^\]\).*AM_COND_IF\(BUILD_NEMESIS_NETMOD_OFI/) {
                        $flag = 0;
                        print Out "    AC_DEFINE([ENABLE_COMM_OVERRIDES], [1], [Define to add per-vc function pointers to override send and recv functions])\n";
                    }
                    next;
                }
                if ($flag_skip) {
                    next;
                }
                print Out $l;
            }
            close Out;
            system "cp -v $m[2] $m[0]";
        }
        else {
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
            open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
            print "  --> [$m[2]]\n";
            foreach my $l (@lines) {
                if ($l=~/^AM_COND_IF\(\[BUILD_CH4_NETMOD_OFI\]/) {
                    $flag = 1;
                    next;
                }
                elsif ($flag) {
                    if ($l=~/^\]\).*AM_COND_IF\(BUILD_CH4_NETMOD_OFI/) {
                        $flag = 0;
                        print Out "    AC_DEFINE([MPIDI_CH4_OFI_USE_SET_RUNTIME], [1], [Define to use runtime capability set])\n";
                        next;
                    }
                    elsif ($l=~/AC_ARG_ENABLE/) {
                        $flag=2;
                    }
                    elsif ($flag==2) {
                    }
                    else {
                        next;
                    }
                }
                if ($flag_skip) {
                    next;
                }
                print Out $l;
            }
            close Out;
            system "cp -v $m[2] $m[0]";
        }
    }

    my $skip_xpmem=1;
    foreach my $a (@config_args) {
        if ($a=~/--with-xpmem/) {
            $skip_xpmem = 0;
        }
    }
    if ($skip_xpmem) {
        my $f = "src/mpid/ch4/shm/ipc/xpmem/subconfigure.m4";
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
        open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines) {
            if ($l=~/AM_CONDITIONAL.*BUILD_SHM_IPC_XPMEM.*build_ch4_shm_ipc_xpmem/) {
                $l=~s/test .* ".*"/false/;
            }
            if ($flag_skip) {
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
    system "autoreconf -ivf";
    foreach my $m (@mod_list) {
        system "cp $m->[1] $m->[0]";
    }
}
if (!-f "mymake/Makefile.orig") {
    print "---------------------------\n";
    print "-     Configure MPICH\n";
    print "---------------------------\n";
    system "rm -f Makefile";
    my $t = join ' ', @config_args;
    system "./configure --with-pm=no $t";
    system "mv Makefile mymake/Makefile.orig";
    my @mod_list;
    my %need_patch;
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/^AR_FLAGS=/) {
            $l = "AR_FLAGS=\"cr\"\n";
        }
        elsif ($l=~/^CC="(.*)"/) {
            my ($CC) = ($1);
            if ($CC =~ /^sun(f77|f9.|fortran)/) {
                $need_patch{pic_flag}=" -KPIC";
                $need_patch{wl}="-Qoption ld ";
                $need_patch{link_static_flag}=" -Bstatic";
                $need_patch{shared}="-G";
            }
            else {
                %need_patch=();
            }
        }
        elsif ($l=~/^(pic_flag|wl|link_static_flag)=/) {
            if ($need_patch{$1}) {
                $l = "$1='$need_patch{$1}'\n";
            }
        }
        elsif ($l=~/^(archive_cmds=|\s*\\\$CC\s+-shared )/) {
            if ($need_patch{shared}) {
                $l=~s/-shared /$need_patch{shared} /;
            }
        }
        if ($flag_skip) {
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    system "chmod a+x libtool";
}

open In, "src/include/mpichconf.h" or die "Can't open src/include/mpichconf.h: $!\n";
while(<In>){
    if (/^#define\s+HAVE_.*WEAK.* 1/) {
        $opts{have_weak}=1;
    }
}
close In;
open In, "maint/version.m4" or die "Can't open maint/version.m4: $!\n";
while(<In>){
    if (/libmpi_so_version_m4.*\[([\d:]*)\]/) {
        $opts{so_version}=$1;
    }
}
close In;
open In, "config.status" or die "Can't open config.status: $!\n";
while(<In>){
    if (/S\["WRAPPER_LIBS"\]="(.*)"/) {
        $opts{WRAPPER_LIBS}=$1;
    }
}
close In;
open In, "mymake/Makefile.orig" or die "Can't open mymake/Makefile.orig: $!\n";
while(<In>){
    if (/^CFLAGS *= *(.*)/) {
        $opts{CFLAGS}=$1;
        open Out, ">mymake/CFLAGS" or die "Can't write mymake/CFLAGS: $!\n";
        print "  --> [mymake/CFLAGS]\n";
        print Out "$1\n";
        close Out;
    }
}
close In;

if (!$opts{have_weak}) {
    $special_targets{lib_libmpi_la}="\x24(LTCC) -DMPICH_MPI_FROM_PMPI";
}

my $bin="\x24(PREFIX)/bin";
if (-f "src/env/mpicc.bash") {
    my @lines;
    {
        open In, "src/env/mpicc.bash" or die "Can't open src/env/mpicc.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$opts{prefix}, EXEC_PREFIX=>"$opts{prefix}/bin", SYSCONFDIR=>"$opts{prefix}/etc", INCLUDEDIR=>"$opts{prefix}/include", LIBDIR=>"$opts{prefix}/lib");
    open Out, ">mymake/mpicc" or die "Can't write mymake/mpicc: $!\n";
    foreach my $l (@lines) {
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpicc"}=$bin;
}
if (-f "src/env/mpicxx.bash") {
    my @lines;
    {
        open In, "src/env/mpicxx.bash" or die "Can't open src/env/mpicxx.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$opts{prefix}, EXEC_PREFIX=>"$opts{prefix}/bin", SYSCONFDIR=>"$opts{prefix}/etc", INCLUDEDIR=>"$opts{prefix}/include", LIBDIR=>"$opts{prefix}/lib");
    open Out, ">mymake/mpicxx" or die "Can't write mymake/mpicxx: $!\n";
    foreach my $l (@lines) {
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpicxx"}=$bin;
}
if (-f "src/env/mpif77.bash") {
    my @lines;
    {
        open In, "src/env/mpif77.bash" or die "Can't open src/env/mpif77.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$opts{prefix}, EXEC_PREFIX=>"$opts{prefix}/bin", SYSCONFDIR=>"$opts{prefix}/etc", INCLUDEDIR=>"$opts{prefix}/include", LIBDIR=>"$opts{prefix}/lib");
    open Out, ">mymake/mpif77" or die "Can't write mymake/mpif77: $!\n";
    foreach my $l (@lines) {
        $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
        print Out $l;
    }
    close Out;
    $dst_hash{"mymake/mpif77"}=$bin;
}
if (-f "src/env/mpifort.bash") {
    my @lines;
    {
        open In, "src/env/mpifort.bash" or die "Can't open src/env/mpifort.bash.\n";
        @lines=<In>;
        close In;
    }
    my %tmp=(PREFIX=>$opts{prefix}, EXEC_PREFIX=>"$opts{prefix}/bin", SYSCONFDIR=>"$opts{prefix}/etc", INCLUDEDIR=>"$opts{prefix}/include", LIBDIR=>"$opts{prefix}/lib");
    open Out, ">mymake/mpifort" or die "Can't write mymake/mpifort: $!\n";
    foreach my $l (@lines) {
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
if (-d "src/openpa") {
    $I_list .= " -I$opts{moddir}/openpa/src";
    $L_list .= " $opts{moddir}/openpa/src/libopa.la";
    push @CONFIGS, "$opts{moddir}/openpa/src/opa_config.h";
    my @t = ("cd $opts{moddir}/openpa");
    push @t, "\x24(DO_stage) Configure OpenPA";
    push @t, "autoreconf -ivf";
    push @t, "./configure --disable-versioning --enable-embedded";
    if ($opts{openpa_primitives}) {
        $t[-1] .= " --with-atomic-primitives=$opts{openpa_primitives}";
    }
    push @t, "cp $pwd/libtool .";
    push @extra_make_rules, "$opts{moddir}/openpa/src/opa_config.h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my @t = ("cd $opts{moddir}/openpa");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$opts{moddir}/openpa/src/libopa.la: $opts{moddir}/openpa/src/opa_config.h";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
}
$I_list .= " -I$opts{moddir}/mpl/include";
$L_list .= " $opts{moddir}/mpl/libmpl.la";
push @CONFIGS, "$opts{moddir}/mpl/include/mplconfig.h";
my $config_args = "--disable-versioning --enable-embedded";
foreach my $t (@config_args) {
    if ($t=~/--enable-(g|strict)/) {
        $config_args.=" $t";
    }
    elsif ($t=~/--with-(mpl|thread-package|argobots|uti)/) {
        $config_args.=" $t";
    }
}
my @t = ("cd $opts{moddir}/mpl");
push @t, "\x24(DO_stage) Configure MPL";
push @t, "autoreconf -ivf";
push @t, "./configure $config_args";
push @t, "cp $pwd/libtool .";
push @extra_make_rules, "$opts{moddir}/mpl/include/mplconfig.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $opts{moddir}/mpl");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$opts{moddir}/mpl/libmpl.la: $opts{moddir}/mpl/include/mplconfig.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if (!-d "$opts{moddir}/hwloc") {
    my $cmd = "cp -r src/hwloc $opts{moddir}/hwloc";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$opts{moddir}/hwloc/include";
$L_list .= " $opts{moddir}/hwloc/hwloc/libhwloc_embedded.la";
push @CONFIGS, "$opts{moddir}/hwloc/include/hwloc/autogen/config.h";
my @t = ("cd $opts{moddir}/hwloc");
push @t, "\x24(DO_stage) Configure HWLOC";
push @t, "sh autogen.sh";
push @t, "./configure --enable-embedded-mode --enable-visibility";
push @extra_make_rules, "$opts{moddir}/hwloc/include/hwloc/autogen/config.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $opts{moddir}/hwloc");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$opts{moddir}/hwloc/hwloc/libhwloc_embedded.la: $opts{moddir}/hwloc/include/hwloc/autogen/config.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if (!-d "$opts{moddir}/yaksa") {
    my $cmd = "cp -r modules/yaksa $opts{moddir}/yaksa";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$opts{moddir}/yaksa/src/frontend/include";
$L_list .= " $opts{moddir}/yaksa/libyaksa.la";
push @CONFIGS, "$opts{moddir}/yaksa/src/frontend/include/yaksa_config.h";
my @t = ("cd $opts{moddir}/yaksa");
push @t, "\x24(DO_stage) Configure yaksa";
push @t, "sh autogen.sh";
push @t, "./configure";
push @extra_make_rules, "$opts{moddir}/yaksa/src/frontend/include/yaksa_config.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $opts{moddir}/yaksa");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$opts{moddir}/yaksa/libyaksa.la: $opts{moddir}/yaksa/src/frontend/include/yaksa_config.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";

if (-f "maint/tuning/coll/json_gen.sh") {
    if (!-d "$opts{moddir}/json-c") {
        my $cmd = "cp -r modules/json-c $opts{moddir}/json-c";
        print "$cmd\n";
        system $cmd;
    }
    $I_list .= " -I$opts{moddir}/json-c";
    $L_list .= " $opts{moddir}/json-c/libjson-c.la";
    system "bash maint/tuning/coll/json_gen.sh";
}

if (!$opts{disable_romio}) {
    system "rsync -r confdb/ src/mpi/romio/confdb/";
    system "cp maint/version.m4 src/mpi/romio/";
    my @t_env;
    push @t_env, "FROM_MPICH=yes";
    push @t_env, "master_top_srcdir=$pwd";
    push @t_env, "master_top_builddir=$pwd";
    push @t_env, "CPPFLAGS='-I$opts{moddir}/mpl/include'";
    if ($opts{argobots}) {
        $t_env[-1] =~s/'$/ -I$opts{argobots}\/include'/;
    }

    $I_list .= " -Isrc/mpi/romio/include";
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

    $dst_hash{"src/mpi/romio/include/mpio.h"} = "$opts{prefix}/include";
    $dst_hash{"src/mpi/romio/include/mpiof.h"} = "$opts{prefix}/include";
}

if ($opts{device}=~/ch4:ucx/) {
    my $ucxdir="$opts{moddir}/ucx";
    if (-e "$ucxdir/need_sed") {
        print "Patch $ucxdir ...\n";
        system "find $ucxdir -name '*.la' | xargs sed -i \"s,MODDIR,$ucxdir,g\"";
        system "find $ucxdir -name '*.la*' | xargs sed -i \"s,/MODPREFIX,$opts{prefix},g\"";
        system "mkdir -p $opts{prefix}/lib/ucx";
        foreach my $m ("ucm", "ucs", "uct", "ucp") {
            system "$ucxdir/libtool --mode=install --quiet install $ucxdir/src/$m/lib$m.la $opts{prefix}/lib";
        }
        my @tlist = glob("$ucxdir/modules/*.la");
        foreach my $m (@tlist) {
            system "$ucxdir/libtool --mode=install --quiet install $m $opts{prefix}/lib/ucx";
        }
        unlink "$ucxdir/need_sed";
    }

    if ($opts{ucx} eq "embedded") {
        $I_list .= " -I$opts{moddir}/ucx/src";
        $L_list .= " $opts{prefix}/lib/libucp.la";
        if (!-d "$opts{moddir}/ucx") {
            my $cmd = "cp -r src/mpid/ch4/netmod/ucx/ucx $opts{moddir}/ucx";
            print "$cmd\n";
            system $cmd;
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

        push @CONFIGS, "$opts{moddir}/ucx/config.h";
        my @t = ("cd $opts{moddir}/ucx");
        push @t, "\x24(DO_stage) Configure UCX";
        push @t, "mkdir -p config/m4 config/aux";
        push @t, "autoreconf -iv";
        push @t, "./configure --prefix=\x24(PREFIX) --disable-static";
        push @extra_make_rules, "$opts{moddir}/ucx/config.h: ";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        my @t = ("cd $opts{moddir}/ucx");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$opts{moddir}/ucx/src/ucp/libucp.la: $opts{moddir}/ucx/config.h";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
    }
    else {
        $I_list .= " -I$opts{ucx}/include";
        $L_list .= " -L$opts{ucx}/lib";
        $L_list .= " -lucp -lucs";
    }
}
if ($opts{device}=~/:ofi/) {
    if ($opts{libfabric} eq "embedded") {
        $I_list .= " -I$opts{moddir}/libfabric/include";
        $L_list .= " $opts{moddir}/libfabric/src/libfabric.la";
        if (!-d "$opts{moddir}/libfabric") {
            my $cmd = "cp -r src/mpid/ch4/netmod/ofi/libfabric $opts{moddir}/libfabric";
            print "$cmd\n";
            system $cmd;
        }
        push @CONFIGS, "$opts{moddir}/libfabric/config.h";
        my @t = ("cd $opts{moddir}/libfabric");
        push @t, "\x24(DO_stage) Configure libfabric";
        push @t, "sh autogen.sh";
        push @t, "./configure --enable-embedded --enable-sockets=yes --enable-psm=no --enable-psm2=no --enable-verbs=no --enable-usnic=no --enable-mlx=no --enable-gni=no --enable-ugni=no --enable-rxm=no --enable-mrail=no --enable-rxd=no --enable-bgq=no --enable-rstream=no --enable-udp=no --enable-perf=no";
        push @extra_make_rules, "$opts{moddir}/libfabric/config.h: ";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        my @t = ("cd $opts{moddir}/libfabric");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$opts{moddir}/libfabric/src/libfabric.la: $opts{moddir}/libfabric/config.h";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
    }
    else {
        $I_list .= " -I$opts{libfabric}/include";
        $L_list .= " -L$opts{libfabric}/lib";
        $L_list .= " -lfabric";
    }
}

if ($ENV{EXTRA_LIB}) {
    $L_list .= " $ENV{EXTRA_LIB}";
}

my $lt_opt;
if ($opts{V}==0) {
    $lt_opt = "--quiet";
}

if ($opts{argobots}) {
    $I_list .= " -I$opts{argobots}/include";
}
my $_P = `pwd`;
chomp $_P;
$I_list=~s/$_P/./g;

%objects=();
my $tlist;
open In, "mymake/Makefile.orig" or die "Can't open mymake/Makefile.orig: $!\n";
while(<In>){
    if (/^(\w+)\s*=\s*(.*)/) {
        my ($a, $b) = ($1, $2);
        $tlist=[];
        $objects{$a} = $tlist;

        my $done=1;
        if ($b=~/\\$/) {
            $done = 0;
            $b=~s/\s*\\$//;
        }

        if ($b) {
            push @$tlist, split /\s+/, $b;
        }
        if ($done) {
            undef $tlist;
        }
    }
    elsif ($tlist) {
        if (/\s*(.*)/) {
            my ($b) = ($1);
            my $done=1;
            if ($b=~/\\$/) {
                $done = 0;
                $b=~s/\s*\\$//;
            }

            if ($b) {
                push @$tlist, split /\s+/, $b;
            }
            if ($done) {
                undef $tlist;
            }
        }
    }
}
close In;
open Out, ">mymake/Makefile.custom" or die "Can't write mymake/Makefile.custom: $!\n";
print "  --> [mymake/Makefile.custom]\n";
print Out "export MODDIR=$opts{moddir}\n";
print Out "PREFIX=$opts{prefix}\n";
print Out "\n";
if (@CONFIGS) {
    my $l = "CONFIGS = @CONFIGS";
    $l=~s/$opts{moddir}/\x24(MODDIR)/g;
    print Out "$l\n";
    print Out "\n";
}
my $t = get_object("DEFS");
$t .= " @extra_DEFS";
my $l = "DEFS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("DEFAULT_INCLUDES");
my $l = "DEFAULT_INCLUDES = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("INCLUDES");
$t .= " @extra_INCLUDES";
my $l = "INCLUDES = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CPPFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
my $l = "AM_CPPFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CPPFLAGS");
$t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa)\/\S+\s*//g;
$t=~s/-I\S+\/json-c//g;
$t .= $I_list;
my $l = "CPPFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
my $l = "AM_CFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CFLAGS");
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
    $t = join(' ', @tlist);
    print(STDOUT "  -->  CFLAGS = $t\n");
}
my $l = "CFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_LDFLAGS");
my $l = "AM_LDFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LDFLAGS");
my $l = "LDFLAGS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LIBS");
my $l = "LIBS = $t";
$l=~s/$opts{moddir}/\x24(MODDIR)/g;
print Out "$l\n";
print Out "\n";

my $cc = get_object("CC");
my $ccld = get_object("CCLD");

print Out "COMPILE = $cc \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) \x24(AM_CFLAGS) \x24(CFLAGS)\n";
print Out "LINK = $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
print Out "LTCC = /bin/sh ./libtool --mode=compile $lt_opt \x24(COMPILE)\n";
print Out "LTLD = /bin/sh ./libtool --mode=link $lt_opt \x24(LINK)\n";
print Out "\n";
if (!$opts{disable_cxx}) {
    my $cxx = get_object("CXX");
    my $flags = get_object("CXXFLAGS");
    my $am_flags = get_object("AM_CXXFLAGS");
    print Out "CXXCOMPILE = $cxx \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) $flags $am_flags\n";

    my $cxxld = get_object("CXXLD");
    if ($cxxld) {
        print Out "LTCXX = /bin/sh ./libtool --mode=compile $lt_opt --tag=CXX \x24(CXXCOMPILE)\n";
        print Out "CXXLD = /bin/sh ./libtool --mode=link $lt_opt --tag=CXX $cxxld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    }
    else {
        print Out "LTCXX = /bin/sh ./libtool --mode=compile $lt_opt \x24(CXXCOMPILE)\n";
        print Out "CXXLD = /bin/sh ./libtool --mode=link $lt_opt --tag=CC $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    }
    print Out "\n";
}
if (!$opts{disable_fortran}) {
    my $fc = get_object("F77");
    my $flags = get_object("FFLAGS");
    my $am_flags = get_object("AM_FFLAGS");
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
    print Out "F77COMPILE = $fc $flags\n";
    print Out "LTF77 = /bin/sh ./libtool --mode=compile $lt_opt --tag=F77 \x24(F77COMPILE)\n";

    my $ld = get_object("F77LD");
    print Out "F77LD = /bin/sh ./libtool --mode=link $lt_opt --tag=F77 $ld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    print Out "\n";
    my $fc = get_object("FC");
    my $flags = get_object("FCFLAGS");
    my $am_flags = get_object("AM_FCFLAGS");
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
    print Out "LTFC = /bin/sh ./libtool --mode=compile $lt_opt --tag=FC \x24(FCCOMPILE)\n";

    my $ld = get_object("FCLD");
    print Out "FCLD = /bin/sh ./libtool --mode=link $lt_opt --tag=FC $ld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    print Out "\n";
}

my $tlist = get_list("lib_LTLIBRARIES");
foreach my $t (@$tlist) {
    $dst_hash{$t} = "\x24(PREFIX)/lib";
}
my $tlist = get_list("bin_PROGRAMS");
foreach my $t (@$tlist) {
    if ($t=~/mpichversion/) {
        next;
    }
    elsif ($t=~/mpivars/) {
        next;
    }
    $dst_hash{$t} = "\x24(PREFIX)/bin";
}
my $tlist = get_list("PROGRAMS");
foreach my $t (@$tlist) {
    if ($t=~/mpichversion/) {
        next;
    }
    elsif ($t=~/mpivars/) {
        next;
    }
    push @programs, $t;
}

my $tlist = get_list("LTLIBRARIES");
foreach my $t (@$tlist) {
    push @ltlibs, $t;
}

print Out "all: @ltlibs @programs\n";
print Out "\n";

foreach my $p (@ltlibs) {
    my $ld = "LTLD";
    if ($p=~/libmpifort.la/) {
        $ld = "F77LD";
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
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if ($special_targets{$a}) {
        foreach my $t (@tlist) {
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else {
        foreach my $t (@tlist) {
            $t=~s/[^\/]+-//;
        }
    }

    my @t;
    foreach my $t (@tlist) {
        if ($t=~/^-l\w+/) {
            $objs.=" $t";
        }
        elsif ($t=~/^-L\S+/) {
            $objs.=" $t";
        }
        else {
            push @t, $t;
        }
    }

    if ($o=~/mpifort.*_OBJECTS/) {
        my @f08_wrappers_f;
        foreach my $t (@t) {
            if ($t=~/use_mpi_f08\/wrappers_f\//) {
                push @f08_wrappers_f, $t;
                $t=undef;
            }
        }

        if (@f08_wrappers_f) {
            push @t, "\x24(F08_WRAPPERS_F_OBJECTS)";

            print Out "F08_WRAPPERS_F_OBJECTS = \\\n";
            my $last_item = pop @f08_wrappers_f;
            foreach my $t (@f08_wrappers_f) {
                print Out "    $t \\\n";
            }
            print Out "    $last_item\n";
        }
        print Out "\x24(F08_WRAPPERS_F_OBJECTS): \x24(CONFIGS) src/binding/fortran/use_mpi_f08/mpi_f08.lo src/binding/fortran/use_mpi_f08/mpi_c_interface.lo src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo\n";
        print Out "\n";
    }

    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t) {
        if ($t) {
            my $l = "    $t \\";
            $l=~s/$opts{moddir}/\x24(MODDIR)/g;
            print Out "$l\n";
        }
    }
    my $l = "    $last_item";
    $l=~s/$opts{moddir}/\x24(MODDIR)/g;
    print Out "$l\n";

    if (@CONFIGS and "$o"=~/_OBJECTS$/) {
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LIBADD";

    if ($objects{$add}) {
        my $t = get_object($add);
        if ($add!~/mpi(fort|cxx)/) {
            if ($t=~/libpromio/) {
                my @t = ("cd src/mpi/romio");
                push @t, "\x24(MAKE)";
                push @extra_make_rules, "src/mpi/romio/libpromio.la: src/mpi/romio/adio/include/romioconf.h";
                push @extra_make_rules, "\t(".join(' && ', @t).")";
                push @extra_make_rules, "";
            }
            if ($add=~/_libmpi_la_/ && $opts{have_weak}) {
                $t=~s/\S+\/(mpl|openpa|izem|hwloc|yaksa|json-c)\/\S+\.la\s*//g;
                $t=~s/\@ucxlib\@\s*//g;
                $t=~s/\@ofilib\@\s*//g;
                $t.= $L_list;
            }
            elsif ($add=~/_libpmpi_la_/) {
                $t=~s/\S+\/(mpl|openpa|izem|hwloc|yaksa|json-c)\/\S+\.la\s*//g;
                $t=~s/\@ucxlib\@\s*//g;
                $t=~s/\@ofilib\@\s*//g;
                $t.= $L_list;
            }
        }
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
                push @t, $t;
            }
        }

        if ($add=~/mpifort.*_OBJECTS/) {
            my @f08_wrappers_f;
            foreach my $t (@t) {
                if ($t=~/use_mpi_f08\/wrappers_f\//) {
                    push @f08_wrappers_f, $t;
                    $t=undef;
                }
            }

            if (@f08_wrappers_f) {
                push @t, "\x24(F08_WRAPPERS_F_OBJECTS)";

                print Out "F08_WRAPPERS_F_OBJECTS = \\\n";
                my $last_item = pop @f08_wrappers_f;
                foreach my $t (@f08_wrappers_f) {
                    print Out "    $t \\\n";
                }
                print Out "    $last_item\n";
            }
            print Out "\x24(F08_WRAPPERS_F_OBJECTS): \x24(CONFIGS) src/binding/fortran/use_mpi_f08/mpi_f08.lo src/binding/fortran/use_mpi_f08/mpi_c_interface.lo src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo\n";
            print Out "\n";
        }

        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t) {
            if ($t) {
                my $l = "    $t \\";
                $l=~s/$opts{moddir}/\x24(MODDIR)/g;
                print Out "$l\n";
            }
        }
        my $l = "    $last_item";
        $l=~s/$opts{moddir}/\x24(MODDIR)/g;
        print Out "$l\n";

        if (@CONFIGS and "$add"=~/_OBJECTS$/) {
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
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

foreach my $p (@programs) {
    my $ld = "LTLD";
    if ($p=~/libmpifort.la/) {
        $ld = "F77LD";
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
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if ($special_targets{$a}) {
        foreach my $t (@tlist) {
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else {
        foreach my $t (@tlist) {
            $t=~s/[^\/]+-//;
        }
    }

    my @t;
    foreach my $t (@tlist) {
        if ($t=~/^-l\w+/) {
            $objs.=" $t";
        }
        elsif ($t=~/^-L\S+/) {
            $objs.=" $t";
        }
        else {
            push @t, $t;
        }
    }

    if ($o=~/mpifort.*_OBJECTS/) {
        my @f08_wrappers_f;
        foreach my $t (@t) {
            if ($t=~/use_mpi_f08\/wrappers_f\//) {
                push @f08_wrappers_f, $t;
                $t=undef;
            }
        }

        if (@f08_wrappers_f) {
            push @t, "\x24(F08_WRAPPERS_F_OBJECTS)";

            print Out "F08_WRAPPERS_F_OBJECTS = \\\n";
            my $last_item = pop @f08_wrappers_f;
            foreach my $t (@f08_wrappers_f) {
                print Out "    $t \\\n";
            }
            print Out "    $last_item\n";
        }
        print Out "\x24(F08_WRAPPERS_F_OBJECTS): \x24(CONFIGS) src/binding/fortran/use_mpi_f08/mpi_f08.lo src/binding/fortran/use_mpi_f08/mpi_c_interface.lo src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo\n";
        print Out "\n";
    }

    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t) {
        if ($t) {
            my $l = "    $t \\";
            $l=~s/$opts{moddir}/\x24(MODDIR)/g;
            print Out "$l\n";
        }
    }
    my $l = "    $last_item";
    $l=~s/$opts{moddir}/\x24(MODDIR)/g;
    print Out "$l\n";

    if (@CONFIGS and "$o"=~/_OBJECTS$/) {
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LDADD";

    if ($objects{$add}) {
        my $t = get_object($add);
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
                push @t, $t;
            }
        }

        if ($add=~/mpifort.*_OBJECTS/) {
            my @f08_wrappers_f;
            foreach my $t (@t) {
                if ($t=~/use_mpi_f08\/wrappers_f\//) {
                    push @f08_wrappers_f, $t;
                    $t=undef;
                }
            }

            if (@f08_wrappers_f) {
                push @t, "\x24(F08_WRAPPERS_F_OBJECTS)";

                print Out "F08_WRAPPERS_F_OBJECTS = \\\n";
                my $last_item = pop @f08_wrappers_f;
                foreach my $t (@f08_wrappers_f) {
                    print Out "    $t \\\n";
                }
                print Out "    $last_item\n";
            }
            print Out "\x24(F08_WRAPPERS_F_OBJECTS): \x24(CONFIGS) src/binding/fortran/use_mpi_f08/mpi_f08.lo src/binding/fortran/use_mpi_f08/mpi_c_interface.lo src/binding/fortran/use_mpi_f08/mpi_c_interface_types.lo src/binding/fortran/use_mpi_f08/mpi_f08_compile_constants.lo\n";
            print Out "\n";
        }

        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t) {
            if ($t) {
                my $l = "    $t \\";
                $l=~s/$opts{moddir}/\x24(MODDIR)/g;
                print Out "$l\n";
            }
        }
        my $l = "    $last_item";
        $l=~s/$opts{moddir}/\x24(MODDIR)/g;
        print Out "$l\n";

        if (@CONFIGS and "$add"=~/_OBJECTS$/) {
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
    }
    if ($objects{"${a}_CFLAGS"}) {
        $cmd.= ' '. get_object("${a}_CFLAGS");
        $cmd .= " \x24(CFLAGS)";
    }
    if ($objects{"${a}_LDFLAGS"}) {
        $cmd.= ' '. get_object("${a}_LDFLAGS");
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

print Out "\x23 --------------------\n";
foreach my $l (@extra_make_rules) {
    $l=~s/$opts{moddir}/\x24(MODDIR)/g;
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
        print Out "\t\@echo LTF77 \$\@ && \x24(LTF77) -c -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(LTF77) -c -o \$\@ \$<\n";
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
print Out "%.i: %.c\n";
if ($opts{V}==0) {
    print Out "\t\@echo CC -E \$\@ && \x24(COMPILE) -E -o \$\@ \$<\n";
}
else {
    print Out "\t\x24(COMPILE) -E -o \$\@ \$<\n";
}
print Out "\n";
my $t1 = get_list("include_HEADERS");
my $t2 = get_list("nodist_include_HEADERS");
my $t3 = get_list("modinc_HEADERS");
if (@$t1 or @$t2 or @$t3) {
    foreach my $t (@$t1, @$t2, @$t3) {
        $t=~s/use_mpi_f08/use_mpi/;
        $dst_hash{$t} = "$opts{prefix}/include";
    }
}

my (%dirs, @install_list, @install_deps, @lns_list);
while (my ($k, $v) = each %dst_hash) {
    if ($k=~/^LN_S-(.*)/) {
        push @lns_list, "rm -f $1 && ln -s $v $1";
    }
    elsif ($v) {
        if (!$dirs{$v}) {
            $dirs{$v} = 1;
        }
        if ($v=~/\/lib$/) {
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
            push @install_deps, $k;
        }
        elsif ($v=~/\/bin$/) {
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
            push @install_deps, $k;
        }
        elsif ($v=~/\/include$/) {
            push @install_list, "cp $k $v";
        }
    }
}

my @install_list = sort @install_list;
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
print Out ".PHONY: clean realclean realrealclean\n";
print Out "clean:\n";
print Out "\t(find src -name '*.o' -o -name '*.lo' -o -name '*.a' -o -name '*.la' |xargs rm -f)\n";
print Out "\n";
print Out "realclean: clean\n";
print Out "\trm -f configure mymake/Makefile.orig src/mpi/errhan/defmsg.h src/include/mpir_cvars.h src/utils/mpir_cvars.c src/pm/hydra/configure src/pm/hydra/mymake/Makefile.orig\n";
print Out "\trm -rf mymake/mpl mymake/openpa mymake/romio\n";
print Out "\n";

close Out;
system "rm -f Makefile";
system "ln -s mymake/Makefile.custom Makefile";

$ENV{CFLAGS}=$opts{CFLAGS};
if (-d "src/openpa") {
    system "make $opts{moddir}/mpl/include/mplconfig.h $opts{moddir}/openpa/src/opa_config.h";
}
else {
    system "make $opts{moddir}/mpl/include/mplconfig.h";
}

open Out, ">mymake/t.c" or die "Can't write mymake/t.c: $!\n";
print Out "#include \"mpl_atomic.h\"\n";
print Out "#include <pthread.h>\n";
print Out "pthread_mutex_t MPL_emulation_lock;\n";
print Out "int main() { return sizeof(MPL_atomic_ptr_t); }\n";
close Out;

system "$make_vars{CC} -Imymake/mpl/include mymake/t.c -o mymake/t";
system "mymake/t";
my $ret = $? >> 8;

$config_defines{SIZEOF_MPL_ATOMIC_PTR_T} = $ret;
my $lock_based_atomics;
open In, "mymake/mpl/include/mplconfig.h" or die "Can't open mymake/mpl/include/mplconfig.h: $!\n";
while(<In>){
    if (/^#define MPL_USE_LOCK_BASED_PRIMITIVES/) {
        $lock_based_atomics = 1;
        last;
    }
}
close In;
if ($lock_based_atomics) {
    $config_defines{ENABLE_NO_LOCAL} = 1;
}
if ($opts{device}=~/ch4:/ && !$config_defines{MPL_POSIX_MUTEX_NAME}) {
    $config_defines{MPL_POSIX_MUTEX_NAME} = "MPL_POSIX_MUTEX_TICKETLOCK";
}
if (%config_defines) {
    my (@lines, $cnt);
    open In, "mymake/mpl/include/mplconfig.h" or die "Can't open mymake/mpl/include/mplconfig.h: $!\n";
    while(<In>){
        if (/^\/\* #undef (\w+)/ && exists $config_defines{$1}) {
            if (defined $config_defines{$1}) {
                print "  -- define $1 $config_defines{$1}\n";
                push @lines, "#define $1 $config_defines{$1}\n";
            }
            else {
                print "  -- undef $1\n";
                push @lines, "\x2f* #undef $1 */\n";
            }
            $cnt++;
        }
        elsif (/^#define (\w+) (.*)/ && exists $config_defines{$1}) {
            if (defined $config_defines{$1}) {
                print "  -- define $1 $config_defines{$1}\n";
                push @lines, "#define $1 $config_defines{$1}\n";
            }
            else {
                print "  -- undef $1\n";
                push @lines, "\x2f* #undef $1 */\n";
            }
            $cnt++;
        }
        else {
            push @lines, $_;
        }
    }
    close In;

    if ($cnt>0) {
        open Out, ">mymake/mpl/include/mplconfig.h" or die "Can't write mymake/mpl/include/mplconfig.h: $!\n";
        foreach my $l (@lines) {
            print Out $l;
        }
        close Out;
    }
    my (@lines, $cnt);
    open In, "src/include/mpichconf.h" or die "Can't open src/include/mpichconf.h: $!\n";
    while(<In>){
        if (/^\/\* #undef (\w+)/ && exists $config_defines{$1}) {
            if (defined $config_defines{$1}) {
                print "  -- define $1 $config_defines{$1}\n";
                push @lines, "#define $1 $config_defines{$1}\n";
            }
            else {
                print "  -- undef $1\n";
                push @lines, "\x2f* #undef $1 */\n";
            }
            $cnt++;
        }
        elsif (/^#define (\w+) (.*)/ && exists $config_defines{$1}) {
            if (defined $config_defines{$1}) {
                print "  -- define $1 $config_defines{$1}\n";
                push @lines, "#define $1 $config_defines{$1}\n";
            }
            else {
                print "  -- undef $1\n";
                push @lines, "\x2f* #undef $1 */\n";
            }
            $cnt++;
        }
        else {
            push @lines, $_;
        }
    }
    close In;

    if ($cnt>0) {
        open Out, ">src/include/mpichconf.h" or die "Can't write src/include/mpichconf.h: $!\n";
        foreach my $l (@lines) {
            print Out $l;
        }
        close Out;
    }
}

# ---- subroutines --------------------------------------------
sub get_object {
    my ($key) = @_;
    my $arr = $objects{$key};
    if (defined $arr) {
        my $t;
        if (ref($arr) eq "ARRAY") {
            $t = join(' ', @$arr);
        }
        else {
            $t = $arr;
        }
        $t=~s/\$\(am__v_[\w]+\)//g;
        $t=~s/\$\((\w+)\)/get_object($1)/ge;
        $t=~s/\s+/ /g;

        $make_vars{$key} = $t;
        return $t;
    }
    else {
        return "";
    }
}

sub get_list {
    my ($key) = @_;
    my @t;
    my $tlist = $objects{$key};
    foreach my $t (@{$objects{$key}}) {
        if ($t=~/^\$\((\w+)\)$/) {
            my $L = get_list($1);
            push @t, @$L;
        }
        else {
            $t=~s/\$\((\w+)\)/get_object($1)/ge;
            push @t, $t;
        }
    }
    return \@t;
}

