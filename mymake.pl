#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our @config_args;
our %config_defines;
our %config_cflags;
our %config_ldflags;
our %hash_defines;
our %hash_define_vals;
our %objects;
our @programs;
our @ltlibs;
our @CONFIGS;
our $I_list;
our $L_list;
our @extra_make_rules;
our %dst_hash;
our %special_targets;
our @extra_DEFS;
our @extra_INCLUDES;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
if ($0=~/^(\/.*)\//) {
    $opts{mymake} = $1;
}
elsif ($0=~/^(.*)\//) {
    $opts{mymake} .= "$pwd/$1";
}
$opts{mymake} .="/mymake";
if ($ARGV[0]=~/^(clean|errmsg|cvars|log|log_show|logs|hydra|testing|test|makefile|config|libtool)$/) {
    shift @ARGV;
    system "perl $opts{mymake}_$1.pl @ARGV";
    exit(0);
}
if (!-f "maint/version.m4") {
    die "Not in top_srcdir.\n";
}
$hash_defines{"disable-ch4-ofi-ipv6"} = "MPIDI_CH4_OFI_SKIP_IPV6";
$hash_defines{"enable-legacy-ofi"} = "MPIDI_ENABLE_LEGACY_OFI";
$hash_defines{"enable-ch4-am-only"} = "MPIDI_ENABLE_AM_ONLY";
$hash_defines{"with-ch4-max-vcis"} = "MPIDI_CH4_MAX_VCIS";
$hash_defines{"with-ch4-rank-bits"} = "CH4_RANK_BITS";
$hash_defines{"enable-nolocal"} = "ENABLE_NO_LOCAL";
$hash_defines{"enable-izem-queue"} = "ENABLE_IZEM_QUEUE";

$hash_defines{"enable-ofi-domain"} = "MPIDI_OFI_VNI_USE_DOMAIN";
$hash_defines{"disable-ofi-domain"} = "MPIDI_OFI_VNI_USE_DOMAIN";
$hash_define_vals{MPIDI_OFI_VNI_USE_DOMAIN} = { enable => 1, disable => undef };

$hash_defines{"enable-thread-cs"} = "MPICH_THREAD_GRANULARITY";
$hash_define_vals{"MPICH_THREAD_GRANULARITY"} = {
    "default" => "MPICH_THREAD_GRANULARITY__GLOBAL",
    "global" => "MPICH_THREAD_GRANULARITY__GLOBAL",
    "per-vci" => "MPICH_THREAD_GRANULARITY__VCI",
    "per-object" => "MPICH_THREAD_GRANULARITY__POBJ",
};

$hash_defines{"with-posix-mutex"} = "MPL_POSIX_MUTEX_NAME";
$hash_define_vals{"MPL_POSIX_MUTEX_NAME"} = {
    "default" => "MPL_POSIX_MUTEX_NATIVE",
    "ticketlock" => "MPL_POSIX_MUTEX_TICKETLOCK",
};

$hash_defines{"enable-ch4-mt"} = "MPIDI_CH4_USE_MT_{DIRECT,HANDOFF,RUNTIME}";
$hash_define_vals{"MPIDI_CH4_USE_MT_{DIRECT,HANDOFF,RUNTIME}"} = {
    "default" => "DIRECT",
    "direct"  => "DIRECT",
    "handoff" => "HANDOFF",
    "runtime" => "RUNTIME",
};

$hash_defines{"enable-ch4-vci-method"} = "MPIDI_CH4_VCI_METHOD";
$hash_define_vals{"MPIDI_CH4_VCI_METHOD"} = {
    "default" => "MPICH_VCI__COMM",
    "zero" =>    "MPICH_VCI__ZERO",
    "communicator" => "MPICH_VCI__COMM",
    "tag" => "MPICH_VCI__TAG",
    "implicit" => "MPICH_VCI__IMPLICIT",
    "explicit" => "MPICH_VCI__EXPLICIT",
};

$hash_defines{"with-pmi"} = "USE_{PMI1_API,PMI2_API,PMIX_API}";
$hash_define_vals{"USE_{PMI1_API,PMI2_API,PMIX_API}"} = {
    "default" => "PMI1_API",
    "pmi1"    => "PMI1_API",
    "pmi2"    => "PMI2_API",
    "pmix"    => "PMIX_API",
};
$opts{V}=0;
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
    if ($a=~/^-(quick|f08|noclean|sh)/) {
        $opts{$1}=1;
    }
    elsif ($a=~/^--(.*?)=(.*)/) {
        my ($o, $v) = ($1, $2);
        $opts{$1}=$2;
        if ($v eq "no") {
            if ($o=~/^with-(.*)/) {
                $opts{"without-$1"} = 1;
            }
            elsif ($o=~/^enable-(.*)/) {
                $opts{"disable-$1"} = 1;
            }
        }
    }
    elsif ($a=~/^--(.*)/) {
        $opts{$1}=1;
    }
    elsif ($a=~/^(\w+)=(.*)/) {
        $opts{$1}=$2;
    }
    if ($a=~/^--(prefix)=(.*)/) {
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
        elsif ($a=~/--with-(argobots)=(.*)/) {
            $opts{$1}=$2;
            push @config_args, $a;
        }
        elsif ($a=~/--((with|enable)-.*)=(.*)/ && $hash_defines{$1}) {
            my $name = $hash_defines{$1};
            my $val = $3;
            if ($hash_define_vals{$name}) {
                my $V = $hash_define_vals{$name}->{$val};
                if (!$V) {
                    $V = $hash_define_vals{$name}->{default};
                }

                if ($name=~/(\w+)_\{(.*)\}$/) {
                    my ($name_, $val_list) = ($1, $2);
                    foreach my $a (split /,\s*/, $val_list) {
                        if ($a eq $V) {
                            $config_defines{"${name_}_$a"} = 1;
                        }
                        else {
                            $config_defines{"${name_}_$a"} = undef;
                        }
                    }
                }
                else {
                    $config_defines{$name} = $V;
                }
            }
            else {
                $config_defines{$name} = $val;
            }
        }
        elsif ($a=~/--((disable|enable|with|without)-.*)/ && $hash_defines{$1}) {
            my $name = $hash_defines{$1};
            my $val = 1;
            if ($hash_define_vals{$name}) {
                $val = $hash_define_vals{$name}->{$2};
            }
            $config_defines{$name} = $val;
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
                elsif ($t eq "asan") {
                    $config_cflags{O}=1;
                    $config_cflags{"-g"} = 1;
                    $config_cflags{"-fsanitize=address"} = 1;
                    $config_cflags{"-fno-omit-frame-pointer"} = 1;
                    $config_ldflags{"-fsanitize=address"} = 1;
                }
                elsif ($t eq "usan" or $t eq "ubsan") {
                    $config_cflags{"-fsanitize=undefined"} = 1;
                    $config_ldflags{"-fsanitize=undefined"} = 1;
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
            elsif ($g=~/alwaysinline/) {
                $config_defines{MPL_ENABLE_ALWAYS_INLINE} = 1;
            }
            elsif ($g=~/avx/) {
                $config_cflags{-mavx} = 1;
                $config_defines{HAVE_MM256_STREAM_SI256} = 1;
            }
        }
        elsif ($a=~/--enable-strict/) {
            $config_cflags{"-Wall"} = 1;
            $config_cflags{"-Wextra"} = 1;
            $config_cflags{"-Wstrict-prototypes"} = 1;
            $config_cflags{"-Wmissing-prototypes"} = 1;
            $config_cflags{"-DGCC_WALL"} = 1;
            $config_cflags{"-Wno-unused-parameter"} = 1;
            $config_cflags{"-Wshadow"} = 1;
            $config_cflags{"-Wmissing-declarations"} = 1;
            $config_cflags{"-Wundef"} = 1;
            $config_cflags{"-Wpointer-arith"} = 1;
            $config_cflags{"-Wbad-function-cast"} = 1;
            $config_cflags{"-Wwrite-strings"} = 1;
            $config_cflags{"-Wno-sign-compare"} = 1;
            $config_cflags{"-Wnested-externs"} = 1;
            $config_cflags{"-Winvalid-pch"} = 1;
            $config_cflags{"-Wvariadic-macros"} = 1;
            $config_cflags{"-Wtype-limits"} = 1;
            $config_cflags{"-Werror-implicit-function-declaration"} = 1;
            $config_cflags{"-Wstack-usage=262144"} = 1;
            $config_cflags{"-fno-var-tracking"} = 1;
        }

        else {
            push @config_args, $a;
        }
    }
}
if (!$opts{device}) {
    $opts{device} = "ch4:ofi";
}
elsif ($opts{device} eq "ch4") {
    $opts{device} = "ch4:ofi";
}

if ($config_defines{MPIDI_CH4_MAX_VCIS} > 1 and !$config_defines{MPIDI_CH4_VCI_METHOD}) {
    $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__COMM";
}
if ($config_defines{MPICH_THREAD_GRANULARITY} =~/VCI|POBJ/) {
    $config_defines{MPICH_THREAD_REFCOUNT} = "MPICH_REFCOUNT__LOCKFREE";
    if (!$config_defines{MPIDI_CH4_MAX_VCIS}) {
        $config_defines{MPIDI_CH4_MAX_VCIS} = 64;
    }
    if (!$config_defines{MPIDI_CH4_VCI_METHOD}) {
        $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__COMM";
    }
}
else {
    $config_defines{MPICH_THREAD_REFCOUNT} = "MPICH_REFCOUNT__NONE";
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
if (!$opts{prefix}) {
    $opts{prefix}="$pwd/_inst";
}
system "mkdir -p $opts{prefix}";
my $mod_tarball;
if ($ENV{MODTARBALL}) {
    $mod_tarball = $ENV{MODTARBALL};
}
elsif (-e "modules.tar.gz") {
    $mod_tarball = "modules.tar.gz";
}
elsif (-e "modules-yaksa-new.tar.gz") {
    $mod_tarball = "modules-yaksa-new.tar.gz";
}
elsif (-e "modules-gpu.tar.gz") {
    $mod_tarball = "modules-gpu.tar.gz";
}
if ($mod_tarball =~/modules\.tar\.gz$/) {
    if ($opts{"with-cuda"} && $mod_tarball) {
        $mod_tarball=~s/modules.*\.tar\.gz/modules-gpu.tar.gz/;
    }
    if (!-e $mod_tarball) {
        print "$mod_tarball not found! Using module.tar.gz.\n";
        $mod_tarball = "modules.tar.gz";
    }
}
if ($ENV{MODDIR}) {
    $opts{moddir} = Cwd::abs_path($ENV{MODDIR});
}
elsif (-e "mymake/skip_tarball") {
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
    system "touch mymake/skip_tarball";
}
else {
    die "moddir not set\n";
}

my $uname = `uname`;
$opts{uname} = $uname;
if ($uname=~/Darwin|CYGWIN/ or $opts{"disable-weak-symbols"}) {
    $opts{do_pmpi} = 1;
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

if ($need_save_args) {
    my $t = join(' ', @ARGV);
    open Out, ">mymake/args" or die "Can't write mymake/args: $!\n";
    print Out $t, "\n";
    close Out;
    $opts{config_args} = join(' ', @config_args);
    open Out, ">mymake/opts" or die "Can't write mymake/opts: $!\n";
    foreach my $k (sort keys %opts) {
        print Out "$k: $opts{$k}\n";
    }
    close Out;

    if (-f "Makefile" and !$opts{noclean}) {
        system "make realclean";
    }
}
print "moddir: $opts{moddir}\n";
print "prefix: $opts{prefix}\n";
print "device: $opts{device}\n";

my $python = find_python3();
if (-f "maint/gen_binding_c.py") {
    if (!-f "src/mpi/pt2pt/send.c") {
        print "[$python maint/gen_binding_c.py -single-source]\n";
        system("$python maint/gen_binding_c.py -single-source")== 0 or die "Failed $python maint/gen_binding_c.py -single-source\n";
    }
}
if (-f "src/binding/abi/gen_abi.py") {
    print "[cd src/binding/abi && $python gen_abi.py]\n";
    system("cd src/binding/abi && $python gen_abi.py")== 0 or die "Failed cd src/binding/abi && $python gen_abi.py\n";
}
if (-f "maint/gen_ch4_api.py") {
    if (!-f "src/mpid/ch4/netmod/include/netmod.h") {
        print "[$python maint/gen_ch4_api.py]\n";
        system("$python maint/gen_ch4_api.py")== 0 or die "Failed $python maint/gen_ch4_api.py\n";
    }
}
if (-f "maint/gen_coll.py") {
    if (!-f "src/mpi/coll/mpir_coll.c") {
        print "[$python maint/gen_coll.py]\n";
        system("$python maint/gen_coll.py")== 0 or die "Failed $python maint/gen_coll.py\n";
    }
}
if (-f "src/pmi/maint/gen_pmi_msg.py") {
    chdir "src/pmi";
    if (!-f "src/pmi_msg.h") {
        print "[$python maint/gen_pmi_msg.py]\n";
        system("$python maint/gen_pmi_msg.py")== 0 or die "Failed $python maint/gen_pmi_msg.py\n";
    }
    chdir "../..";
}
if (-f "src/env/mpicc.def") {
    $ENV{PERL5LIB} = "$pwd/mymake/mydef_boot/lib/perl5";
    $ENV{MYDEFLIB} = "$pwd/mymake/mydef_boot/lib/MyDef";
    my $mydef_page = "$pwd/mymake/mydef_boot/bin/mydef_page";
    chdir "src/env";
    system "$mydef_page mpicc.def";
    chdir "../..";
}

if (!$opts{disable_cxx}) {
    print ": buildiface - cxx\n";
    chdir "src/binding/cxx";
    system "perl buildiface -nosep -initfile=./cxx.vlist";
    chdir $pwd;
}
if (!$opts{disable_fortran}) {
    if (!-f "configure") {
        print ": buildiface - mpif_h\n";
        chdir "src/binding/fortran/mpif_h";
        system "perl buildiface >/dev/null";
        chdir $pwd;
        print ": buildiface - use_mpi\n";
        chdir "src/binding/fortran/use_mpi";
        if (-f "buildiface") {
            system "perl buildiface >/dev/null";
            system "perl ../mpif_h/buildiface -infile=cf90t.h -deffile=./cf90tdefs";
        }
        chdir $pwd;
        print ": buildiface - use_mpi_f08\n";
        chdir "src/binding/fortran/use_mpi_f08";
        system "perl buildiface >/dev/null";
        chdir $pwd;
        if (-f "maint/gen_binding_f77.py") {
            system "$python maint/gen_binding_f77.py";
        }
        if (-f "maint/gen_binding_f90.py") {
            system "$python maint/gen_binding_f90.py";
        }
        if (-f "maint/gen_binding_f08.py") {
            system "$python maint/gen_binding_f08.py";
        }
        else {
            print ": buildiface - use_mpi_f08/wrappers_c\n";
            chdir "src/binding/fortran/use_mpi_f08/wrappers_c";
            system "rm -f Makefile.mk";
            if (-f "$pwd/src/include/mpi_proto.h") {
                system "perl buildiface $pwd/src/include/mpi_proto.h";
            }
            else {
                system "perl buildiface $pwd/src/include/mpi.h.in";
            }
            system "perl buildiface $pwd/src/mpi/romio/include/mpio.h.in";
            chdir $pwd;
        }
    }
}

if ($opts{quick}) {
    if (!-f "libtool") {
        if (-f "mymake/libtool/libtool") {
            my %need_patch;
            my @lines;
            {
                open In, "mymake/libtool/libtool" or die "Can't open mymake/libtool/libtool.\n";
                @lines=<In>;
                close In;
            }
            open Out, ">libtool" or die "Can't write libtool: $!\n";
            print "  --> [libtool]\n";
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
                print Out $l;
            }
            close Out;
            system "chmod a+x libtool";
        }
        else {
            system "perl $opts{mymake}_libtool.pl";
        }
    }
    else {
        print "\"libtool\" already exist.\n";
    }
    if (!-f "src/include/mpichconf.h") {
        system "perl $opts{mymake}_config.pl mpich";
        system "perl $opts{mymake}_makefile.pl mpich";
    }
    else {
        print "\"src/include/mpichconf.h\" already exist.\n";
    }
}
else {
    my $bin="\x24(PREFIX)/bin";
    if (!$opts{disable_cxx}) {
        $opts{enable_cxx}=1;
        $dst_hash{"src/binding/cxx/mpicxx.h"}="$opts{prefix}/include";
    }
    else {
        system "touch src/binding/cxx/mpicxx.h.in";
    }
    $dst_hash{"mymake/mpicxx"}=$bin;
    $dst_hash{"LN_S-$bin/mpic++"}="$bin/mpicxx";

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
        $dst_hash{"mymake/mpifort"}=$bin;
        $dst_hash{"LN_S-$bin/mpif90"}="$bin/mpifort";
        $dst_hash{"LN_S-$bin/mpif77"}="$bin/mpifort";
    }
    else {
        system "touch src/binding/fortran/mpif_h/Makefile_wrappers.mk";
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
    push @extra_make_rules, "DO_stage = perl $opts{mymake}_stage.pl";
    push @extra_make_rules, "DO_clean = perl $opts{mymake}_clean.pl";
    push @extra_make_rules, "DO_errmsg = perl $opts{mymake}_errmsg.pl";
    push @extra_make_rules, "DO_cvars = perl $opts{mymake}_cvars.pl";
    push @extra_make_rules, "DO_logs = perl $opts{mymake}_logs.pl";
    push @extra_make_rules, "DO_hydra = perl $opts{mymake}_hydra.pl";
    push @extra_make_rules, "DO_testing = perl $opts{mymake}_testing.pl";
    push @extra_make_rules, "DO_mpi_h = perl $opts{mymake}_mpi_h.pl";
    push @extra_make_rules, "";
    push @extra_make_rules, ".PHONY: test cvars errmsg";
    push @extra_make_rules, "testing:";
    push @extra_make_rules, "\t\x24(DO_testing)";
    push @extra_make_rules, "";
    push @extra_make_rules, "cvars:";
    push @extra_make_rules, "\t\x24(DO_cvars)";
    push @extra_make_rules, "";
    push @extra_make_rules, "errmsg:";
    push @extra_make_rules, "\t\x24(DO_errmsg)";
    push @extra_make_rules, "";
    push @extra_make_rules, "realclean: clean";
    push @extra_make_rules, "\t\x24(DO_clean)";
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
        my $add="src/mpl/libmpl.la src/pmi/libpmi.la \x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
        push @extra_make_rules, ".PHONY: hydra hydra-install";
        push @extra_make_rules, "hydra: $mkfile $add";
        push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) )";
        push @extra_make_rules, "";
        push @extra_make_rules, "hydra-install: $mkfile";
        push @extra_make_rules, "\t(cd src/pm/hydra && \x24(MAKE) install )";
        push @extra_make_rules, "";
        push @extra_make_rules, "hydra-clean:";
        push @extra_make_rules, "\t(cd src/pm/hydra && rm -f Makefile && rm -rf mymake )";
        push @extra_make_rules, "";
        push @extra_make_rules, "$mkfile:";
        my $config_args = "--prefix=\x24(PREFIX)";
        if ($opts{"with-argobots"}) {
            $config_args .= " --with-argobots=$opts{argobots}";
        }
        if ($opts{"with-cuda"}) {
            $config_args .= " --with-cuda=$opts{cuda}";
        }
        push @extra_make_rules, "\t\x24(DO_hydra) $config_args";
        push @extra_make_rules, "";
    }
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
        elsif ($t=~/--with(out)?-(mpl|thread-package|argobots|uti|cuda|hip|ze)/) {
            $configure.=" $t";
        }
    }
    my $subdir="src/mpl";
    my $lib_la = "src/mpl/libmpl.la";
    my $config_h = "src/mpl/include/mplconfig.h";
    my $lib_dep = $config_h;

    my @t = ("cd $subdir");
    push @t, "\x24(DO_stage) Configure MPL";
    if (-f "$opts{moddir}/src/mpl/autogen.sh") {
        push @t, "sh autogen.sh";
    }
    else {
        push @t, "autoreconf -ivf";
    }
    push @t, "$configure";
    push @t, "cp $pwd/libtool .";
    push @extra_make_rules, "$config_h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my $dep = "$config_h";
    my @t = ("cd $subdir");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$lib_la: $lib_dep";
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
    my $lib_dep = $config_h;

    my @t = ("cd $subdir");
    push @t, "\x24(DO_stage) Configure HWLOC";
    if (-f "$opts{moddir}/hwloc/autogen.sh") {
        push @t, "sh autogen.sh";
    }
    else {
        push @t, "autoreconf -ivf";
    }
    push @t, "$configure";
    push @t, "cp $pwd/libtool .";
    push @extra_make_rules, "$config_h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my $dep = "$config_h";
    my @t = ("cd $subdir");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$lib_la: $lib_dep";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
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
    my $lib_dep = $config_h;

    my @t = ("cd $subdir");
    push @t, "\x24(DO_stage) Configure YAKSA";
    if (-f "$opts{moddir}/yaksa/autogen.sh") {
        push @t, "sh autogen.sh";
    }
    else {
        push @t, "autoreconf -ivf";
    }
    push @t, "$configure";
    push @t, "cp $pwd/libtool .";
    push @extra_make_rules, "$config_h: ";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
    my $dep = "$config_h";
    my @t = ("cd $subdir");
    push @t, "\x24(MAKE)";
    push @extra_make_rules, "$lib_la: $lib_dep";
    push @extra_make_rules, "\t(".join(' && ', @t).")";
    push @extra_make_rules, "";
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
        my $lib_dep = $config_h;

        my @t = ("cd $subdir");
        push @t, "\x24(DO_stage) Configure JSONC";
        if (-f "$opts{moddir}/json-c/autogen.sh") {
            push @t, "sh autogen.sh";
        }
        else {
            push @t, "autoreconf -ivf";
        }
        push @t, "$configure";
        push @t, "cp $pwd/libtool .";
        push @extra_make_rules, "$config_h: ";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        my $dep = "$config_h";
        my @t = ("cd $subdir");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$lib_la: $lib_dep";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
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
        my $lib_dep = $config_h;

        my @t = ("cd $subdir");
        push @t, "\x24(DO_stage) Configure IZEM";
        if (-f "$opts{moddir}/izem/autogen.sh") {
            push @t, "sh autogen.sh";
        }
        else {
            push @t, "autoreconf -ivf";
        }
        push @t, "$configure";
        push @t, "cp $pwd/libtool .";
        push @extra_make_rules, "$config_h: ";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        my $dep = "$config_h";
        my @t = ("cd $subdir");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$lib_la: $lib_dep";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
    }

    if (-f "src/pmi/configure.ac") {
        if ($opts{"with-pmi"} !~ /slurm|cray/ and $opts{"with-pmilib"} !~/slurm|cray/) {
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
            push @t_env, "CPPFLAGS='-I$pwd/src/mpl/include'";
            if ($opts{argobots}) {
                $t_env[-1] =~s/'$/ -I$opts{argobots}\/include'/;
            }
            if (!$opts{disable_romio}) {
                my $t_dir = "$pwd/src/mpi/romio/include";
                $t_env[-1] =~s/'$/ -I\/$t_dir'/;
            }
            my $configure = "@t_env ./configure --enable-embedded";
            my $subdir="src/pmi";
            my $lib_la = "src/pmi/libpmi.la";
            my $config_h = "src/pmi/include/pmi_config.h";
            my $lib_dep = $config_h;
            if (!$opts{disable_romio}) {
                $lib_dep .= " src/mpi/romio/adio/include/romioconf.h";
            }

            my @t = ("cd $subdir");
            push @t, "\x24(DO_stage) Configure PMI";
            if (-f "$opts{moddir}/src/pmi/autogen.sh") {
                push @t, "sh autogen.sh";
            }
            else {
                push @t, "autoreconf -ivf";
            }
            push @t, "$configure";
            push @t, "cp $pwd/libtool .";
            push @extra_make_rules, "$config_h: ";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
            my $dep = "$config_h";
            my @t = ("cd $subdir");
            push @t, "\x24(MAKE)";
            push @extra_make_rules, "$lib_la: $lib_dep";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
        }
    }

    if (!$opts{disable_romio}) {
        system "rsync -r confdb/ src/mpi/romio/confdb/";
        system "cp maint/version.m4 src/mpi/romio/";
        system "ln -sf ../mpi/romio/include/mpio.h src/include/mpio.h";
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
        push @t_env, "CPPFLAGS='-I$pwd/src/mpl/include'";
        if ($opts{argobots}) {
            $t_env[-1] =~s/'$/ -I$opts{argobots}\/include'/;
        }
        my $configure = "@t_env ./configure";
        if ($opts{"enable-mpi-abi"}) {
            $configure .= " --enable-mpi-abi";
        }
        my $subdir="src/mpi/romio";
        my $lib_la = "src/mpi/romio/libromio.la";
        my $config_h = "src/mpi/romio/adio/include/romioconf.h";
        my $lib_dep = $config_h;

        my @t = ("cd $subdir");
        push @t, "\x24(DO_stage) Configure ROMIO";
        if (-f "$opts{moddir}/src/mpi/romio/autogen.sh") {
            push @t, "sh autogen.sh";
        }
        else {
            push @t, "autoreconf -ivf";
        }
        push @t, "$configure";
        push @t, "cp $pwd/libtool .";
        push @extra_make_rules, "$config_h: ";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        my $dep = "$config_h";
        my @t = ("cd $subdir");
        push @t, "\x24(MAKE)";
        push @extra_make_rules, "$lib_la: $lib_dep";
        push @extra_make_rules, "\t(".join(' && ', @t).")";
        push @extra_make_rules, "";
        if ($opts{"enable-mpi-abi"}) {
            my @t = ("cd $subdir");
            push @t, "\x24(MAKE) libromio_abi.la";
            push @extra_make_rules, "src/mpi/romio/libromio_abi.la: $lib_dep";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
        }

        $dst_hash{"src/mpi/romio/include/mpio.h"} = "$opts{prefix}/include";
        $dst_hash{"src/mpi/romio/include/mpiof.h"} = "$opts{prefix}/include";
    }
    if ($opts{device}=~/:ucx/) {
        if (!$opts{"with-ucx"} or $opts{"with-ucx"} eq "embedded") {
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
            my $lib_dep = $config_h;

            my @t = ("cd $subdir");
            push @t, "\x24(DO_stage) Configure UCX";
            if (-f "$opts{moddir}/ucx/autogen.sh") {
                push @t, "sh autogen.sh";
            }
            else {
                push @t, "autoreconf -ivf";
            }
            push @t, "$configure";
            push @t, "cp $pwd/libtool .";
            push @extra_make_rules, "$config_h: ";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
            my $dep = "$config_h";
            my @t = ("cd $subdir");
            push @t, "\x24(MAKE)";
            push @extra_make_rules, "$lib_la: $lib_dep";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
        }
        else {
            my $L=$opts{"with-ucx"};
            $I_list .= " -I$L/include";
            if (-e "$L/lib64/libucp.so") {
                $L_list .= " -L$L/lib64 -lucp -luct -lucm -lucs";
            }
            else {
                print "libfabric.so NOT FOUND in $L\n";
            }
        }
    }
    elsif ($opts{device}=~/ch4:ofi/) {
        if (!$opts{"with-libfabric"} || $opts{"with-libfabric"} eq "embedded") {
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
            my $lib_dep = $config_h;

            my @t = ("cd $subdir");
            push @t, "\x24(DO_stage) Configure OFI";
            if (-f "$opts{moddir}/libfabric/autogen.sh") {
                push @t, "sh autogen.sh";
            }
            else {
                push @t, "autoreconf -ivf";
            }
            push @t, "$configure";
            push @t, "cp $pwd/libtool .";
            push @extra_make_rules, "$config_h: ";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
            my $dep = "$config_h";
            my @t = ("cd $subdir");
            push @t, "\x24(MAKE)";
            push @extra_make_rules, "$lib_la: $lib_dep";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
        }
        else {
            my $L=$opts{"with-libfabric"};
            $I_list .= " -I$L/include";
            if (-e "$L/lib64/libfabric.so") {
                $L_list .= " -L$L/lib64 -lfabric";
            }
            else {
                print "libfabric.so NOT FOUND in $L\n";
            }
        }
    }
    elsif ($opts{device}=~/ch3.*:ofi/) {
        if (!$opts{"with-libfabric"} || $opts{"with-libfabric"} eq "embedded") {
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
            my $lib_dep = $config_h;

            my @t = ("cd $subdir");
            push @t, "\x24(DO_stage) Configure OFI";
            if (-f "$opts{moddir}/libfabric/autogen.sh") {
                push @t, "sh autogen.sh";
            }
            else {
                push @t, "autoreconf -ivf";
            }
            push @t, "$configure";
            push @t, "cp $pwd/libtool .";
            push @extra_make_rules, "$config_h: ";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
            my $dep = "$config_h";
            my @t = ("cd $subdir");
            push @t, "\x24(MAKE)";
            push @extra_make_rules, "$lib_la: $lib_dep";
            push @extra_make_rules, "\t(".join(' && ', @t).")";
            push @extra_make_rules, "";
        }
        else {
            my $L=$opts{"with-libfabric"};
            $I_list .= " -I$L/include";
            if (-e "$L/lib64/libfabric.so") {
                $L_list .= " -L$L/lib64 -lfabric";
            }
            else {
                print "libfabric.so NOT FOUND in $L\n";
            }
        }
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
    if ($opts{"enable-mpi-abi"}) {
        my $CC = "\x24(LTCC) -DBUILD_MPI_ABI -Isrc/binding/abi";
        if (!$opts{do_pmpi}) {
            $special_targets{lib_libmpi_abi_la}=$CC;
        }
        else {
            $special_targets{lib_libpmpi_abi_la}=$CC;
            $special_targets{lib_libmpi_abi_la}="$CC -DMPICH_MPI_FROM_PMPI";
        }
    }

    my $bin="\x24(PREFIX)/bin";
    $dst_hash{"mymake/mpicc"}=$bin;
    $dst_hash{"mymake/mpifort"}=$bin;
    $dst_hash{"mymake/mpicxx"}=$bin;
    if ($opts{"enable-mpi-abi"}) {
        $dst_hash{"mymake/mpicc_abi"} = $bin;
    }

    my $ret=0;
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
        my $flag;
        my $f = "confdb/aclocal_subcfg.m4";
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
            if ($l=~/^AC_DEFUN\(\[PAC_CONFIG_SUBDIR_ARGS/) {
                $flag=1;
            }
            elsif ($flag and $l=~/^\]\)/) {
                $l = ":])";
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
            elsif ($l=~/^(\s*)AM_CONDITIONAL.*BUILD_ROMIO/) {
                $l = $1. "AM_CONDITIONAL([BUILD_ROMIO], false)";
            }
            elsif ($l=~/^\s*(PAC_CONFIG_MPL|HWLOC_)/) {
                next;
            }
            elsif ($l=~/^(\s*)PAC_CONFIG_HWLOC/) {
                $l = "$1"."pac_have_hwloc=yes\n";
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
        if ($opts{device}=~/ch3/) {
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
        }
        else {
            if (-f "src/mpid/ch4/shm/ipc/xpmem/subconfigure.m4") {
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
            }
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
        if (!$ret) {
            $ret = system "./configure --with-pm=no $t";
        }
        if (!$ret) {
            $ret = system "mv Makefile mymake/Makefile.orig";
        }
        if (!$ret) {
            $ret = system "mv libtool mymake/libtool.orig";
        }
        if (!$ret) {
            my %need_patch;
            my @lines;
            {
                open In, "mymake/libtool.orig" or die "Can't open mymake/libtool.orig.\n";
                @lines=<In>;
                close In;
            }
            open Out, ">libtool" or die "Can't write libtool: $!\n";
            print "  --> [libtool]\n";
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
                print Out $l;
            }
            close Out;
            system "chmod a+x libtool";
        }
    }


    if ($ret == 0) {
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
    }

    if ($ret == 0) {
        if ($opts{argobots}) {
            $I_list .= " -I$opts{argobots}/include";
        }
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
        $objects{MODDIR}="-";
        $objects{PREFIX}="-";

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

        foreach my $p (@ltlibs) {
            my $a = $p;
            $a=~s/\.exe$//;
            $a=~s/[\.\/]/_/g;
            my $add = $a."_LIBADD";
            my $t = get_make_var($add);
            $t=~s/(\S+\/)?(mpl|pmi|openpa|izem|hwloc|yaksa|json-c|libfabric|ucx)\/\S+\.la\s*//g;
            $t=~s/\@ucxlib\@\s*//g;
            $t=~s/\@ofilib\@\s*//g;

            if (($add=~/libmpi_la_/ && $opts{have_weak}) or ($add=~/libpmpi_la_/)) {
                $t.= $L_list;
            }
            elsif (($add=~/libmpi_abi_la_/ && $opts{have_weak}) or ($add=~/libpmpi_abi_la_/)) {
                $t.= $L_list;
                $t =~s/libromio.la/libromio_abi.la/;
            }
            $objects{$add} = $t;
        }
        foreach my $p (@programs) {
            my $a = $p;
            $a=~s/\.exe$//;
            $a=~s/[\.\/]/_/g;
            my $add = $a."_LDADD";
            my $t = get_make_var($add);
            $t=~s/(\S+\/)?(mpl|pmi|openpa|izem|hwloc|yaksa|json-c|libfabric|ucx)\/\S+\.la\s*//g;
            $t=~s/\@ucxlib\@\s*//g;
            $t=~s/\@ofilib\@\s*//g;

            $objects{$add} = $t;
        }
        dump_makefile("mymake/Makefile.custom", "mymake");

        system "rm -f Makefile";
        system "ln -s mymake/Makefile.custom Makefile";
    }

    if ($ret == 0) {
        open In, "mymake/Makefile.custom" or die "Can't open mymake/Makefile.custom: $!\n";
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
        if (-f "src/env/mpicc.bash") {
            my @lines;
            {
                open In, "src/env/mpicc.bash" or die "Can't open src/env/mpicc.bash.\n";
                @lines=<In>;
                close In;
            }
            my %tmp=(PREFIX=>$opts{prefix}, EXEC_PREFIX=>"$opts{prefix}/bin", SYSCONFDIR=>"$opts{prefix}/etc", INCLUDEDIR=>"$opts{prefix}/include", LIBDIR=>"$opts{prefix}/lib");
            open Out, ">mymake/mpicc" or die "Can't write mymake/mpicc: $!\n";
            print "  --> [mymake/mpicc]\n";
            foreach my $l (@lines) {
                if ($l=~/_TO_BE_FILLED_AT_INSTALL_TIME__/) {
                    $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
                }
                elsif ($l=~/^final_(c|cxx|f|fc)flags="(.*)"/) {
                    my ($c, $flags) = ($1, $2);
                    if ($opts{CFLAGS}=~/-fsanitize=(address|undefined)/) {
                        $l = "final_${c}flags=\"$flags -fsanitize=$1\"\n";
                    }
                }
                print Out $l;
            }
            close Out;
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
            print "  --> [mymake/mpicxx]\n";
            foreach my $l (@lines) {
                if ($l=~/_TO_BE_FILLED_AT_INSTALL_TIME__/) {
                    $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
                }
                elsif ($l=~/^final_(c|cxx|f|fc)flags="(.*)"/) {
                    my ($c, $flags) = ($1, $2);
                    if ($opts{CFLAGS}=~/-fsanitize=(address|undefined)/) {
                        $l = "final_${c}flags=\"$flags -fsanitize=$1\"\n";
                    }
                }
                print Out $l;
            }
            close Out;
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
            print "  --> [mymake/mpifort]\n";
            foreach my $l (@lines) {
                if ($l=~/_TO_BE_FILLED_AT_INSTALL_TIME__/) {
                    $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$tmp{$1}/e;
                }
                elsif ($l=~/^final_(c|cxx|f|fc)flags="(.*)"/) {
                    my ($c, $flags) = ($1, $2);
                    if ($opts{CFLAGS}=~/-fsanitize=(address|undefined)/) {
                        $l = "final_${c}flags=\"$flags -fsanitize=$1\"\n";
                    }
                }
                print Out $l;
            }
            close Out;
        }

        $ENV{CFLAGS}=$opts{CFLAGS};
        my $t="src/mpl/include/mplconfig.h";
        $t=~s/$pwd\///g;

        $ret = system "make $t";
        my $t="src/pmi/include/pmi_config.h";
        $t=~s/$pwd\///g;

        $ret = system "make $t";
    }

    if ($ret == 0) {
        if (-f "src/mpl/include/mpl_atomic.h") {
            open Out, ">mymake/t.c" or die "Can't write mymake/t.c: $!\n";
            print Out "#include \"mpl_atomic.h\"\n";
            print Out "#include <pthread.h>\n";
            print Out "pthread_mutex_t MPL_emulation_lock;\n";
            print Out "int main() { return sizeof(MPL_atomic_ptr_t); }\n";
            close Out;

            my $CC = get_make_var("CC");
            system "$CC -Isrc/mpl/include mymake/t.c -o mymake/t";
            system "mymake/t";
            my $ret = $? >> 8;

            $config_defines{SIZEOF_MPL_ATOMIC_PTR_T} = $ret;
        }
        $config_defines{SIZEOF_OPA_PTR_T} = 8;
        my $lock_based_atomics;
        open In, "src/mpl/include/mplconfig.h" or die "Can't open src/mpl/include/mplconfig.h: $!\n";
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
        if (%config_defines) {
            my (@lines, $cnt);
            open In, "src/mpl/include/mplconfig.h" or die "Can't open src/mpl/include/mplconfig.h: $!\n";
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
                open Out, ">src/mpl/include/mplconfig.h" or die "Can't write src/mpl/include/mplconfig.h: $!\n";
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
    }

}

# ---- subroutines --------------------------------------------
sub find_python3 {
    if (`python -V 2>&1` =~ /Python\s*3/) {
        return "python";
    }
    if (`python3 -V 2>&1` =~ /Python\s*3/) {
        return "python3";
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
            $t=~s/\$\((\w+)\)/get_make_var($1)/ge;
            push @t, $t;
        }
    }
    return \@t;
}

sub get_make_var {
    my ($name) = @_;
    my $t = $objects{$name};
    if ($t eq "-") {
        return "\x24($name)";
    }
    if (defined $t) {
        if (ref($t) eq "ARRAY") {
            $t = join(' ', @$t);
        }
        $t=~s/\$\((\w+)\)/get_make_var($1)/ge;
        $t=~s/\s+/ /g;

        $t=~s/$opts{moddir}/\x24(MODDIR)/g;
        return $t;
    }
    elsif ($name=~/^am__v_\w+/) {
        return "";
    }
    else {
        return "";
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
    if ($makefile eq "Makefile" or $makefile eq "mymake/Makefile.custom") {
        $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
        $t=~s/-I\S+\/ucx\/src//g;
        $t=~s/-I\S+\/json-c//g;
    }
    elsif ($makefile =~/hydra/) {
        $t=~s/-I\S+\/(mpl)\/\S+\s*//g;
    }
    print Out "AM_CPPFLAGS = $t\n";
    my $t = get_make_var_unique("CPPFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    if ($makefile eq "Makefile" or $makefile eq "mymake/Makefile.custom") {
        $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
        $t=~s/-I\S+\/ucx\/src//g;
        $t=~s/-I\S+\/json-c//g;
    }
    elsif ($makefile =~/hydra/) {
        $t=~s/-I\S+\/(mpl)\/\S+\s*//g;
    }
    if ($opts{"with-cuda"}) {
        my $p = $opts{"with-cuda"};
        $I_list .= " -I$p/include";
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
    if ($opts{"with-cuda"}) {
        $t .= " -L".$opts{"with-cuda"}."/lib64";
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
        print Out "LTCC = $lt --mode=compile $lt_opt --tag=CC \x24(COMPILE)\n";
        if (!$opts{quick} or !$ENV{"USE_MYMAKE_LD"} or $ENV{CC}) {
            print Out "LTLD = $lt --mode=link $lt_opt --tag=CC \x24(LINK)\n";
        }
        else {
            print Out "LTLD = perl $opts{mymake}_ld.pl \"lt=$lt\" \x24(LINK)\n";
        }
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
            elsif ($opts{ld_default}) {
                $ld = $opts{ld_default};
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/\.exe$//;
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
            elsif ($opts{ld_default}) {
                $ld = $opts{ld_default};
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/\.exe$//;
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
    print Out "%.o: %.f\n";
    if ($opts{V}==0) {
        print Out "\t\@echo FC \$\@ && \x24(FCCOMPILE) -c -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(FCCOMPILE) -c -o \$\@ \$<\n";
    }
    print Out "\n";
    print Out "%.o: %.f90\n";
    if ($opts{V}==0) {
        print Out "\t\@echo FC \$\@ && \x24(FCCOMPILE) -c -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(FCCOMPILE) -c -o \$\@ \$<\n";
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
        if ($opts{"with-cuda"}) {
            print Out "%.lo: %.cu\n";
            if ($opts{V}==0) {
                print Out "\t\@echo NVCC \$\@ && confdb/cudalt.sh \$\@ nvcc -c \x24(AM_CPPFLAGS) \$<\n";
            }
            else {
                print Out "\tconfdb/cudalt.sh \$\@ nvcc -c \x24(AM_CPPFLAGS) \$<\n";
            }
            print Out "\n";
        }
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
    my @dst_keys = sort keys %dst_hash;
    if ($dst_hash{'lib/libpmpi.la'}) {
        foreach my $k (@dst_keys) {
            if ($k eq "lib/libpmpi.la") {
                $k = "lib/libmpi.la";
            }
            elsif ($k eq "lib/libmpi.la") {
                $k = "lib/libpmpi.la";
            }
        }
    }

    foreach my $k (@dst_keys) {
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
                if (!$opts{quick}) {
                    push @install_list, "$lt --mode=install $lt_opt install $k $v";
                }
                else {
                    push @install_list, "perl $opts{mymake}_install.pl $k $v";
                }
                push @install_deps, $k;
            }
            elsif ($v=~/\/bin$/) {
                if (!$opts{quick}) {
                    push @install_list, "$lt --mode=install $lt_opt install $k $v";
                }
                else {
                    push @install_list, "perl $opts{mymake}_install.pl $k $v";
                }
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
    my ($p) = @_;
    my $a = $p;
    $a=~s/\.exe$//;
    $a=~s/[\.\/]/_/g;

    my $tlist = get_list("${a}_OBJECTS");
    my @tlist = sort @$tlist;
    foreach my $t (@tlist) {
        $t =~s/[^\/]+-//g;
    }
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

