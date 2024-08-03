#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our $config;
our $config_in;
our $config_out;
our $config_prefix;
our %config_defines;
our %config_cflags;
our %config_ldflags;
our %hash_defines;
our %hash_define_vals;
our $version;
our %sizeof_hash;
our %headers_hash;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
$config = shift @ARGV;
print "-- mymake_config $config ...\n";

if ($config eq "mpich") {
    $config_in = "$mymake_dir/config_templates/mpichconf.h";
    $config_out = "src/include/mpichconf.h";
}
elsif ($config eq "mpl") {
    $config_prefix = "mpl";
    $config_in = "$mymake_dir/config_templates/mplconfig.h";
    $config_out = "src/mpl/include/mplconfig.h";
    symlink "../../libtool", "src/mpl/libtool";
    symlink "../../confdb", "src/mpl/confdb";
}
elsif ($config eq "pmi") {
    $config_in = "$mymake_dir/config_templates/pmi_config.h";
    $config_out = "src/pmi/include/pmi_config.h";
    symlink "../../libtool", "src/pmi/libtool";
}
elsif ($config eq "opa") {
    $config_prefix = "opa";
    $config_in = "$mymake_dir/config_templates/opa_config.h";
    $config_out = "mymake/openpa/src/opa_config.h";
    symlink "../../../libtool", "mymake/openpa/src/libtool";
}
elsif ($config eq "hydra") {
    $config_in = "$mymake_dir/config_templates/hydra_config.h";
    if (-d "src/pm/hydra/include") {
        $config_out = "src/pm/hydra/include/hydra_config.h";
    }
    else {
        $config_out = "src/pm/hydra/hydra_config.h";
    }
    symlink "../../../libtool", "src/pm/hydra/libtool";
}
elsif ($config eq "test") {
    my $MPICC = "mpicc";
    if ($opts{"enable-mpi-abi"}) {
        $MPICC = "mpicc_abi";
    }
    $config_in = "$mymake_dir/config_templates/mpitestconf.h";
    $config_out = "test/mpi/include/mpitestconf.h";
    if ($ENV{CC}) {
        system "sed -e 's/\"$ENV{CC}\"/\"$MPICC\"/' libtool > test/mpi/libtool";
    }
    else {
        system "sed -e 's/\"gcc\"/\"$MPICC\"/' libtool > test/mpi/libtool";
    }
    system "chmod a+x test/mpi/libtool";
}
elsif ($config eq "dtpools") {
    $config_in = "$mymake_dir/config_templates/dtpoolsconf.h";
    $config_out = "test/mpi/dtpools/dtpoolsconf.h";
    symlink "../../../libtool", "test/mpi/dtpools/libtool";
}
elsif ($config eq "romio") {
    $config_in = "$mymake_dir/config_templates/romioconf.h";
    $config_out = "src/mpi/romio/adio/include/romioconf.h";
    symlink "../../../libtool", "src/mpi/romio/libtool";
}
else {
    die "Usage: $0 [mpich]\n";
}

if (-e "mymake/opts") {
    open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
    while(<In>){
        if (/^(\S+): (.*)/) {
            $opts{$1} = $2;
        }
    }
    close In;
}
$hash_defines{"disable-ch4-ofi-ipv6"} = "MPIDI_CH4_OFI_SKIP_IPV6";
$hash_defines{"enable-legacy-ofi"} = "MPIDI_ENABLE_LEGACY_OFI";
$hash_defines{"enable-ch4-am-only"} = "MPIDI_ENABLE_AM_ONLY";
$hash_defines{"with-ch4-max-vcis"} = "MPIDI_CH4_MAX_VCIS";
$hash_defines{"with-ch4-rank-bits"} = "CH4_RANK_BITS";
$hash_defines{"enable-nolocal"} = "ENABLE_NO_LOCAL";
$hash_defines{"enable-izem-queue"} = "ENABLE_IZEM_QUEUE";
$hash_defines{"enable-mpit-events"} = "HAVE_MPIT_EVENTS";

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

my $t;
{
    open In, "mymake/args" or die "Can't open mymake/args.\n";
    local $/;
    $t=<In>;
    close In;
}
my @tlist = split /\s+/, $t;
foreach my $a (@tlist, @ARGV) {
    if (0) {
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
            elsif ($t eq "progress") {
                $config_defines{MPICH_DEBUG_PROGRESS} = 1;
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

open In, "maint/version.m4" or die "Can't open maint/version.m4: $!\n";
while(<In>){
    if (/m4_define\(\[MPICH_VERSION_m4\],\[(.*)\]/) {
        $version = $1;
        last;
    }
}
close In;

if ($ENV{CC}) {
    $opts{CC} = $ENV{CC};
}
else {
    $opts{CC} = "gcc";
}
if ($ENV{CXX}) {
    $opts{CXX} = $ENV{CXX};
}
else {
    $opts{CXX} = "g++";
}
if ($ENV{F77}) {
    $opts{F77} = $ENV{F77};
}
else {
    $opts{F77} = "gfortran";
}
if ($ENV{FC}) {
    $opts{FC} = $ENV{FC};
}
else {
    $opts{FC} = "gfortran";
}
$opts{cc_version} = get_cc_version($opts{CC});
if ($opts{cc_version}=~/gcc 4/) {
    $opts{CC} .= " -std=gnu99";
}
my @header_list=("stdio.h");
my @type_list=("void *", "char", "short", "int", "long", "long long", "size_t", "off_t", "float", "double", "long double");
if ($config eq "mpich") {
    push @type_list, "pair:short";
    push @type_list, "pair:int";
    push @type_list, "pair:long";
    push @type_list, "pair:float";
    push @type_list, "pair:double";
    push @type_list, "pair:long double";

    push @header_list, "stdint.h";
    push @type_list, "int8_t", "uint8_t";
    push @type_list, "int16_t", "uint16_t";
    push @type_list, "int32_t", "uint32_t";
    push @type_list, "int64_t", "uint64_t";

    push @header_list, "stdbool.h";
    push @type_list, "bool";

    push @type_list, "float _Complex";
    push @type_list, "double _Complex";
    push @type_list, "long double _Complex";
}
get_sizeof(\@type_list, \@header_list);

if ($config eq "mpich") {
    get_sizeof(["_Bool"], ["stdio.h"]);
    get_sizeof(["__float128"], ["stdio.h"]);
    get_sizeof(["_Float16"], ["stdio.h"]);
    get_sizeof(["wchar_t"], ["stdio.h", "stddef.h"]);
    $config_defines{SIZEOF__FLOAT16}=0;
    $config_defines{SIZEOF___FLOAT128}=0;
    $config_defines{SIZEOF_WCHAR_T}=0;

    if ($sizeof_hash{VOID_P}==$sizeof_hash{INT}) {
        $config_defines{MAX_ALIGNMENT} = 4;
    }
    else {
        $config_defines{MAX_ALIGNMENT} = 16;
    }

    $config_defines{MPIR_Ufint} = "unsigned int";
    my $MPI_AINT;
    if ($sizeof_hash{VOID_P}==$sizeof_hash{INT}) {
        $MPI_AINT = "int";
        $config_defines{MPIR_AINT_MAX} = 'INT_MAX';
    }
    elsif ($sizeof_hash{VOID_P}==$sizeof_hash{LONG}) {
        $MPI_AINT = "long";
        $config_defines{MPIR_AINT_MAX} = 'LONG_MAX';
    }
    elsif ($sizeof_hash{VOID_P}==$sizeof_hash{LONG_LONG}) {
        $MPI_AINT = "long long";
        $config_defines{MPIR_AINT_MAX} = 'LONG_LONG_MAX';
    }

    if ($sizeof_hash{LONG} == $sizeof_hash{LONG_LONG}) {
        $config_defines{MPIR_COUNT_MAX} = 'LONG_MAX';
        $config_defines{MPIR_OFFSET_MAX} = 'LONG_MAX';
        $config_defines{MPIR_Ucount} = "unsigned long";
    }
    else {
        $config_defines{MPIR_COUNT_MAX} = 'LONG_LONG_MAX';
        $config_defines{MPIR_OFFSET_MAX} = 'LONG_LONG_MAX';
        $config_defines{MPIR_Ucount} = "unsigned long long";
    }
    $config_defines{HAVE_LONG_LONG_INT} = 1;

    $sizeof_hash{MPII_BSEND_DATA_T} = 96;
}

my @header_list;
open In, "$config_in" or die "Can't open $config_in: $!\n";
while(<In>){
    if (/#undef HAVE_(\w+)_H\b/) {
        my $h=lc($1).".h";
        $h=~s/_/\//g;
        push @header_list, $h;
    }
}
close In;
get_have_headers(\@header_list);
$config_defines{STDC_HEADERS}=1;
$config_defines{HAVE_ANY_INT64_T_ALIGNMENT}=1;
$config_defines{HAVE_ANY_INT32_T_ALIGNMENT}=1;
$config_defines{LT_OBJDIR} = '".libs/"';

$config_defines{HAVE__FUNC__}="\x2f**/";
$config_defines{HAVE__FUNCTION__}="\x2f**/";
$config_defines{HAVE_WEAK_ATTRIBUTE}=1;
$config_defines{HAVE_PRAGMA_WEAK}=1;
$config_defines{HAVE_MULTIPLE_PRAGMA_WEAK}=1;
$config_defines{HAVE_GCC_ATTRIBUTE}=1;
$config_defines{HAVE_MACRO_VA_ARGS}=1;
$config_defines{HAVE_VA_COPY}=1;
$config_defines{HAVE_VISIBILITY}=1;
$config_defines{HAVE_BUILTIN_EXPECT}=1;
$config_defines{HAVE_C11__STATIC_ASSERT}=1;
$config_defines{HAVE_H_ADDR_LIST}=1;
$config_defines{HAVE_SCHED_GETAFFINITY}=1;
$config_defines{HAVE_SCHED_SETAFFINITY}=1;
$config_defines{HAVE_SETITIMER}=1;
$config_defines{HAVE_STRUCT_RANDOM_DATA}=1;
$config_defines{USE_WEAK_SYMBOLS}=1;
$config_defines{WORDS_LITTLEENDIAN}=1;

$config_defines{restrict} = '__restrict';
$config_defines{HAVE_FC_TYPE_ROUTINES} = 1;

$config_defines{HAVE_ALARM}=1;
$config_defines{HAVE_ALLOCA}=1;
$config_defines{HAVE_GETHOSTNAME}=1;
$config_defines{HAVE_PUTENV}=1;
$config_defines{HAVE_QSORT}=1;
$config_defines{HAVE_RANDOM_R}=1;
$config_defines{HAVE_SIGNAL}=1;
$config_defines{HAVE_SNPRINTF}=1;
$config_defines{HAVE_STRDUP}=1;
$config_defines{HAVE_STRERROR}=1;
$config_defines{HAVE_STRERROR_R}=1;
$config_defines{HAVE_STRNCMP}=1;
$config_defines{HAVE_STRNCASECMP}=1;
$config_defines{HAVE_VSNPRINTF}=1;
$config_defines{HAVE_VSPRINTF}=1;
$config_defines{HAVE_MKSTEMP}=1;
$config_defines{HAVE_CPU_SET_T}=1;
$config_defines{HAVE_CPU_SET_MACROS}=1;
$config_defines{HAVE_DECL_STRERROR_R}=1;
$config_defines{HAVE_POSIX_MEMALIGN}=1;
$config_defines{HAVE_SELECT}=1;
$config_defines{HAVE_SCHED_YIELD}=1;
$config_defines{HAVE_PTHREAD_YIELD}=1;
$config_defines{HAVE_MMAP}=1;
$config_defines{HAVE_MUNMAP}=1;
$config_defines{HAVE_INET_PTON}=1;

if ($opts{uname}=~/Linux/i) {
    $config_defines{USE_SYM_HEAP} = 1;
    $config_defines{STRERROR_R_CHAR_P} = 1;
}
if ($opts{uname}=~/Darwin/i) {
    $config_defines{HAVE_WEAK_ATTRIBUTE} = undef;
    $config_defines{HAVE_PRAGMA_WEAK} = undef;
    $config_defines{HAVE_MULTIPLE_PRAGMA_WEAK} = undef;
    $config_defines{USE_WEAK_SYMBOLS} = undef;
    $opts{cc_weak} = "no";
    $opts{cflags} = "-O2 -fno-common -g";
}

if ($config eq "mpich") {
    my %make_conds;
    $config_defines{PACKAGE}='"mpich"';
    $config_defines{PACKAGE_BUGREPORT}='"discuss@mpich.org"';
    $config_defines{PACKAGE_NAME}='"MPICH"';
    $config_defines{PACKAGE_STRING}="\"MPICH $version\"";
    $config_defines{PACKAGE_TARNAME}='"mpich"';
    $config_defines{PACKAGE_URL}='"http://www.mpich.org/"';
    $config_defines{PACKAGE_VERSION}="\"$version\"";
    $config_defines{VERSION}="\"$version\"";

    $config_defines{_ALL_SOURCE}=1;
    $config_defines{_GNU_SOURCE}=1;
    $config_defines{_POSIX_PTHREAD_SEMANTICS}=1;
    $config_defines{_TANDEM_SOURCE}=1;
    $config_defines{__EXTENSIONS__}=1;
    my %temp;
    $temp{HAVE_MPICHCONF}=1;

    $temp{uc("ENABLE_PVAR_nem")} = 0;
    $temp{uc("ENABLE_PVAR_recvq")} = 0;
    $temp{uc("ENABLE_PVAR_rma")} = 0;
    $temp{uc("ENABLE_PVAR_dims")} = 0;
    $temp{HAVE_TAG_ERROR_BITS} = 1;
    $temp{USE_PMI_PORT} = 1;
    $temp{HAVE_NAMEPUB_SERVICE} = 1;
    $temp{HAVE_HWLOC} = 1;

    if ($opts{"disable-error-checking"}) {
    }
    else {
        $temp{HAVE_ERROR_CHECKING}='MPID_ERROR_LEVEL_RUNTIME';
    }
    $temp{MPICH_ERROR_MSG_LEVEL} = 'MPICH_ERROR_MSG__ALL';
    $temp{MPICH_IS_THREADED} = 1;
    $temp{MPICH_THREAD_LEVEL} = 'MPI_THREAD_MULTIPLE';

    $temp{TRUE} = 1;
    $temp{FALSE} = 0;
    $temp{F77_NAME_LOWER_USCORE} = 1;
    $temp{HAVE_AINT_DIFFERENT_THAN_FINT} = 1;

    $temp{ENABLE_PMI1} = 1;
    $temp{ENABLE_PMI2} = 1;
    $temp{ENABLE_PMIX} = 1;
    if ($opts{"with-pmix"}) {
        $temp{ENABLE_PMI1} = undef;
        $temp{ENABLE_PMI2} = undef;
    }

    if (!$opts{disable_romio}) {
        $temp{HAVE_ROMIO} = 1;
    }
    if ($opts{device}=~/ch4/) {
        $temp{MPICH_THREAD_GRANULARITY} = 'MPICH_THREAD_GRANULARITY__VCI';
        $temp{MPICH_THREAD_REFCOUNT} = 'MPICH_REFCOUNT__LOCKFREE';
        if ($opts{"without-ch4-shmmods"}) {
            $temp{MPIDI_CH4_DIRECT_NETMOD} = 1;
        }
        if ($opts{"enable-ch4-am-only"}) {
            $temp{MPIDI_ENABLE_AM_ONLY} = 1;
        }
        $temp{MPIDI_BUILD_CH4_LOCALITY_INFO}=1;
        $temp{MPIDI_CH4U_USE_PER_COMM_QUEUE}=1;
        $temp{MPIDI_CH4_MAX_VCIS}=64;
        $temp{MPIDI_CH4_USE_MT_DIRECT}=1;
        $temp{MPIDI_CH4_VCI_METHOD}='MPICH_VCI__COMM';
        $temp{HAVE_CH4_SHM_EAGER_IQUEUE}=1;
        $temp{ENABLE_LOCAL_SESSION_INIT}=1;
        $temp{ENABLE_THREADCOMM}=1;

        if (!$temp{MPIDI_CH4_DIRECT_NETMOD}) {
            if ($opts{"with-cuda"}) {
                $temp{MPIDI_CH4_SHM_ENABLE_GPU}=1;
                $make_conds{BUILD_SHM_IPC_GPU} = 1;
            }
            if ($opts{"with-xpmem"}) {
                $temp{MPIDI_CH4_SHM_ENABLE_XPMEM}=1;
                $make_conds{BUILD_SHM_IPC_XPMEM} = 1;
            }
            if ($opts{"with-cma"}) {
                $temp{MPIDI_CH4_SHM_ENABLE_CMA}=1;
                $make_conds{BUILD_SHM_IPC_CMA} = 1;
            }
        }

        if ($opts{device}=~/ch4:ucx/) {
            $temp{HAVE_CH4_NETMOD_UCX}=1;
            $temp{HAVE_LIBUCP} = 1;
            $temp{HAVE_UCP_PUT_NB}=1;
            $temp{HAVE_UCP_GET_NB}=1;
            $temp{CH4_UCX_RANKBITS}=16;
        }
        elsif ($opts{device}=~/ch4:ofi/) {
            $temp{HAVE_CH4_NETMOD_OFI}=1;
            $temp{MPIDI_OFI_VNI_USE_DOMAIN}=1;
            $temp{HAVE_LIBFABRIC_NIC}=1;
            if ($opts{device}=~/ch4:ofi:(\w+)/) {
                my ($set) = ($1);
                $set = uc($set);
                $temp{"MPIDI_CH4_OFI_USE_SET_$set"}=1;
            }
            else {
                $temp{MPIDI_CH4_OFI_USE_SET_RUNTIME}=1;
            }
            $temp{ENABLE_PVAR_MULTINIC}=0;
        }
    }
    elsif ($opts{device}=~/ch3/) {
        $temp{MPICH_THREAD_GRANULARITY} = 'MPICH_THREAD_GRANULARITY__GLOBAL';
        $temp{MPICH_THREAD_REFCOUNT} = 'MPICH_REFCOUNT__NONE';
        $temp{CH3_RANK_BITS} = 16;
        $temp{PREFETCH_CELL}=1;
        $temp{USE_FASTBOX}=1;
        if ($opts{device}=~/ch3:sock/) {
        }
        else {
            $temp{MPID_NEM_INLINE}=1;
            $temp{MPID_NEM_LOCAL_LMT_IMPL}="MPID_NEM_LOCAL_LMT_SHM_COPY";
        }
    }

    if ($opts{"with-datatype-engine"} eq "dataloop") {
        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_DATALOOP';
    }
    elsif ($opts{"with-datatype-engine"} eq "yaksa") {
        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_YAKSA';
    }
    elsif ($opts{device}=~/ch3/) {
        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_DATALOOP';
    }
    else {
        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_YAKSA';
    }

    if ($opts{device} =~ /ch4/) {
        if (-f "src/mpid/ch4/shm/posix/posix_eager_array.c.in") {
            my $eager_modules;
            if (-f "src/mpid/ch4/shm/posix/eager/iqueue/iqueue_pre.h") {
                $eager_modules="iqueue";
            }
            else {
                $eager_modules="fbox";
            }
            if ($opts{"with-ch4-posix-eager-modules"}) {
                $eager_modules = $opts{"with-ch4-posix-eager-modules"};
            }
            my @eager_list = split /\s+/, $eager_modules;

            my %confs;
            $confs{ch4_posix_eager_array_sz} = @eager_list;
            my $a = $eager_list[0];
            $confs{ch4_posix_eager_func_array} = "\&MPIDI_POSIX_eager_${a}_funcs";
            $confs{ch4_posix_eager_strings} = "\"${a}\"";
            $confs{ch4_posix_eager_func_decl} = "MPIDI_POSIX_eager_${a}_funcs";

            $confs{ch4_posix_eager_pre_include} = "#include \"../${a}/${a}_pre.h\"";
            $confs{ch4_posix_eager_recv_transaction_decl} = "MPIDI_POSIX_eager_${a}_recv_transaction_t ${a};";

            autoconf_file("src/mpid/ch4/shm/posix/posix_eager_array.c", \%confs);
            autoconf_file("src/mpid/ch4/shm/posix/eager/include/posix_eager_pre.h", \%confs);
        }
        if (-f "src/mpid/ch4/include/coll_algo_params.h.in") {
            my $net;
            if ($opts{device}=~/ch4:ofi/) {
                $net="ofi";
            }
            elsif ($opts{device}=~/ch4:ucx/) {
                $net="ucx";
            }
            my $NET=uc($net);

            my %confs;
            $confs{ch4_netmod_coll_globals_default}="#include \"../netmod/${net}/${net}_coll_globals_default.c\"";
            $confs{ch4_netmod_coll_params_include} ="#include \"../netmod/${net}/${net}_coll_params.h\"";
            open In, "src/mpid/ch4/include/coll_algo_params.h.in" or die "Can't open src/mpid/ch4/include/coll_algo_params.h.in: $!\n";
            while(<In>){
                if (/\@ch4_netmod_(\w+)_params_decl\@/) {
                    my $COLL=uc($1);
                    my $key = "ch4_netmod_".$1."_params_decl";
                    $confs{$key} = "MPIDI_${NET}_${COLL}_PARAMS_DECL;";
                }
            }
            close In;

            autoconf_file("src/mpid/ch4/include/coll_algo_params.h", \%confs);
            autoconf_file("src/mpid/ch4/src/ch4_coll_globals_default.c", \%confs);
        }
        my @net_list;
        if ($opts{device}=~/ch4:ofi/) {
            push @net_list, "ofi";
        }
        elsif ($opts{device} =~/ch4:ucx/) {
            push @net_list, "ucx";
        }

        if (@net_list) {
            my %confs;
            $confs{ch4_nets_array_sz} = @net_list;
            my $a = $net_list[0];
            my $A = uc($a);
            $confs{ch4_nets_func_array} = "\&MPIDI_NM_${a}_funcs";
            $confs{ch4_nets_native_func_array} = "\&MPIDI_NM_native_${a}_funcs";
            $confs{ch4_nets_strings} = "\"${a}\"";
            $confs{ch4_nets_func_decl} = "MPIDI_NM_${a}_funcs";
            $confs{ch4_nets_native_func_decl} = "MPIDI_NM_native_${a}_funcs";

            $confs{ch4_netmod_pre_include} = "#include \"../netmod/${a}/${a}_pre.h\"";
            $confs{ch4_netmod_amrequest_decl} = "MPIDI_${A}_am_request_t $a;";
            $confs{ch4_netmod_request_decl} = "MPIDI_${A}_request_t $a;";
            $confs{ch4_netmod_comm_decl} = "MPIDI_${A}_comm_t $a;";
            $confs{ch4_netmod_dt_decl} = "MPIDI_${A}_dt_t $a;";
            $confs{ch4_netmod_win_decl} = "MPIDI_${A}_win_t $a;";
            $confs{ch4_netmod_addr_decl} = "MPIDI_${A}_addr_t $a;";
            $confs{ch4_netmod_op_decl} = "MPIDI_${A}_op_t $a;";

            autoconf_file("src/mpid/ch4/src/mpid_ch4_net_array.c", \%confs);
            autoconf_file("src/mpid/ch4/include/netmodpre.h", \%confs);
        }
    }
    elsif ($opts{device} =~ /ch3/ and $opts{device}!~/:sock/) {
        my %confs;
        my $a = "tcp";
        if ($opts{device} =~/ch3:.*:ofi/) {
            $a = "ofi";
        }
        $confs{nemesis_nets_array_sz} = 1;
        $confs{nemesis_nets_func_decl} = "MPIDI_nem_${a}_funcs";
        $confs{nemesis_nets_func_array} = "\&MPIDI_nem_${a}_funcs";
        $confs{nemesis_nets_strings} = "\"$a\"";

        my $A=uc($a);
        $confs{nemesis_nets_macro_defs} = "#define MPIDI_NEM_${A} 0";

        autoconf_file("src/mpid/ch3/channels/nemesis/src/mpid_nem_net_array.c", \%confs);
        autoconf_file("src/mpid/ch3/channels/nemesis/include/mpid_nem_net_module_defs.h", \%confs);
    }

    if (!$opts{disable_fortran}) {
        $temp{HAVE_NO_FORTRAN_MPI_TYPES_IN_C} = 1;
        $temp{HAVE_FORTRAN_BINDING} = 1;
        if ($sizeof_hash{VOID_P} > $sizeof_hash{INT}) {
            $temp{HAVE_AINT_LARGER_THAN_FINT} = 1;
        }
        $temp{MPIR_FC_REAL_CTYPE} = "float";
        $temp{MPIR_FC_DOUBLE_CTYPE} = "double";
        my %confs;
        $confs{MPI_STATUS_SIZE} = 5;
        $confs{CMB_1INT_ALIGNMENT}='__attribute__((aligned(16)))';
        $confs{CMB_STATUS_ALIGNMENT}='__attribute__((aligned(32)))';
        autoconf_file("src/binding/fortran/mpif_h/setbot.c", \%confs);
        autoconf_file("src/binding/fortran/mpif_h/setbotf.f", \%confs);
    }
    if (0) {
        $temp{HAVE_NAMESPACES}=1;
        $temp{HAVE_NAMESPACE_STD}=1;
    }
    while (my ($k, $v) = each %temp) {
        if (!exists $config_defines{$k}) {
            $config_defines{$k} = $v;
        }
    }
    my %confs;
    $confs{BASH_SHELL} = "/bin/bash";
    $confs{LDFLAGS} = $ENV{LDFLAGS};
    if ($opts{"with-cuda"}) {
        my $p = $opts{"with-cuda"};
        $confs{LDFLAGS} .= "  -Wl,-rpath -Wl,$p/lib64";
    }
    $confs{LIBS} = $ENV{LIBS};
    $confs{MPILIBNAME} = "mpi";
    $confs{PMPILIBNAME} = "pmpi";
    $confs{MPIABILIBNAME} = "mpi_abi";
    if ($opts{cc_weak} eq "no") {
        $confs{LPMPILIBNAME} = "-lpmpi";
    }
    else {
        $confs{LPMPILIBNAME} = "";
    }
    $confs{MPICH_VERSION} = $version;
    $confs{CC} = $opts{CC};
    $confs{CXX} = $opts{CXX};
    $confs{FC} = $opts{FC};
    $confs{FCINC} = "-I";
    $confs{with_wrapper_dl_type} = "runpath";
    $confs{INTERLIB_DEPS} = "yes";
    $confs{MPIFCLIBNAME} = "mpifort";

    $confs{WRAPPER_CFLAGS}="";
    $confs{WRAPPER_CPPFLAGS}="";
    $confs{WRAPPER_LDFLAGS}="";
    $confs{WRAPPER_LIBS} = "";

    if ($opts{CFLAGS}=~/-fsanitize=(address|undefined)/) {
        $confs{WRAPPER_CFLAGS} .= " -fsanitize=$1";
    }

    my $tag="cc";
    open In, "libtool" or die "Can't open libtool: $!\n";
    while(<In>){
        if (/^wl=/) {
            $confs{"${tag}_shlib_conf"} .= $_;
        }
        if (/^hardcode_libdir_flag_spec=/) {
            $confs{"${tag}_shlib_conf"} .= $_;
            if ($opts{uname}=~/Linux/i) {
                my $dtags="enable_dtags_flag=\"\\\$wl--enable-new-dtags\"\n";
                $dtags  .="disable_dtags_flag=\"\\\$wl--disble-new-dtags\"\n";
                $confs{"${tag}_shlib_conf"} .= $dtags;
            }
        }
        elsif (/# ### BEGIN LIBTOOL TAG CONFIG: (\w+)/) {
            $tag = lc($1);
        }
    }
    close In;
    $confs{PREFIX}=$opts{prefix};
    $confs{EXEC_PREFIX}="$opts{prefix}/bin";
    $confs{SYSCONFDIR}="$opts{prefix}/etc";
    $confs{INCLUDEDIR}="$opts{prefix}/include";
    $confs{LIBDIR}="$opts{prefix}/lib";

    foreach my $p ("cc", "cc_abi", "cxx", "f77", "fort") {
        my $P = uc($p);
        $confs{"MPICH_MPI${P}_CFLAGS"}="";
        $confs{"MPICH_MPI${P}_CPPFLAGS"}="";
        $confs{"MPICH_MPI${P}_LDFLAGS"}="";
        $confs{"MPICH_MPI${P}_LIBS"}="";

        my $script = "src/env/mpi$p.bash.in";
        if ($opts{sh}) {
            $script = "src/env/mpi$p.sh.in";
        }
        if (-f $script) {
            my @lines;
            {
                open In, "$script" or die "Can't open $script.\n";
                @lines=<In>;
                close In;
            }
            open Out, ">mymake/mpi$p" or die "Can't write mymake/mpi$p: $!\n";
            print "  --> [mymake/mpi$p]\n";
            foreach my $l (@lines) {
                if ($l=~/cxxlibs="-l"/) {
                    print Out "    cxxlibs=\n";
                    next;
                }
                $l=~s/\@(\w+)\@/$confs{$1}/g;
                $l=~s/__(\w+)_TO_BE_FILLED_AT_INSTALL_TIME__/$confs{$1}/;
                print Out $l;
            }
            close Out;
        }
    }
    my %confs;
    $confs{MPICH_VERSION} = $version;
    my %ext_hash=(a=>0, b=>1, rc=>2, p=>3);
    if ($version=~/^(\d+)\.(\d+)\.(\d+)/) {
        my ($major, $minor, $rev) = ($1, $2, $3);
        $confs{MPICH_NUMVERSION} = sprintf("%d%02d%02d%d%02d", $major, $minor, $rev, 0, 0);
    }
    elsif ($version=~/^(\d+)\.(\d+)([a-z]+)(\d*)/) {
        my ($major, $minor, $ext, $patch) = ($1, $2, $3, $4);
        $confs{MPICH_NUMVERSION} = sprintf("%d%02d%02d%d%02d", $major, $minor, 0, $ext_hash{$ext}, $patch);
    }

    $confs{MPIU_DLL_SPEC_DEF}="#define MPIU_DLL_SPEC";

    $confs{DISABLE_TAG_SUPPORT}="#define NO_TAGS_WITH_MODIFIERS 1";
    if ($ENV{MPID_MAX_PROCESSOR_NAME}) {
        $confs{MPI_MAX_PROCESSOR_NAME}=$ENV{MPID_MAX_PROCESSOR_NAME};
    }
    else {
        $confs{MPI_MAX_PROCESSOR_NAME}=128;
    }
    if ($ENV{MPID_MAX_LIBRARY_VERSION_STRING}) {
        $confs{MPI_MAX_LIBRARY_VERSION_STRING}=$ENV{MPID_MAX_LIBRARY_VERSION_STRING};
    }
    else {
        $confs{MPI_MAX_LIBRARY_VERSION_STRING}=8192;
    }
    if ($ENV{MPID_MAX_ERROR_STRING}) {
        $confs{MPI_MAX_ERROR_STRING}=$ENV{MPID_MAX_ERROR_STRING};
    }
    else {
        $confs{MPI_MAX_ERROR_STRING}=512;
    }
    $sizeof_hash{AINT} = $sizeof_hash{VOID_P};
    $sizeof_hash{OFFSET} = $sizeof_hash{VOID_P};

    if ($sizeof_hash{VOID_P}==$sizeof_hash{INT}) {
        $confs{MPI_AINT} = "int";
        $confs{MPI_AINT_FMT_DEC_SPEC}='%d';
        $confs{MPI_AINT_FMT_HEX_SPEC}='%x';
    }
    elsif ($sizeof_hash{VOID_P}==$sizeof_hash{LONG}) {
        $confs{MPI_AINT} = "long";
        $confs{MPI_AINT_FMT_DEC_SPEC}='%ld';
        $confs{MPI_AINT_FMT_HEX_SPEC}='%lx';
    }
    elsif ($sizeof_hash{VOID_P}==$sizeof_hash{LONG_LONG}) {
        $confs{MPI_AINT} = "long long";
        $confs{MPI_AINT_FMT_DEC_SPEC}='%lld';
        $confs{MPI_AINT_FMT_HEX_SPEC}='%llx';
    }

    $confs{MPI_FINT} = "int";

    if ($sizeof_hash{LONG} == 8) {
        $sizeof_hash{COUNT} = $sizeof_hash{LONG};
        $confs{MPI_COUNT} = "long";
    }
    else {
        $sizeof_hash{COUNT} = $sizeof_hash{LONG_LONG};
        $confs{MPI_COUNT} = "long long";
    }

    $confs{MPI_OFFSET_TYPEDEF} = "typedef $confs{MPI_AINT} MPI_Offset;";
    if (!$opts{disable_cxx}) {
        $confs{INCLUDE_MPICXX_H} = "#include \"mpicxx.h\"";
    }
    if (!$opts{disable_romio}) {
        $confs{HAVE_ROMIO} = "#include \"mpio.h\"";
    }

    $confs{BSEND_OVERHEAD} = $sizeof_hash{MPII_BSEND_DATA_T};

    $sizeof_hash{SIGNED_CHAR} = $sizeof_hash{CHAR};
    $sizeof_hash{BYTE} = $sizeof_hash{CHAR};
    $sizeof_hash{PACKED} = $sizeof_hash{CHAR};
    $sizeof_hash{WCHAR} = $sizeof_hash{WCHAR_T};

    $sizeof_hash{UNSIGNED_CHAR} = $sizeof_hash{CHAR};
    $sizeof_hash{UNSIGNED_SHORT} = $sizeof_hash{SHORT};
    $sizeof_hash{UNSIGNED_INT} = $sizeof_hash{INT};
    $sizeof_hash{UNSIGNED_LONG} = $sizeof_hash{LONG};
    $sizeof_hash{UNSIGNED_LONG_LONG} = $sizeof_hash{LONG_LONG};
    $sizeof_hash{"2INT"} = $sizeof_hash{INT} * 2;

    $sizeof_hash{"C_BOOL"} = $sizeof_hash{"BOOL"};
    $sizeof_hash{"C_FLOAT16"} = 2;
    $sizeof_hash{"C_FLOAT_COMPLEX"} = $sizeof_hash{"FLOAT__COMPLEX"};
    $sizeof_hash{"C_DOUBLE_COMPLEX"} = $sizeof_hash{"DOUBLE__COMPLEX"};
    $sizeof_hash{"C_LONG_DOUBLE_COMPLEX"} = $sizeof_hash{"LONG_DOUBLE__COMPLEX"};
    $sizeof_hash{CHARACTER} = $sizeof_hash{CHAR};
    $sizeof_hash{INTEGER} = $sizeof_hash{INT};
    $sizeof_hash{REAL} = $sizeof_hash{FLOAT};
    $sizeof_hash{DOUBLE_PRECISION} = $sizeof_hash{DOUBLE};

    $confs{MPI_CHAR} = sprintf("0x4c00%02x01", $sizeof_hash{"CHAR"});
    $confs{MPI_UNSIGNED_CHAR} = sprintf("0x4c00%02x02", $sizeof_hash{"UNSIGNED_CHAR"});
    $confs{MPI_SHORT} = sprintf("0x4c00%02x03", $sizeof_hash{"SHORT"});
    $confs{MPI_UNSIGNED_SHORT} = sprintf("0x4c00%02x04", $sizeof_hash{"UNSIGNED_SHORT"});
    $confs{MPI_INT} = sprintf("0x4c00%02x05", $sizeof_hash{"INT"});
    $confs{MPI_UNSIGNED_INT} = sprintf("0x4c00%02x06", $sizeof_hash{"UNSIGNED_INT"});
    $confs{MPI_LONG} = sprintf("0x4c00%02x07", $sizeof_hash{"LONG"});
    $confs{MPI_UNSIGNED_LONG} = sprintf("0x4c00%02x08", $sizeof_hash{"UNSIGNED_LONG"});
    $confs{MPI_LONG_LONG} = sprintf("0x4c00%02x09", $sizeof_hash{"LONG_LONG"});
    $confs{MPI_FLOAT} = sprintf("0x4c00%02x0a", $sizeof_hash{"FLOAT"});
    $confs{MPI_DOUBLE} = sprintf("0x4c00%02x0b", $sizeof_hash{"DOUBLE"});
    $confs{MPI_LONG_DOUBLE} = sprintf("0x4c00%02x0c", $sizeof_hash{"LONG_DOUBLE"});
    $confs{MPI_BYTE} = sprintf("0x4c00%02x0d", $sizeof_hash{"BYTE"});
    $confs{MPI_WCHAR} = sprintf("0x4c00%02x0e", $sizeof_hash{"WCHAR"});
    $confs{MPI_PACKED} = sprintf("0x4c00%02x0f", $sizeof_hash{"PACKED"});
    $confs{MPI_LB} = sprintf("0x4c00%02x10", $sizeof_hash{"LB"});
    $confs{MPI_UB} = sprintf("0x4c00%02x11", $sizeof_hash{"UB"});
    $confs{MPI_2INT} = sprintf("0x4c00%02x16", $sizeof_hash{"2INT"});
    $confs{MPI_SIGNED_CHAR} = sprintf("0x4c00%02x18", $sizeof_hash{"SIGNED_CHAR"});
    $confs{MPI_UNSIGNED_LONG_LONG} = sprintf("0x4c00%02x19", $sizeof_hash{"UNSIGNED_LONG_LONG"});

    $confs{MPI_FLOAT_INT} = "0x8c000000";
    $confs{MPI_DOUBLE_INT} = "0x8c000001";
    $confs{MPI_LONG_INT} = "0x8c000002";
    $confs{MPI_SHORT_INT} = "0x8c000003";
    $confs{MPI_LONG_DOUBLE_INT} = "0x8c000004";

    if (!$opts{disable_fortran}) {
        $confs{MPI_CHARACTER} = sprintf("0x4c00%02x1a", $sizeof_hash{"CHARACTER"});
        $confs{MPI_INTEGER} = sprintf("0x4c00%02x1b", $sizeof_hash{"INTEGER"});
        $confs{MPI_REAL} = sprintf("0x4c00%02x1c", $sizeof_hash{"REAL"});
        $confs{MPI_LOGICAL} = sprintf("0x4c00%02x1d", $sizeof_hash{"LOGICAL"});
        $confs{MPI_COMPLEX} = sprintf("0x4c00%02x1e", $sizeof_hash{"COMPLEX"});
        $confs{MPI_DOUBLE_PRECISION} = sprintf("0x4c00%02x1f", $sizeof_hash{"DOUBLE_PRECISION"});
        $confs{MPI_2INTEGER} = sprintf("0x4c00%02x20", $sizeof_hash{"2INTEGER"});
        $confs{MPI_2REAL} = sprintf("0x4c00%02x21", $sizeof_hash{"2REAL"});
        $confs{MPI_DOUBLE_COMPLEX} = sprintf("0x4c00%02x22", $sizeof_hash{"DOUBLE_COMPLEX"});
        $confs{MPI_2DOUBLE_PRECISION} = sprintf("0x4c00%02x23", $sizeof_hash{"2DOUBLE_PRECISION"});
        $confs{MPI_2COMPLEX} = sprintf("0x4c00%02x24", $sizeof_hash{"2COMPLEX"});
        $confs{MPI_2DOUBLE_COMPLEX} = sprintf("0x4c00%02x25", $sizeof_hash{"2DOUBLE_COMPLEX"});
        $confs{MPI_REAL4} = sprintf("0x4c00%02x27", 4);
        $confs{MPI_COMPLEX8} = sprintf("0x4c00%02x28", 8);
        $confs{MPI_REAL8} = sprintf("0x4c00%02x29", 8);
        $confs{MPI_COMPLEX16} = sprintf("0x4c00%02x2a", 16);
        $confs{MPI_REAL16} = sprintf("0x4c00%02x2b", 16);
        $confs{MPI_COMPLEX32} = sprintf("0x4c00%02x2c", 32);
        $confs{MPI_INTEGER1} = sprintf("0x4c00%02x2d", 1);
        $confs{MPI_INTEGER2} = sprintf("0x4c00%02x2f", 2);
        $confs{MPI_INTEGER4} = sprintf("0x4c00%02x30", 4);
        $confs{MPI_INTEGER8} = sprintf("0x4c00%02x31", 8);
        $confs{MPI_INTEGER16} = sprintf("0x4c00%02x32", 16);
        foreach my $n (1,2,4,8) {
            foreach my $type ("char", "short", "int", "long", "long long") {
                my $a = get_config_name($type);
                if ($sizeof_hash{$a} == $n) {
                    $config_defines{"MPIR_INTEGER${n}_CTYPE"} = $type;
                    last;
                }
            }
        }
        foreach my $n (4,8,16) {
            foreach my $type ("float", "double", "__float128") {
                my $a = get_config_name($type);
                if ($sizeof_hash{$a} == $n) {
                    $config_defines{"MPIR_REAL${n}_CTYPE"} = $type;
                    last;
                }
            }
        }
    }
    else {
        $confs{MPI_CHARACTER} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER} = "MPI_DATATYPE_NULL";
        $confs{MPI_REAL} = "MPI_DATATYPE_NULL";
        $confs{MPI_LOGICAL} = "MPI_DATATYPE_NULL";
        $confs{MPI_COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPI_DOUBLE_PRECISION} = "MPI_DATATYPE_NULL";
        $confs{MPI_2INTEGER} = "MPI_DATATYPE_NULL";
        $confs{MPI_2REAL} = "MPI_DATATYPE_NULL";
        $confs{MPI_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPI_2DOUBLE_PRECISION} = "MPI_DATATYPE_NULL";
        $confs{MPI_2COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPI_2DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPI_REAL4} = "MPI_DATATYPE_NULL";
        $confs{MPI_COMPLEX8} = "MPI_DATATYPE_NULL";
        $confs{MPI_REAL8} = "MPI_DATATYPE_NULL";
        $confs{MPI_COMPLEX16} = "MPI_DATATYPE_NULL";
        $confs{MPI_REAL16} = "MPI_DATATYPE_NULL";
        $confs{MPI_COMPLEX32} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER1} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER2} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER4} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER8} = "MPI_DATATYPE_NULL";
        $confs{MPI_INTEGER16} = "MPI_DATATYPE_NULL";
    }
    $confs{MPI_REAL2} = "MPI_DATATYPE_NULL";
    $confs{MPI_COMPLEX4} = "MPI_DATATYPE_NULL";

    if (!$opts{disable_cxx}) {
        $confs{MPIR_CXX_BOOL} = sprintf("0x4c00%02x33", $sizeof_hash{"CXX_BOOL"});
        $confs{MPIR_CXX_COMPLEX} = sprintf("0x4c00%02x34", $sizeof_hash{"CXX_COMPLEX"});
        $confs{MPIR_CXX_DOUBLE_COMPLEX} = sprintf("0x4c00%02x35", $sizeof_hash{"CXX_DOUBLE_COMPLEX"});
        $confs{MPIR_CXX_LONG_DOUBLE_COMPLEX} = sprintf("0x4c00%02x36", $sizeof_hash{"CXX_LONG_DOUBLE_COMPLEX"});
    }
    else {
        $confs{MPIR_CXX_BOOL} = "MPI_DATATYPE_NULL";
        $confs{MPIR_CXX_COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPIR_CXX_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        $confs{MPIR_CXX_LONG_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
    }

    $confs{MPI_INT8_T} = sprintf("0x4c00%02x37", $sizeof_hash{"INT8_T"});
    $confs{MPI_INT16_T} = sprintf("0x4c00%02x38", $sizeof_hash{"INT16_T"});
    $confs{MPI_INT32_T} = sprintf("0x4c00%02x39", $sizeof_hash{"INT32_T"});
    $confs{MPI_INT64_T} = sprintf("0x4c00%02x3a", $sizeof_hash{"INT64_T"});
    $confs{MPI_UINT8_T} = sprintf("0x4c00%02x3b", $sizeof_hash{"UINT8_T"});
    $confs{MPI_UINT16_T} = sprintf("0x4c00%02x3c", $sizeof_hash{"UINT16_T"});
    $confs{MPI_UINT32_T} = sprintf("0x4c00%02x3d", $sizeof_hash{"UINT32_T"});
    $confs{MPI_UINT64_T} = sprintf("0x4c00%02x3e", $sizeof_hash{"UINT64_T"});
    $confs{MPI_C_BOOL} = sprintf("0x4c00%02x3f", $sizeof_hash{"C_BOOL"});
    $confs{MPI_C_FLOAT_COMPLEX} = sprintf("0x4c00%02x40", $sizeof_hash{"C_FLOAT_COMPLEX"});
    $confs{MPI_C_DOUBLE_COMPLEX} = sprintf("0x4c00%02x41", $sizeof_hash{"C_DOUBLE_COMPLEX"});
    $confs{MPI_C_LONG_DOUBLE_COMPLEX} = sprintf("0x4c00%02x42", $sizeof_hash{"C_LONG_DOUBLE_COMPLEX"});

    $confs{MPI_AINT_DATATYPE} = sprintf("0x4c00%02x43", $sizeof_hash{AINT});
    $confs{MPI_OFFSET_DATATYPE} = sprintf("0x4c00%02x44", $sizeof_hash{OFFSET});
    $confs{MPI_COUNT_DATATYPE} = sprintf("0x4c00%02x45", $sizeof_hash{COUNT});

    $confs{MPIX_C_FLOAT16} = sprintf("0x4c00%02x46", $sizeof_hash{"C_FLOAT16"});

    $confs{MPI_UNSIGNED} = $confs{MPI_UNSIGNED_INT};
    $confs{MPI_LONG_LONG_INT} = $confs{MPI_LONG_LONG};
    $confs{MPIR_CXX_FLOAT_COMPLEX} = $confs{MPIR_CXX_COMPLEX};
    autoconf_file("src/include/mpi.h", \%confs);
    my $mpi_h_confs = \%confs;
    my %confs;
    $confs{HAVE_ERROR_CHECKING} = 1;
    autoconf_file("src/include/mpir_ext.h", \%confs);
    my %confs;
    $confs{CONFIGURE_ARGS_CLEAN}= $opts{config_args};
    $confs{MPICH_RELEASE_DATE} = "unreleased development copy";
    $confs{DEVICE} = $opts{device};
    $confs{CC} = $ENV{CC};
    $confs{CXX} = $ENV{CXX};
    $confs{F77} = $ENV{F77};
    $confs{FC} = $ENV{FC};
    $confs{CFLAGS} = "";
    $confs{MPICH_CUSTOM_STRING}="";
    $confs{MPICH_ABIVERSION} = "0:0:0";
    autoconf_file("src/include/mpichinfo.h", \%confs);
    my %confs;
    $confs{FC_REAL_MODEL} = "6, 37";
    $confs{FC_DOUBLE_MODEL} = "15, 307";
    $confs{FC_INTEGER_MODEL} = "9";
    $confs{FC_INTEGER_MODEL_MAP} = "{9, 4, 4}, ";
    if (-f "src/include/mpif90model.h.in") {
        autoconf_file("src/include/mpif90model.h", \%confs);
    }
    elsif (-f "src/mpi/datatype/mpif90model.h.in") {
        autoconf_file("src/mpi/datatype/mpif90model.h", \%confs);
    }
    if (!$opts{disable_cxx}) {
        my %confs;
        $confs{HAVE_CXX_EXCEPTIONS}=0;
        if (!$opts{disable_fortran}) {
            $confs{FORTRAN_BINDING} = 1;
        }
        else {
            $confs{FORTRAN_BINDING} = 0;
        }
        if (!$opts{disable_romio}) {
            $confs{HAVE_CXX_IO} = 1;
        }
        else {
            $confs{HAVE_CXX_IO} = 0;
        }

        $confs{MPIR_CXX_BOOL} = sprintf("0x4c00%02x33", $sizeof_hash{"CXX_BOOL"});
        $confs{MPIR_CXX_COMPLEX} = sprintf("0x4c00%02x34", $sizeof_hash{"CXX_COMPLEX"});
        $confs{MPIR_CXX_DOUBLE_COMPLEX} = sprintf("0x4c00%02x35", $sizeof_hash{"CXX_DOUBLE_COMPLEX"});
        $confs{MPIR_CXX_LONG_DOUBLE_COMPLEX} = sprintf("0x4c00%02x36", $sizeof_hash{"CXX_LONG_DOUBLE_COMPLEX"});

        autoconf_file("src/binding/cxx/mpicxx.h", \%confs);
    }
    if (!$opts{disable_fortran}) {
        my %mpidef;
        my (@mpidef_list, %mpidef_type);
        push @mpidef_list, "MPI_SUCCESS";
        open In, "src/include/mpi.h" or die "Can't open src/include/mpi.h: $!\n";
        while(<In>){
            if (/^\s*#\s*define\s+(MPIX?_[A-Z_]+)\s+(.*)/) {
                my ($name, $t) = ($1, $2);
                my $val;
                if ($t=~/\(\(\w+\)\s*(\S+)\)/) {
                    $val = $1;
                }
                elsif ($t=~/^(\S+)/) {
                    $val = $1;
                }

                if (defined $mpidef{$name}) {
                    print "duplicated define - $name, was $mpidef{$name}, new $val\n";
                }
                else {
                    $mpidef{$name} = $val;
                    if ($name=~/MPI_ERR_\w+/) {
                        push @mpidef_list, $name;
                    }
                }
            }

            elsif (/^(?:typedef\s+)?enum\s+\w*\s*{\s*(.*)/) {
                my ($enum_line) = ($1);
                while ($enum_line !~ /}/) {
                    my $l = <In>;
                    chomp $l;
                    $enum_line .= $l;
                }

                while ($enum_line=~/\s*(MPIX?_\w+)\s*=\s*([a-fx0-9]*)/g) {
                    $mpidef{$1} = $2;
                }
            }
        }
        close In;

        foreach my $k (keys %mpidef) {
            if ($mpidef{$k} =~ /0x(\w+)/) {
                $mpidef{$k} = hex($1);
            }
        }

        my $v = hex $mpi_h_confs->{MPI_AINT_DATATYPE};
        $mpidef{MPI_AINT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        my $v = hex $mpi_h_confs->{MPI_OFFSET_DATATYPE};
        $mpidef{MPI_OFFSET} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        my $v = hex $mpi_h_confs->{MPI_COUNT_DATATYPE};
        $mpidef{MPI_COUNT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        $mpidef{MPI_INTEGER_KIND} = $sizeof_hash{INT};
        $mpidef{MPI_ADDRESS_KIND} = $sizeof_hash{AINT};
        $mpidef{MPI_AINT_KIND} = $sizeof_hash{AINT};
        $mpidef{MPI_COUNT_KIND} = $sizeof_hash{COUNT};
        $mpidef{MPI_OFFSET_KIND} = $sizeof_hash{OFFSET};
        push @mpidef_list, "MPI_IDENT";
        push @mpidef_list, "MPI_CONGRUENT";
        push @mpidef_list, "MPI_SIMILAR";
        push @mpidef_list, "MPI_UNEQUAL";
        push @mpidef_list, "MPI_WIN_FLAVOR_CREATE";
        push @mpidef_list, "MPI_WIN_FLAVOR_ALLOCATE";
        push @mpidef_list, "MPI_WIN_FLAVOR_DYNAMIC";
        push @mpidef_list, "MPI_WIN_FLAVOR_SHARED";
        push @mpidef_list, "MPI_WIN_SEPARATE";
        push @mpidef_list, "MPI_WIN_UNIFIED";
        push @mpidef_list, "MPI_MAX";
        $mpidef_type{MAX} = "Op";
        push @mpidef_list, "MPI_MIN";
        $mpidef_type{MIN} = "Op";
        push @mpidef_list, "MPI_SUM";
        $mpidef_type{SUM} = "Op";
        push @mpidef_list, "MPI_PROD";
        $mpidef_type{PROD} = "Op";
        push @mpidef_list, "MPI_LAND";
        $mpidef_type{LAND} = "Op";
        push @mpidef_list, "MPI_BAND";
        $mpidef_type{BAND} = "Op";
        push @mpidef_list, "MPI_LOR";
        $mpidef_type{LOR} = "Op";
        push @mpidef_list, "MPI_BOR";
        $mpidef_type{BOR} = "Op";
        push @mpidef_list, "MPI_LXOR";
        $mpidef_type{LXOR} = "Op";
        push @mpidef_list, "MPI_BXOR";
        $mpidef_type{BXOR} = "Op";
        push @mpidef_list, "MPI_MINLOC";
        $mpidef_type{MINLOC} = "Op";
        push @mpidef_list, "MPI_MAXLOC";
        $mpidef_type{MAXLOC} = "Op";
        push @mpidef_list, "MPI_REPLACE";
        $mpidef_type{REPLACE} = "Op";
        push @mpidef_list, "MPI_NO_OP";
        $mpidef_type{NO_OP} = "Op";
        push @mpidef_list, "MPI_COMM_NULL";
        $mpidef_type{COMM_NULL} = "Comm";
        push @mpidef_list, "MPI_WIN_NULL";
        $mpidef_type{WIN_NULL} = "Win";
        push @mpidef_list, "MPI_FILE_NULL";
        $mpidef_type{FILE_NULL} = "File";
        push @mpidef_list, "MPI_GROUP_NULL";
        $mpidef_type{GROUP_NULL} = "Group";
        push @mpidef_list, "MPI_OP_NULL";
        $mpidef_type{OP_NULL} = "Op";
        push @mpidef_list, "MPI_DATATYPE_NULL";
        $mpidef_type{DATATYPE_NULL} = "Datatype";
        push @mpidef_list, "MPI_REQUEST_NULL";
        $mpidef_type{REQUEST_NULL} = "Request";
        push @mpidef_list, "MPI_INFO_NULL";
        $mpidef_type{INFO_NULL} = "Info";
        push @mpidef_list, "MPI_ERRHANDLER_NULL";
        $mpidef_type{ERRHANDLER_NULL} = "Errhandler";
        push @mpidef_list, "MPI_MESSAGE_NULL";
        $mpidef_type{MESSAGE_NULL} = "Message";
        push @mpidef_list, "MPI_SESSION_NULL";
        $mpidef_type{SESSION_NULL} = "Session";
        push @mpidef_list, "MPI_COMM_WORLD";
        $mpidef_type{COMM_WORLD} = "Comm";
        push @mpidef_list, "MPI_COMM_SELF";
        $mpidef_type{COMM_SELF} = "Comm";
        push @mpidef_list, "MPI_GROUP_EMPTY";
        $mpidef_type{GROUP_EMPTY} = "Group";
        push @mpidef_list, "MPI_INFO_ENV";
        $mpidef_type{INFO_ENV} = "Info";
        push @mpidef_list, "MPI_MESSAGE_NO_PROC";
        $mpidef_type{MESSAGE_NO_PROC} = "Message";
        push @mpidef_list, "MPI_ERRORS_ARE_FATAL";
        $mpidef_type{ERRORS_ARE_FATAL} = "MPI_Errhandler";
        push @mpidef_list, "MPI_ERRORS_RETURN";
        $mpidef_type{ERRORS_RETURN} = "MPI_Errhandler";

        push @mpidef_list, "MPI_TAG_UB";
        $mpidef{MPI_TAG_UB} += 1;
        push @mpidef_list, "MPI_HOST";
        $mpidef{MPI_HOST} += 1;
        push @mpidef_list, "MPI_IO";
        $mpidef{MPI_IO} += 1;
        push @mpidef_list, "MPI_WTIME_IS_GLOBAL";
        $mpidef{MPI_WTIME_IS_GLOBAL} += 1;
        push @mpidef_list, "MPI_UNIVERSE_SIZE";
        $mpidef{MPI_UNIVERSE_SIZE} += 1;
        push @mpidef_list, "MPI_LASTUSEDCODE";
        $mpidef{MPI_LASTUSEDCODE} += 1;
        push @mpidef_list, "MPI_APPNUM";
        $mpidef{MPI_APPNUM} += 1;
        push @mpidef_list, "MPI_WIN_BASE";
        $mpidef{MPI_WIN_BASE} += 1;
        push @mpidef_list, "MPI_WIN_SIZE";
        $mpidef{MPI_WIN_SIZE} += 1;
        push @mpidef_list, "MPI_WIN_DISP_UNIT";
        $mpidef{MPI_WIN_DISP_UNIT} += 1;
        push @mpidef_list, "MPI_WIN_CREATE_FLAVOR";
        $mpidef{MPI_WIN_CREATE_FLAVOR} += 1;
        push @mpidef_list, "MPI_WIN_MODEL";
        $mpidef{MPI_WIN_MODEL} += 1;
        push @mpidef_list, "MPI_MAX_ERROR_STRING";
        $mpidef{MPI_MAX_ERROR_STRING} -= 1;
        push @mpidef_list, "MPI_MAX_PORT_NAME";
        $mpidef{MPI_MAX_PORT_NAME} -= 1;
        push @mpidef_list, "MPI_MAX_OBJECT_NAME";
        $mpidef{MPI_MAX_OBJECT_NAME} -= 1;
        push @mpidef_list, "MPI_MAX_INFO_KEY";
        $mpidef{MPI_MAX_INFO_KEY} -= 1;
        push @mpidef_list, "MPI_MAX_INFO_VAL";
        $mpidef{MPI_MAX_INFO_VAL} -= 1;
        push @mpidef_list, "MPI_MAX_PROCESSOR_NAME";
        $mpidef{MPI_MAX_PROCESSOR_NAME} -= 1;
        push @mpidef_list, "MPI_MAX_DATAREP_STRING";
        $mpidef{MPI_MAX_DATAREP_STRING} -= 1;
        push @mpidef_list, "MPI_MAX_LIBRARY_VERSION_STRING";
        $mpidef{MPI_MAX_LIBRARY_VERSION_STRING} -= 1;
        push @mpidef_list, "MPI_UNDEFINED";
        push @mpidef_list, "MPI_KEYVAL_INVALID";
        push @mpidef_list, "MPI_BSEND_OVERHEAD";
        push @mpidef_list, "MPI_PROC_NULL";
        push @mpidef_list, "MPI_ANY_SOURCE";
        push @mpidef_list, "MPI_ANY_TAG";
        push @mpidef_list, "MPI_ROOT";
        push @mpidef_list, "MPI_GRAPH";
        push @mpidef_list, "MPI_CART";
        push @mpidef_list, "MPI_DIST_GRAPH";
        push @mpidef_list, "MPI_VERSION";
        push @mpidef_list, "MPI_SUBVERSION";
        push @mpidef_list, "MPI_LOCK_EXCLUSIVE";
        push @mpidef_list, "MPI_LOCK_SHARED";

        my $v = hex $mpi_h_confs->{MPI_CHAR};
        if ($v == 0) {
            $mpidef{MPI_CHAR} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CHAR} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CHAR";
        $mpidef_type{"CHAR"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UNSIGNED_CHAR};
        if ($v == 0) {
            $mpidef{MPI_UNSIGNED_CHAR} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UNSIGNED_CHAR} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UNSIGNED_CHAR";
        $mpidef_type{"UNSIGNED_CHAR"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_SHORT};
        if ($v == 0) {
            $mpidef{MPI_SHORT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_SHORT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_SHORT";
        $mpidef_type{"SHORT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UNSIGNED_SHORT};
        if ($v == 0) {
            $mpidef{MPI_UNSIGNED_SHORT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UNSIGNED_SHORT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UNSIGNED_SHORT";
        $mpidef_type{"UNSIGNED_SHORT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INT};
        if ($v == 0) {
            $mpidef{MPI_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INT";
        $mpidef_type{"INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UNSIGNED_INT};
        if ($v == 0) {
            $mpidef{MPI_UNSIGNED_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UNSIGNED_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UNSIGNED_INT";
        $mpidef_type{"UNSIGNED_INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LONG};
        if ($v == 0) {
            $mpidef{MPI_LONG} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LONG} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LONG";
        $mpidef_type{"LONG"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UNSIGNED_LONG};
        if ($v == 0) {
            $mpidef{MPI_UNSIGNED_LONG} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UNSIGNED_LONG} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UNSIGNED_LONG";
        $mpidef_type{"UNSIGNED_LONG"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LONG_LONG};
        if ($v == 0) {
            $mpidef{MPI_LONG_LONG} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LONG_LONG} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LONG_LONG";
        $mpidef_type{"LONG_LONG"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_FLOAT};
        if ($v == 0) {
            $mpidef{MPI_FLOAT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_FLOAT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_FLOAT";
        $mpidef_type{"FLOAT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_DOUBLE};
        if ($v == 0) {
            $mpidef{MPI_DOUBLE} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_DOUBLE} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_DOUBLE";
        $mpidef_type{"DOUBLE"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LONG_DOUBLE};
        if ($v == 0) {
            $mpidef{MPI_LONG_DOUBLE} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LONG_DOUBLE} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LONG_DOUBLE";
        $mpidef_type{"LONG_DOUBLE"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_BYTE};
        if ($v == 0) {
            $mpidef{MPI_BYTE} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_BYTE} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_BYTE";
        $mpidef_type{"BYTE"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_WCHAR};
        if ($v == 0) {
            $mpidef{MPI_WCHAR} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_WCHAR} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_WCHAR";
        $mpidef_type{"WCHAR"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_PACKED};
        if ($v == 0) {
            $mpidef{MPI_PACKED} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_PACKED} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_PACKED";
        $mpidef_type{"PACKED"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LB};
        if ($v == 0) {
            $mpidef{MPI_LB} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LB} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LB";
        $mpidef_type{"LB"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UB};
        if ($v == 0) {
            $mpidef{MPI_UB} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UB} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UB";
        $mpidef_type{"UB"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2INT};
        if ($v == 0) {
            $mpidef{MPI_2INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2INT";
        $mpidef_type{"2INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_SIGNED_CHAR};
        if ($v == 0) {
            $mpidef{MPI_SIGNED_CHAR} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_SIGNED_CHAR} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_SIGNED_CHAR";
        $mpidef_type{"SIGNED_CHAR"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UNSIGNED_LONG_LONG};
        if ($v == 0) {
            $mpidef{MPI_UNSIGNED_LONG_LONG} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UNSIGNED_LONG_LONG} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UNSIGNED_LONG_LONG";
        $mpidef_type{"UNSIGNED_LONG_LONG"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_CHARACTER};
        if ($v == 0) {
            $mpidef{MPI_CHARACTER} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CHARACTER} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CHARACTER";
        $mpidef_type{"CHARACTER"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER};
        if ($v == 0) {
            $mpidef{MPI_INTEGER} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER";
        $mpidef_type{"INTEGER"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_REAL};
        if ($v == 0) {
            $mpidef{MPI_REAL} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_REAL} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_REAL";
        $mpidef_type{"REAL"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LOGICAL};
        if ($v == 0) {
            $mpidef{MPI_LOGICAL} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LOGICAL} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LOGICAL";
        $mpidef_type{"LOGICAL"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_COMPLEX";
        $mpidef_type{"COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_DOUBLE_PRECISION};
        if ($v == 0) {
            $mpidef{MPI_DOUBLE_PRECISION} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_DOUBLE_PRECISION} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_DOUBLE_PRECISION";
        $mpidef_type{"DOUBLE_PRECISION"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2INTEGER};
        if ($v == 0) {
            $mpidef{MPI_2INTEGER} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2INTEGER} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2INTEGER";
        $mpidef_type{"2INTEGER"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2REAL};
        if ($v == 0) {
            $mpidef{MPI_2REAL} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2REAL} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2REAL";
        $mpidef_type{"2REAL"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_DOUBLE_COMPLEX";
        $mpidef_type{"DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2DOUBLE_PRECISION};
        if ($v == 0) {
            $mpidef{MPI_2DOUBLE_PRECISION} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2DOUBLE_PRECISION} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2DOUBLE_PRECISION";
        $mpidef_type{"2DOUBLE_PRECISION"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_2COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2COMPLEX";
        $mpidef_type{"2COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_2DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_2DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_2DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_2DOUBLE_COMPLEX";
        $mpidef_type{"2DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_REAL4};
        if ($v == 0) {
            $mpidef{MPI_REAL4} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_REAL4} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_REAL4";
        $mpidef_type{"REAL4"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_COMPLEX8};
        if ($v == 0) {
            $mpidef{MPI_COMPLEX8} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_COMPLEX8} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_COMPLEX8";
        $mpidef_type{"COMPLEX8"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_REAL8};
        if ($v == 0) {
            $mpidef{MPI_REAL8} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_REAL8} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_REAL8";
        $mpidef_type{"REAL8"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_COMPLEX16};
        if ($v == 0) {
            $mpidef{MPI_COMPLEX16} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_COMPLEX16} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_COMPLEX16";
        $mpidef_type{"COMPLEX16"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_REAL16};
        if ($v == 0) {
            $mpidef{MPI_REAL16} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_REAL16} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_REAL16";
        $mpidef_type{"REAL16"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_COMPLEX32};
        if ($v == 0) {
            $mpidef{MPI_COMPLEX32} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_COMPLEX32} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_COMPLEX32";
        $mpidef_type{"COMPLEX32"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER1};
        if ($v == 0) {
            $mpidef{MPI_INTEGER1} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER1} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER1";
        $mpidef_type{"INTEGER1"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER2};
        if ($v == 0) {
            $mpidef{MPI_INTEGER2} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER2} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER2";
        $mpidef_type{"INTEGER2"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER4};
        if ($v == 0) {
            $mpidef{MPI_INTEGER4} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER4} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER4";
        $mpidef_type{"INTEGER4"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER8};
        if ($v == 0) {
            $mpidef{MPI_INTEGER8} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER8} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER8";
        $mpidef_type{"INTEGER8"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INTEGER16};
        if ($v == 0) {
            $mpidef{MPI_INTEGER16} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INTEGER16} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INTEGER16";
        $mpidef_type{"INTEGER16"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_CXX_BOOL};
        if ($v == 0) {
            $mpidef{MPI_CXX_BOOL} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CXX_BOOL} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CXX_BOOL";
        $mpidef_type{"CXX_BOOL"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_CXX_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_CXX_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CXX_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CXX_COMPLEX";
        $mpidef_type{"CXX_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_CXX_DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_CXX_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CXX_DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CXX_DOUBLE_COMPLEX";
        $mpidef_type{"CXX_DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_CXX_LONG_DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_CXX_LONG_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_CXX_LONG_DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_CXX_LONG_DOUBLE_COMPLEX";
        $mpidef_type{"CXX_LONG_DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INT8_T};
        if ($v == 0) {
            $mpidef{MPI_INT8_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INT8_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INT8_T";
        $mpidef_type{"INT8_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INT16_T};
        if ($v == 0) {
            $mpidef{MPI_INT16_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INT16_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INT16_T";
        $mpidef_type{"INT16_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INT32_T};
        if ($v == 0) {
            $mpidef{MPI_INT32_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INT32_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INT32_T";
        $mpidef_type{"INT32_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_INT64_T};
        if ($v == 0) {
            $mpidef{MPI_INT64_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_INT64_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_INT64_T";
        $mpidef_type{"INT64_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UINT8_T};
        if ($v == 0) {
            $mpidef{MPI_UINT8_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UINT8_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UINT8_T";
        $mpidef_type{"UINT8_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UINT16_T};
        if ($v == 0) {
            $mpidef{MPI_UINT16_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UINT16_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UINT16_T";
        $mpidef_type{"UINT16_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UINT32_T};
        if ($v == 0) {
            $mpidef{MPI_UINT32_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UINT32_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UINT32_T";
        $mpidef_type{"UINT32_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_UINT64_T};
        if ($v == 0) {
            $mpidef{MPI_UINT64_T} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_UINT64_T} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_UINT64_T";
        $mpidef_type{"UINT64_T"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_C_BOOL};
        if ($v == 0) {
            $mpidef{MPI_C_BOOL} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_C_BOOL} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_C_BOOL";
        $mpidef_type{"C_BOOL"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_C_FLOAT_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_C_FLOAT_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_C_FLOAT_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_C_FLOAT_COMPLEX";
        $mpidef_type{"C_FLOAT_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_C_DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_C_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_C_DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_C_DOUBLE_COMPLEX";
        $mpidef_type{"C_DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_C_LONG_DOUBLE_COMPLEX};
        if ($v == 0) {
            $mpidef{MPI_C_LONG_DOUBLE_COMPLEX} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_C_LONG_DOUBLE_COMPLEX} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_C_LONG_DOUBLE_COMPLEX";
        $mpidef_type{"C_LONG_DOUBLE_COMPLEX"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_AINT_DATATYPE};
        if ($v == 0) {
            $mpidef{MPI_AINT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_AINT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_AINT";
        $mpidef_type{"AINT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_OFFSET_DATATYPE};
        if ($v == 0) {
            $mpidef{MPI_OFFSET} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_OFFSET} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_OFFSET";
        $mpidef_type{"OFFSET"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_COUNT_DATATYPE};
        if ($v == 0) {
            $mpidef{MPI_COUNT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_COUNT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_COUNT";
        $mpidef_type{"COUNT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_C_FLOAT16};
        if ($v == 0) {
            $mpidef{MPI_C_FLOAT16} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_C_FLOAT16} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_C_FLOAT16";
        $mpidef_type{"C_FLOAT16"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_FLOAT_INT};
        if ($v == 0) {
            $mpidef{MPI_FLOAT_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_FLOAT_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_FLOAT_INT";
        $mpidef_type{"FLOAT_INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_DOUBLE_INT};
        if ($v == 0) {
            $mpidef{MPI_DOUBLE_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_DOUBLE_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_DOUBLE_INT";
        $mpidef_type{"DOUBLE_INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LONG_INT};
        if ($v == 0) {
            $mpidef{MPI_LONG_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LONG_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LONG_INT";
        $mpidef_type{"LONG_INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_SHORT_INT};
        if ($v == 0) {
            $mpidef{MPI_SHORT_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_SHORT_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_SHORT_INT";
        $mpidef_type{"SHORT_INT"} = "Datatype";
        my $v = hex $mpi_h_confs->{MPI_LONG_DOUBLE_INT};
        if ($v == 0) {
            $mpidef{MPI_LONG_DOUBLE_INT} = "MPI_DATATYPE_NULL";
        }
        else {
            $mpidef{MPI_LONG_DOUBLE_INT} = $v > 0x7fffffff ? $v - (1<<31) : $v;
        }
        push @mpidef_list, "MPI_LONG_DOUBLE_INT";
        $mpidef_type{"LONG_DOUBLE_INT"} = "Datatype";

        push @mpidef_list, "MPI_ADDRESS_KIND";
        push @mpidef_list, "MPI_OFFSET_KIND";
        push @mpidef_list, "MPI_COUNT_KIND";
        push @mpidef_list, "MPI_INTEGER_KIND";
        push @mpidef_list, "MPI_COMBINER_NAMED";
        push @mpidef_list, "MPI_COMBINER_DUP";
        push @mpidef_list, "MPI_COMBINER_CONTIGUOUS";
        push @mpidef_list, "MPI_COMBINER_VECTOR";
        push @mpidef_list, "MPI_COMBINER_HVECTOR_INTEGER";
        push @mpidef_list, "MPI_COMBINER_HVECTOR";
        push @mpidef_list, "MPI_COMBINER_INDEXED";
        push @mpidef_list, "MPI_COMBINER_HINDEXED_INTEGER";
        push @mpidef_list, "MPI_COMBINER_HINDEXED";
        push @mpidef_list, "MPI_COMBINER_INDEXED_BLOCK";
        push @mpidef_list, "MPI_COMBINER_STRUCT_INTEGER";
        push @mpidef_list, "MPI_COMBINER_STRUCT";
        push @mpidef_list, "MPI_COMBINER_SUBARRAY";
        push @mpidef_list, "MPI_COMBINER_DARRAY";
        push @mpidef_list, "MPI_COMBINER_F90_REAL";
        push @mpidef_list, "MPI_COMBINER_F90_COMPLEX";
        push @mpidef_list, "MPI_COMBINER_F90_INTEGER";
        push @mpidef_list, "MPI_COMBINER_RESIZED";
        push @mpidef_list, "MPI_COMBINER_HINDEXED_BLOCK";
        push @mpidef_list, "MPI_TYPECLASS_REAL";
        push @mpidef_list, "MPI_TYPECLASS_INTEGER";
        push @mpidef_list, "MPI_TYPECLASS_COMPLEX";
        push @mpidef_list, "MPI_MODE_NOCHECK";
        push @mpidef_list, "MPI_MODE_NOSTORE";
        push @mpidef_list, "MPI_MODE_NOPUT";
        push @mpidef_list, "MPI_MODE_NOPRECEDE";
        push @mpidef_list, "MPI_MODE_NOSUCCEED";
        push @mpidef_list, "MPI_COMM_TYPE_SHARED";
        push @mpidef_list, "MPI_THREAD_SINGLE";
        push @mpidef_list, "MPI_THREAD_FUNNELED";
        push @mpidef_list, "MPI_THREAD_SERIALIZED";
        push @mpidef_list, "MPI_THREAD_MULTIPLE";

        if (!$opts{disable_romio}) {
            push @mpidef_list, "MPI_MODE_RDONLY";
            push @mpidef_list, "MPI_MODE_RDWR";
            push @mpidef_list, "MPI_MODE_WRONLY";
            push @mpidef_list, "MPI_MODE_DELETE_ON_CLOSE";
            push @mpidef_list, "MPI_MODE_UNIQUE_OPEN";
            push @mpidef_list, "MPI_MODE_CREATE";
            push @mpidef_list, "MPI_MODE_EXCL";
            push @mpidef_list, "MPI_MODE_APPEND";
            push @mpidef_list, "MPI_MODE_SEQUENTIAL";
            push @mpidef_list, "MPI_SEEK_SET";
            push @mpidef_list, "MPI_SEEK_CUR";
            push @mpidef_list, "MPI_SEEK_END";
            push @mpidef_list, "MPI_ORDER_C";
            push @mpidef_list, "MPI_ORDER_FORTRAN";
            push @mpidef_list, "MPI_DISTRIBUTE_BLOCK";
            push @mpidef_list, "MPI_DISTRIBUTE_CYCLIC";
            push @mpidef_list, "MPI_DISTRIBUTE_NONE";
            push @mpidef_list, "MPI_DISTRIBUTE_DFLT_DARG";
            $mpidef{MPI_DISPLACEMENT_CURRENT} = -54278278;
            push @mpidef_list, "MPI_MPI_DISPLACEMENT_CURRENT";
        }

        my $dir="src/binding/fortran/mpif_h";
        open Out, ">$dir/mpif.h" or die "Can't write $dir/mpif.h: $!\n";
        print "  --> [$dir/mpif.h]\n";
        my $sp = ' ' x 6;
        print Out "!      \n";
        print Out "!      Copyright (C) by Argonne National Laboratory\n";
        print Out "!          See COPYRIGHT in top-level directory\n";
        print Out "!      \n";
        print Out "!      DO NOT EDIT\n";
        print Out "!      This file created by buildiface\n";
        print Out "!      \n";
        my $n = 5;
        print Out "       INTEGER MPI_SOURCE, MPI_TAG, MPI_ERROR\n";
        print Out "       PARAMETER (MPI_SOURCE=3,MPI_TAG=4,MPI_ERROR=5)\n";

        print Out "       INTEGER MPI_STATUS_SIZE\n";
        print Out "       PARAMETER (MPI_STATUS_SIZE=$n)\n";
        print Out "       INTEGER MPI_STATUS_IGNORE($n)\n";
        print Out "       INTEGER MPI_STATUSES_IGNORE($n,1)\n";

        print Out "       INTEGER MPI_ERRCODES_IGNORE(1)\n";

        print Out "       CHARACTER*1 MPI_ARGVS_NULL(1,1)\n";
        print Out "       CHARACTER*1 MPI_ARGV_NULL(1)\n";

        print Out "       INTEGER MPI_BOTTOM, MPI_IN_PLACE, MPI_UNWEIGHTED\n";
        print Out "       INTEGER MPI_WEIGHTS_EMPTY\n";
        foreach my $k (@mpidef_list) {
            if (!defined $mpidef{$k}) {
                warn "mpif.h: $k missing\n";
            }
            print Out "$sp INTEGER $k\n";
            print Out "$sp PARAMETER ($k=$mpidef{$k})\n";
        }
        foreach my $a ("SUBARRAYS_SUPPORTED", "ASYNC_PROTECTS_NONBLOCKING") {
            print Out "       LOGICAL MPI_$a\n";
            print Out "       PARAMETER(MPI_$a=.FALSE.)\n";
        }

        print Out "       EXTERNAL MPI_DUP_FN, MPI_NULL_DELETE_FN, MPI_NULL_COPY_FN\n";
        print Out "       EXTERNAL MPI_WTIME, MPI_WTICK\n";
        print Out "       EXTERNAL PMPI_WTIME, PMPI_WTICK\n";
        print Out "       EXTERNAL MPI_COMM_DUP_FN, MPI_COMM_NULL_DELETE_FN\n";
        print Out "       EXTERNAL MPI_COMM_NULL_COPY_FN\n";
        print Out "       EXTERNAL MPI_WIN_DUP_FN, MPI_WIN_NULL_DELETE_FN\n";
        print Out "       EXTERNAL MPI_WIN_NULL_COPY_FN\n";
        print Out "       EXTERNAL MPI_TYPE_DUP_FN, MPI_TYPE_NULL_DELETE_FN\n";
        print Out "       EXTERNAL MPI_TYPE_NULL_COPY_FN\n";
        print Out "       EXTERNAL MPI_CONVERSION_FN_NULL\n";
        print Out "       DOUBLE PRECISION MPI_WTIME, MPI_WTICK\n";
        print Out "       DOUBLE PRECISION PMPI_WTIME, PMPI_WTICK\n";
        print Out "$sp COMMON /MPIFCMB5/ MPI_UNWEIGHTED\n";
        print Out "$sp COMMON /MPIFCMB9/ MPI_WEIGHTS_EMPTY\n";
        print Out "$sp SAVE /MPIFCMB5/\n";
        print Out "$sp SAVE /MPIFCMB9/\n";

        print Out "$sp COMMON /MPIPRIV1/ MPI_BOTTOM, MPI_IN_PLACE, MPI_STATUS_IGNORE\n";

        print Out "$sp COMMON /MPIPRIV2/ MPI_STATUSES_IGNORE, MPI_ERRCODES_IGNORE\n";
        print Out "$sp SAVE /MPIPRIV1/,/MPIPRIV2/\n";

        print Out "$sp COMMON /MPIPRIVC/ MPI_ARGVS_NULL, MPI_ARGV_NULL\n";
        print Out "$sp SAVE   /MPIPRIVC/\n";
        close Out;
        my $dir="src/binding/fortran/use_mpi";
        open Out, ">$dir/mpi_constants.f90" or die "Can't write $dir/mpi_constants.f90: $!\n";
        print "  --> [$dir/mpi_constants.f90]\n";
        print Out "MODULE MPI_CONSTANTS\n";
        print Out "IMPLICIT NONE\n";
        print Out "include 'mpifnoext.h'\n";
        my $sp = '    ';
        print Out "${sp}TYPE :: MPI_Status\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: count_lo\n";
        print Out "${sp}INTEGER :: count_hi_and_cancelled\n";
        print Out "${sp}INTEGER :: MPI_SOURCE\n";
        print Out "${sp}INTEGER :: MPI_TAG\n";
        print Out "${sp}INTEGER :: MPI_ERROR\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Status\n";
        print Out "${sp}TYPE :: MPI_Comm\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Comm\n";
        print Out "${sp}TYPE :: MPI_Win\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Win\n";
        print Out "${sp}TYPE :: MPI_File\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_File\n";
        print Out "${sp}TYPE :: MPI_Group\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Group\n";
        print Out "${sp}TYPE :: MPI_Op\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Op\n";
        print Out "${sp}TYPE :: MPI_Datatype\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Datatype\n";
        print Out "${sp}TYPE :: MPI_Request\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Request\n";
        print Out "${sp}TYPE :: MPI_Info\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Info\n";
        print Out "${sp}TYPE :: MPI_Errhandler\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Errhandler\n";
        print Out "${sp}TYPE :: MPI_Message\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Message\n";
        print Out "${sp}TYPE :: MPI_Session\n";
        $sp .= '    ';
        print Out "${sp}SEQUENCE\n";
        print Out "${sp}INTEGER :: MPI_VAL\n";
        $sp =~s/^    //;
        print Out "${sp}END TYPE MPI_Session\n";
        print Out "${sp}INTERFACE OPERATOR(.EQ.)\n";
        $sp .= '    ';
        print Out "${sp}MODULE PROCEDURE commeq\n";
        print Out "${sp}MODULE PROCEDURE wineq\n";
        print Out "${sp}MODULE PROCEDURE fileeq\n";
        print Out "${sp}MODULE PROCEDURE groupeq\n";
        print Out "${sp}MODULE PROCEDURE opeq\n";
        print Out "${sp}MODULE PROCEDURE datatypeeq\n";
        print Out "${sp}MODULE PROCEDURE requesteq\n";
        print Out "${sp}MODULE PROCEDURE infoeq\n";
        print Out "${sp}MODULE PROCEDURE errhandlereq\n";
        print Out "${sp}MODULE PROCEDURE messageeq\n";
        print Out "${sp}MODULE PROCEDURE sessioneq\n";
        $sp =~s/^    //;
        print Out "${sp}END INTERFACE\n";
        print Out "${sp}INTERFACE OPERATOR(.NE.)\n";
        $sp .= '    ';
        print Out "${sp}MODULE PROCEDURE commne\n";
        print Out "${sp}MODULE PROCEDURE winne\n";
        print Out "${sp}MODULE PROCEDURE filene\n";
        print Out "${sp}MODULE PROCEDURE groupne\n";
        print Out "${sp}MODULE PROCEDURE opne\n";
        print Out "${sp}MODULE PROCEDURE datatypene\n";
        print Out "${sp}MODULE PROCEDURE requestne\n";
        print Out "${sp}MODULE PROCEDURE infone\n";
        print Out "${sp}MODULE PROCEDURE errhandlerne\n";
        print Out "${sp}MODULE PROCEDURE messagene\n";
        print Out "${sp}MODULE PROCEDURE sessionne\n";
        $sp =~s/^    //;
        print Out "${sp}END INTERFACE\n";
        print Out "${sp}CONTAINS\n";
        print Out "${sp}LOGICAL FUNCTION Commeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Comm), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Commeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Commne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Comm), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Commne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Wineq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Win), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Wineq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Winne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Win), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Winne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Fileeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_File), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Fileeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Filene(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_File), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Filene = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Groupeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Group), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Groupeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Groupne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Group), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Groupne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Opeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Op), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Opeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Opne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Op), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Opne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Datatypeeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Datatype), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Datatypeeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Datatypene(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Datatype), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Datatypene = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Requesteq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Request), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Requesteq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Requestne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Request), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Requestne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Infoeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Info), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Infoeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Infone(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Info), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Infone = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Errhandlereq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Errhandler), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Errhandlereq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Errhandlerne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Errhandler), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Errhandlerne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Messageeq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Message), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Messageeq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Messagene(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Message), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Messagene = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Sessioneq(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Session), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Sessioneq = lhs%MPI_VAL .EQ. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "${sp}LOGICAL FUNCTION Sessionne(lhs, rhs)\n";
        print Out "${sp}    TYPE(MPI_Session), INTENT(IN):: lhs, rhs\n";
        print Out "${sp}    Sessionne = lhs%MPI_VAL .NE. rhs%MPI_VAL\n";
        print Out "${sp}END FUNCTION\n";
        print Out "END MODULE MPI_CONSTANTS\n";
        close Out;

        my %confs;
        $confs{WTIME_DOUBLE_TYPE} = "REAL*8";
        $confs{SIZEOF_FC_INTEGER} = $sizeof_hash{INTEGER};
        $confs{SIZEOF_FC_REAL} = $sizeof_hash{REAL};
        $confs{SIZEOF_FC_DOUBLE_PRECISION} = $sizeof_hash{DOUBLE_PRECISION};
        $confs{SIZEOF_FC_CHARACTER} = $sizeof_hash{CHARACTER};
        my $dir="src/binding/fortran/use_mpi_f08";
        open Out, ">$dir/mpi_f08_types.f90" or die "Can't write $dir/mpi_f08_types.f90: $!\n";
        print "  --> [$dir/mpi_f08_types.f90]\n";
        print Out "!      \n";
        print Out "!      Copyright (C) by Argonne National Laboratory\n";
        print Out "!          See COPYRIGHT in top-level directory\n";
        print Out "!      \n";
        print Out "!      DO NOT EDIT\n";
        print Out "!      This file created by buildiface\n";
        print Out "!      \n";
        print Out "module MPI_f08_types\n";
        print Out "\n";
        print Out "use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "use:: mpi_c_interface_types, only: c_Count, c_Status\n";
        print Out "implicit none\n";
        print Out "type, bind(C) :: MPI_Comm\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Comm\n";
        print Out "type, bind(C) :: MPI_Win\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Win\n";
        print Out "type, bind(C) :: MPI_File\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_File\n";
        print Out "type, bind(C) :: MPI_Group\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Group\n";
        print Out "type, bind(C) :: MPI_Op\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Op\n";
        print Out "type, bind(C) :: MPI_Datatype\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Datatype\n";
        print Out "type, bind(C) :: MPI_Request\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Request\n";
        print Out "type, bind(C) :: MPI_Info\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Info\n";
        print Out "type, bind(C) :: MPI_Errhandler\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Errhandler\n";
        print Out "type, bind(C) :: MPI_Message\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Message\n";
        print Out "type, bind(C) :: MPI_Session\n";
        print Out "    integer:: MPI_VAL\n";
        print Out "end type MPI_Session\n";
        print Out "type, bind(C) :: MPI_Status\n";
        print Out "    integer :: count_lo\n";
        print Out "    integer :: count_hi_and_cancelled\n";
        print Out "    integer :: MPI_SOURCE\n";
        print Out "    integer :: MPI_TAG\n";
        print Out "    integer :: MPI_ERROR\n";
        print Out "end type MPI_Status\n";
        print Out "integer,parameter :: MPI_SOURCE = 3\n";
        print Out "integer,parameter :: MPI_TAG = 4\n";
        print Out "integer,parameter :: MPI_ERROR = 5\n";
        print Out "integer,parameter :: MPI_STATUS_SIZE = 5\n";
        print Out "interface assignment(=)\n";
        my $sp = "    ";
        print Out "${sp}module procedure MPI_Status_f08_assign_c\n";
        print Out "${sp}module procedure MPI_Status_c_assign_f08\n";
        print Out "end interface\n";
        print Out "private:: MPI_Status_f08_assign_c\n";
        print Out "private:: MPI_Status_c_assign_f08\n";
        print Out "private:: MPI_Status_f_assign_c\n";
        print Out "private:: MPI_Status_c_assign_f\n";
        print Out "interface operator(==)\n";
        print Out "    module procedure MPI_Comm_eq\n";
        print Out "    module procedure MPI_Comm_f08_eq_f\n";
        print Out "    module procedure MPI_Comm_f_eq_f08\n";
        print Out "    module procedure MPI_Win_eq\n";
        print Out "    module procedure MPI_Win_f08_eq_f\n";
        print Out "    module procedure MPI_Win_f_eq_f08\n";
        print Out "    module procedure MPI_File_eq\n";
        print Out "    module procedure MPI_File_f08_eq_f\n";
        print Out "    module procedure MPI_File_f_eq_f08\n";
        print Out "    module procedure MPI_Group_eq\n";
        print Out "    module procedure MPI_Group_f08_eq_f\n";
        print Out "    module procedure MPI_Group_f_eq_f08\n";
        print Out "    module procedure MPI_Op_eq\n";
        print Out "    module procedure MPI_Op_f08_eq_f\n";
        print Out "    module procedure MPI_Op_f_eq_f08\n";
        print Out "    module procedure MPI_Datatype_eq\n";
        print Out "    module procedure MPI_Datatype_f08_eq_f\n";
        print Out "    module procedure MPI_Datatype_f_eq_f08\n";
        print Out "    module procedure MPI_Request_eq\n";
        print Out "    module procedure MPI_Request_f08_eq_f\n";
        print Out "    module procedure MPI_Request_f_eq_f08\n";
        print Out "    module procedure MPI_Info_eq\n";
        print Out "    module procedure MPI_Info_f08_eq_f\n";
        print Out "    module procedure MPI_Info_f_eq_f08\n";
        print Out "    module procedure MPI_Errhandler_eq\n";
        print Out "    module procedure MPI_Errhandler_f08_eq_f\n";
        print Out "    module procedure MPI_Errhandler_f_eq_f08\n";
        print Out "    module procedure MPI_Message_eq\n";
        print Out "    module procedure MPI_Message_f08_eq_f\n";
        print Out "    module procedure MPI_Message_f_eq_f08\n";
        print Out "    module procedure MPI_Session_eq\n";
        print Out "    module procedure MPI_Session_f08_eq_f\n";
        print Out "    module procedure MPI_Session_f_eq_f08\n";
        print Out "end interface\n";
        print Out "private:: MPI_Comm_eq\n";
        print Out "private:: MPI_Comm_f08_eq_f\n";
        print Out "private:: MPI_Comm_f_eq_f08\n";
        print Out "private:: MPI_Win_eq\n";
        print Out "private:: MPI_Win_f08_eq_f\n";
        print Out "private:: MPI_Win_f_eq_f08\n";
        print Out "private:: MPI_File_eq\n";
        print Out "private:: MPI_File_f08_eq_f\n";
        print Out "private:: MPI_File_f_eq_f08\n";
        print Out "private:: MPI_Group_eq\n";
        print Out "private:: MPI_Group_f08_eq_f\n";
        print Out "private:: MPI_Group_f_eq_f08\n";
        print Out "private:: MPI_Op_eq\n";
        print Out "private:: MPI_Op_f08_eq_f\n";
        print Out "private:: MPI_Op_f_eq_f08\n";
        print Out "private:: MPI_Datatype_eq\n";
        print Out "private:: MPI_Datatype_f08_eq_f\n";
        print Out "private:: MPI_Datatype_f_eq_f08\n";
        print Out "private:: MPI_Request_eq\n";
        print Out "private:: MPI_Request_f08_eq_f\n";
        print Out "private:: MPI_Request_f_eq_f08\n";
        print Out "private:: MPI_Info_eq\n";
        print Out "private:: MPI_Info_f08_eq_f\n";
        print Out "private:: MPI_Info_f_eq_f08\n";
        print Out "private:: MPI_Errhandler_eq\n";
        print Out "private:: MPI_Errhandler_f08_eq_f\n";
        print Out "private:: MPI_Errhandler_f_eq_f08\n";
        print Out "private:: MPI_Message_eq\n";
        print Out "private:: MPI_Message_f08_eq_f\n";
        print Out "private:: MPI_Message_f_eq_f08\n";
        print Out "private:: MPI_Session_eq\n";
        print Out "private:: MPI_Session_f08_eq_f\n";
        print Out "private:: MPI_Session_f_eq_f08\n";
        print Out "interface operator(/=)\n";
        print Out "    module procedure MPI_Comm_neq\n";
        print Out "    module procedure MPI_Comm_f08_neq_f\n";
        print Out "    module procedure MPI_Comm_f_neq_f08\n";
        print Out "    module procedure MPI_Win_neq\n";
        print Out "    module procedure MPI_Win_f08_neq_f\n";
        print Out "    module procedure MPI_Win_f_neq_f08\n";
        print Out "    module procedure MPI_File_neq\n";
        print Out "    module procedure MPI_File_f08_neq_f\n";
        print Out "    module procedure MPI_File_f_neq_f08\n";
        print Out "    module procedure MPI_Group_neq\n";
        print Out "    module procedure MPI_Group_f08_neq_f\n";
        print Out "    module procedure MPI_Group_f_neq_f08\n";
        print Out "    module procedure MPI_Op_neq\n";
        print Out "    module procedure MPI_Op_f08_neq_f\n";
        print Out "    module procedure MPI_Op_f_neq_f08\n";
        print Out "    module procedure MPI_Datatype_neq\n";
        print Out "    module procedure MPI_Datatype_f08_neq_f\n";
        print Out "    module procedure MPI_Datatype_f_neq_f08\n";
        print Out "    module procedure MPI_Request_neq\n";
        print Out "    module procedure MPI_Request_f08_neq_f\n";
        print Out "    module procedure MPI_Request_f_neq_f08\n";
        print Out "    module procedure MPI_Info_neq\n";
        print Out "    module procedure MPI_Info_f08_neq_f\n";
        print Out "    module procedure MPI_Info_f_neq_f08\n";
        print Out "    module procedure MPI_Errhandler_neq\n";
        print Out "    module procedure MPI_Errhandler_f08_neq_f\n";
        print Out "    module procedure MPI_Errhandler_f_neq_f08\n";
        print Out "    module procedure MPI_Message_neq\n";
        print Out "    module procedure MPI_Message_f08_neq_f\n";
        print Out "    module procedure MPI_Message_f_neq_f08\n";
        print Out "    module procedure MPI_Session_neq\n";
        print Out "    module procedure MPI_Session_f08_neq_f\n";
        print Out "    module procedure MPI_Session_f_neq_f08\n";
        print Out "end interface\n";
        print Out "private:: MPI_Comm_neq\n";
        print Out "private:: MPI_Comm_f08_neq_f\n";
        print Out "private:: MPI_Comm_f_neq_f08\n";
        print Out "private:: MPI_Win_neq\n";
        print Out "private:: MPI_Win_f08_neq_f\n";
        print Out "private:: MPI_Win_f_neq_f08\n";
        print Out "private:: MPI_File_neq\n";
        print Out "private:: MPI_File_f08_neq_f\n";
        print Out "private:: MPI_File_f_neq_f08\n";
        print Out "private:: MPI_Group_neq\n";
        print Out "private:: MPI_Group_f08_neq_f\n";
        print Out "private:: MPI_Group_f_neq_f08\n";
        print Out "private:: MPI_Op_neq\n";
        print Out "private:: MPI_Op_f08_neq_f\n";
        print Out "private:: MPI_Op_f_neq_f08\n";
        print Out "private:: MPI_Datatype_neq\n";
        print Out "private:: MPI_Datatype_f08_neq_f\n";
        print Out "private:: MPI_Datatype_f_neq_f08\n";
        print Out "private:: MPI_Request_neq\n";
        print Out "private:: MPI_Request_f08_neq_f\n";
        print Out "private:: MPI_Request_f_neq_f08\n";
        print Out "private:: MPI_Info_neq\n";
        print Out "private:: MPI_Info_f08_neq_f\n";
        print Out "private:: MPI_Info_f_neq_f08\n";
        print Out "private:: MPI_Errhandler_neq\n";
        print Out "private:: MPI_Errhandler_f08_neq_f\n";
        print Out "private:: MPI_Errhandler_f_neq_f08\n";
        print Out "private:: MPI_Message_neq\n";
        print Out "private:: MPI_Message_f08_neq_f\n";
        print Out "private:: MPI_Message_f_neq_f08\n";
        print Out "private:: MPI_Session_neq\n";
        print Out "private:: MPI_Session_f08_neq_f\n";
        print Out "private:: MPI_Session_f_neq_f08\n";
        print Out "interface MPI_Sizeof\n";
        print Out "    module procedure MPI_Sizeof_character\n";
        print Out "    module procedure MPI_Sizeof_logical\n";
        print Out "    module procedure MPI_Sizeof_xint8\n";
        print Out "    module procedure MPI_Sizeof_xint16\n";
        print Out "    module procedure MPI_Sizeof_xint32\n";
        print Out "    module procedure MPI_Sizeof_xint64\n";
        print Out "    module procedure MPI_Sizeof_xreal32\n";
        print Out "    module procedure MPI_Sizeof_xreal64\n";
        print Out "    module procedure MPI_Sizeof_xreal128\n";
        print Out "    module procedure MPI_Sizeof_xcomplex32\n";
        print Out "    module procedure MPI_Sizeof_xcomplex64\n";
        print Out "    module procedure MPI_Sizeof_xcomplex128\n";
        print Out "end interface\n";
        print Out "private:: MPI_Sizeof_character\n";
        print Out "private:: MPI_Sizeof_logical\n";
        print Out "private:: MPI_Sizeof_xint8\n";
        print Out "private:: MPI_Sizeof_xint16\n";
        print Out "private:: MPI_Sizeof_xint32\n";
        print Out "private:: MPI_Sizeof_xint64\n";
        print Out "private:: MPI_Sizeof_xreal32\n";
        print Out "private:: MPI_Sizeof_xreal64\n";
        print Out "private:: MPI_Sizeof_xreal128\n";
        print Out "private:: MPI_Sizeof_xcomplex32\n";
        print Out "private:: MPI_Sizeof_xcomplex64\n";
        print Out "private:: MPI_Sizeof_xcomplex128\n";

        print Out "contains\n";
        print Out "subroutine MPI_Sizeof_character(x, size, ierror)\n";
        print Out "    character,dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_logical(x, size, ierror)\n";
        print Out "    logical,dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xint8(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: int8\n";
        print Out "    integer(int8),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xint16(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: int16\n";
        print Out "    integer(int16),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xint32(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: int32\n";
        print Out "    integer(int32),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xint64(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: int64\n";
        print Out "    integer(int64),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xreal32(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real32\n";
        print Out "    real(real32),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xreal64(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real64\n";
        print Out "    real(real64),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xreal128(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real128\n";
        print Out "    real(real128),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xcomplex32(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real32\n";
        print Out "    complex(real32),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xcomplex64(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real64\n";
        print Out "    complex(real64),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Sizeof_xcomplex128(x, size, ierror)\n";
        print Out "    use,intrinsic :: iso_fortran_env, only: real128\n";
        print Out "    complex(real128),dimension(..) :: x\n";
        print Out "    integer,intent(out) :: size\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    size = storage_size(x) / 8\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Status_f2f08(status_f, status_f08, ierror)\n";
        print Out "    integer,intent(in) :: status_f(MPI_STATUS_SIZE)\n";
        print Out "    type(MPI_Status),intent(out) :: status_f08\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    status_f08%count_lo = status_f(1)\n";
        print Out "    status_f08%count_hi_and_cancelled = status_f(2)\n";
        print Out "    status_f08%MPI_SOURCE = status_f(3)\n";
        print Out "    status_f08%MPI_TAG = status_f(4)\n";
        print Out "    status_f08%MPI_ERROR = status_f(5)\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Status_f082f(status_f08, status_f, ierror)\n";
        print Out "    type(MPI_Status),intent(in) :: status_f08\n";
        print Out "    integer,intent(out) :: status_f(MPI_STATUS_SIZE)\n";
        print Out "    integer,optional, intent(out) :: ierror\n";
        print Out "    status_f(1) = status_f08%count_lo\n";
        print Out "    status_f(2) = status_f08%count_hi_and_cancelled\n";
        print Out "    status_f(3) = status_f08%MPI_SOURCE\n";
        print Out "    status_f(4) = status_f08%MPI_TAG\n";
        print Out "    status_f(5) = status_f08%MPI_ERROR\n";
        print Out "    if (present(ierror)) ierror = 0\n";
        print Out "end subroutine\n";
        print Out "elemental subroutine MPI_Status_f08_assign_c(status_f08, status_c)\n";
        print Out "    type(c_Status),intent(in) :: status_c\n";
        print Out "    type(MPI_Status),intent(out) :: status_f08\n";
        print Out "    status_f08%count_lo = status_c%count_lo\n";
        print Out "    status_f08%count_hi_and_cancelled = status_c%count_hi_and_cancelled\n";
        print Out "    status_f08%MPI_SOURCE = status_c%MPI_SOURCE\n";
        print Out "    status_f08%MPI_TAG = status_c%MPI_TAG\n";
        print Out "    status_f08%MPI_ERROR = status_c%MPI_ERROR\n";
        print Out "end subroutine\n";
        print Out "elemental subroutine MPI_Status_c_assign_f08(status_c, status_f08)\n";
        print Out "    type(MPI_Status),intent(in) :: status_f08\n";
        print Out "    type(c_Status),intent(out) :: status_c\n";
        print Out "    status_c%count_lo = status_f08%count_lo\n";
        print Out "    status_c%count_hi_and_cancelled = status_f08%count_hi_and_cancelled\n";
        print Out "    status_c%MPI_SOURCE = status_f08%MPI_SOURCE\n";
        print Out "    status_c%MPI_TAG = status_f08%MPI_TAG\n";
        print Out "    status_c%MPI_ERROR = status_f08%MPI_ERROR\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Status_f_assign_c(status_f, status_c)\n";
        print Out "    type(c_Status),intent(in) :: status_c\n";
        print Out "    integer,intent(out) :: status_f(MPI_STATUS_SIZE)\n";
        print Out "    status_f(1) = status_c%count_lo\n";
        print Out "    status_f(2) = status_c%count_hi_and_cancelled\n";
        print Out "    status_f(3) = status_c%MPI_SOURCE\n";
        print Out "    status_f(4) = status_c%MPI_TAG\n";
        print Out "    status_f(5) = status_c%MPI_ERROR\n";
        print Out "end subroutine\n";
        print Out "subroutine MPI_Status_c_assign_f(status_c, status_f)\n";
        print Out "    integer,intent(in) :: status_f(MPI_STATUS_SIZE)\n";
        print Out "    type(c_Status),intent(out) :: status_c\n";
        print Out "    status_c%count_lo = status_f(1)\n";
        print Out "    status_c%count_hi_and_cancelled = status_f(2)\n";
        print Out "    status_c%MPI_SOURCE = status_f(3)\n";
        print Out "    status_c%MPI_TAG = status_f(4)\n";
        print Out "    status_c%MPI_ERROR = status_f(5)\n";
        print Out "end subroutine\n";
        print Out "function MPI_Status_f082c(status_f08, status_c) bind(C, name=\"MPI_Status_f082c\")  result (res)\n";
        print Out "    use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "    type(MPI_Status),intent(in) :: status_f08\n";
        print Out "    type(c_Status),intent(out) :: status_c\n";
        print Out "    integer(c_int) :: res\n";
        print Out "\n";
        print Out "    status_c = status_f08\n";
        print Out "    res = 0\n";
        print Out "end function\n";
        print Out "function MPI_Status_c2f08(status_c, status_f08) bind(C, name=\"MPI_Status_c2f08\")  result (res)\n";
        print Out "    use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "    type(c_Status),intent(in) :: status_c\n";
        print Out "    type(MPI_Status),intent(out) :: status_f08\n";
        print Out "    integer(c_int) :: res\n";
        print Out "\n";
        print Out "    status_f08 = status_c\n";
        print Out "    res = 0\n";
        print Out "end function\n";
        print Out "function PMPI_Status_f082c(status_f08, status_c) bind(C, name=\"PMPI_Status_f082c\")  result (res)\n";
        print Out "    use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "    type(MPI_Status),intent(in) :: status_f08\n";
        print Out "    type(c_Status),intent(out) :: status_c\n";
        print Out "    integer(c_int) :: res\n";
        print Out "\n";
        print Out "    status_c = status_f08\n";
        print Out "    res = 0\n";
        print Out "end function\n";
        print Out "function PMPI_Status_c2f08(status_c, status_f08) bind(C, name=\"PMPI_Status_c2f08\")  result (res)\n";
        print Out "    use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "    type(c_Status),intent(in) :: status_c\n";
        print Out "    type(MPI_Status),intent(out) :: status_f08\n";
        print Out "    integer(c_int) :: res\n";
        print Out "\n";
        print Out "    status_f08 = status_c\n";
        print Out "    res = 0\n";
        print Out "end function\n";
        print Out "function MPI_Comm_eq(x, y) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Comm_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Comm_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Comm_neq(x, y) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Comm_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Comm_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Comm), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Comm_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Comm\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Comm):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Comm_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Comm\n";
        print Out "    integer(c_Comm), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Win_eq(x, y) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Win_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Win_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Win_neq(x, y) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Win_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Win_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Win), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Win_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Win\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Win):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Win_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Win\n";
        print Out "    integer(c_Win), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_File_eq(x, y) result (res)\n";
        print Out "    type(MPI_File), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_File_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_File), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_File_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_File), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_File_neq(x, y) result (res)\n";
        print Out "    type(MPI_File), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_File_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_File), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_File_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_File), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_File_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_File\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_File):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_File_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_File\n";
        print Out "    integer(c_File), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Group_eq(x, y) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Group_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Group_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Group_neq(x, y) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Group_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Group_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Group), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Group_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Group\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Group):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Group_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Group\n";
        print Out "    integer(c_Group), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Op_eq(x, y) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Op_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Op_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Op_neq(x, y) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Op_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Op_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Op), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Op_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Op\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Op):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Op_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Op\n";
        print Out "    integer(c_Op), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Datatype_eq(x, y) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Datatype_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Datatype_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Datatype_neq(x, y) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Datatype_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Datatype_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Datatype), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Datatype_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Datatype\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Datatype):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Datatype_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Datatype\n";
        print Out "    integer(c_Datatype), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Request_eq(x, y) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Request_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Request_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Request_neq(x, y) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Request_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Request_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Request), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Request_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Request\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Request):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Request_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Request\n";
        print Out "    integer(c_Request), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Info_eq(x, y) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Info_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Info_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Info_neq(x, y) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Info_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Info_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Info), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Info_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Info\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Info):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Info_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Info\n";
        print Out "    integer(c_Info), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Errhandler_eq(x, y) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Errhandler_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Errhandler_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Errhandler_neq(x, y) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Errhandler_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Errhandler_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Errhandler), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Errhandler_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Errhandler\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Errhandler):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Errhandler_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Errhandler\n";
        print Out "    integer(c_Errhandler), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Message_eq(x, y) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Message_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Message_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Message_neq(x, y) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Message_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Message_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Message), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Message_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Message\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Message):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Message_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Message\n";
        print Out "    integer(c_Message), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "function MPI_Session_eq(x, y) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL == y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Session_f08_eq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";

        print Out "function MPI_Session_f_eq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL == f)\n";
        print Out "end function\n";
        print Out "function MPI_Session_neq(x, y) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: x,y\n";
        print Out "    logical:: res\n";
        print Out "    res = (x%MPI_VAL /= y%MPI_VAL)\n";
        print Out "end function\n";

        print Out "function MPI_Session_f08_neq_f(f08, f) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";

        print Out "function MPI_Session_f_neq_f08(f, f08) result (res)\n";
        print Out "    type(MPI_Session), intent(in):: f08\n";
        print Out "    integer, intent(in):: f\n";
        print Out "    logical:: res\n";
        print Out "    res = (f08%MPI_VAL /= f)\n";
        print Out "end function\n";
        print Out "function MPI_Session_f2c(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Session\n";
        print Out "    integer, value:: x\n";
        print Out "    integer(c_Session):: res\n";
        print Out "    res = x\n";
        print Out "end function\n";

        print Out "function MPI_Session_c2f(x) result (res)\n";
        print Out "    use mpi_c_interface_types, only: c_Session\n";
        print Out "    integer(c_Session), value:: x\n";
        print Out "    integer:: res\n";
        print Out "    res = x\n";
        print Out "end function\n";
        print Out "\n";
        print Out "end module MPI_f08_types\n";
        close Out;

        open Out, ">$dir/mpi_c_interface_types.f90" or die "Can't write $dir/mpi_c_interface_types.f90: $!\n";
        print "  --> [$dir/mpi_c_interface_types.f90]\n";
        print Out "!      \n";
        print Out "!      Copyright (C) by Argonne National Laboratory\n";
        print Out "!          See COPYRIGHT in top-level directory\n";
        print Out "!      \n";
        print Out "!      DO NOT EDIT\n";
        print Out "!      This file created by buildiface\n";
        print Out "!      \n";
        print Out "module mpi_c_interface_types\n";
        print Out "\n";
        print Out "use, intrinsic:: iso_c_binding\n";
        print Out "implicit none\n";
        print Out "integer,parameter :: c_Fint = KIND(0)\n";
        print Out "integer,parameter :: c_Aint = $mpidef{MPI_AINT_KIND}\n";
        print Out "integer,parameter :: c_Count = $mpidef{MPI_COUNT_KIND}\n";
        print Out "integer,parameter :: c_Offset = $mpidef{MPI_OFFSET_KIND}\n";
        print Out "integer,parameter :: c_Comm = c_int\n";
        print Out "integer,parameter :: c_Win = c_int\n";
        print Out "integer,parameter :: c_File = c_intptr_t\n";
        print Out "integer,parameter :: c_Group = c_int\n";
        print Out "integer,parameter :: c_Op = c_int\n";
        print Out "integer,parameter :: c_Datatype = c_int\n";
        print Out "integer,parameter :: c_Request = c_int\n";
        print Out "integer,parameter :: c_Info = c_int\n";
        print Out "integer,parameter :: c_Errhandler = c_int\n";
        print Out "integer,parameter :: c_Message = c_int\n";
        print Out "integer,parameter :: c_Session = c_int\n";
        print Out "type, bind(c) :: c_Status\n";
        my $sp = "    ";
        print Out "${sp}integer(c_int) :: count_lo\n";
        print Out "${sp}integer(c_int) :: count_hi_and_cancelled\n";
        print Out "${sp}integer(c_int) :: MPI_SOURCE\n";
        print Out "${sp}integer(c_int) :: MPI_TAG\n";
        print Out "${sp}integer(c_int) :: MPI_ERROR\n";
        print Out "end type c_Status\n";
        print Out "\n";
        print Out "end module mpi_c_interface_types\n";
        close Out;
        open Out, ">$dir/mpi_f08_compile_constants.f90" or die "Can't write $dir/mpi_f08_compile_constants.f90: $!\n";
        print "  --> [$dir/mpi_f08_compile_constants.f90]\n";
        print Out "!      \n";
        print Out "!      Copyright (C) by Argonne National Laboratory\n";
        print Out "!          See COPYRIGHT in top-level directory\n";
        print Out "!      \n";
        print Out "!      DO NOT EDIT\n";
        print Out "!      This file created by buildiface\n";
        print Out "!      \n";
        print Out "module mpi_f08_compile_constants\n";
        print Out "\n";
        print Out "use,intrinsic :: iso_c_binding, only: c_int\n";
        print Out "use :: mpi_f08_types\n";
        print Out "use :: mpi_c_interface_types, only: c_Aint, c_Count, c_Offset\n";
        print Out "\n";
        print Out "private :: c_int\n";
        print Out "private :: c_Aint, c_Count, c_Offset\n";
        foreach my $k (@mpidef_list) {
            if ($k=~/^MPI_DISPLACEMENT_CURRENT/) {
                print Out "integer(kind=MPI_OFFSET_KIND), parameter :: $k = $mpidef{$k}\n";
            }
            elsif ($mpidef_type{$k}) {
                my $T = $mpidef_type{$k};
                printf Out "type($T), parameter :: %s = $T(%d)\n", $k, $mpidef{$k};
            }
            else {
                printf Out "integer, parameter :: %20s = %d\n", $k, $mpidef{$k};
            }
        }
        print Out "\n";
        print Out "end module mpi_f08_compile_constants\n";
        close Out;
        open Out, ">$dir/mpi_f08_link_constants.f90" or die "Can't write $dir/mpi_f08_link_constants.f90: $!\n";
        print "  --> [$dir/mpi_f08_link_constants.f90]\n";
        print Out "!      \n";
        print Out "!      Copyright (C) by Argonne National Laboratory\n";
        print Out "!          See COPYRIGHT in top-level directory\n";
        print Out "!      \n";
        print Out "!      DO NOT EDIT\n";
        print Out "!      This file created by buildiface\n";
        print Out "!      \n";
        print Out "module mpi_f08_link_constants\n";
        print Out "\n";
        print Out "use,intrinsic:: iso_c_binding, only: c_ptr, c_int, c_char, c_loc\n";
        print Out "use :: mpi_f08_types, only: MPI_Status\n";
        print Out "use :: mpi_c_interface_types, only: c_Status\n";
        print Out "implicit none\n";
        print Out "type(MPI_Status, bind(C, name=\"MPIR_F08_MPI_STATUS_IGNORE_OBJ\"), target:: MPI_STATUS_IGNORE\n";
        print Out "type(c_ptr), bind(C, name=\"MPIR_C_MPI_STATUS_IGNORE\") :: MPIR_C_MPI_STATUS_IGNORE\n";
        print Out "type(c_ptr), bind(C, name=\"MPI_F08_STATUS_IGNORE\") :: MPI_F08_STATUS_IGNORE\n";
        print Out "type(MPI_Status, dimension(1), bind(C, name=\"MPIR_F08_MPI_STATUSES_IGNORE_OBJ\"), target:: MPI_STATUSES_IGNORE\n";
        print Out "type(c_ptr), bind(C, name=\"MPIR_C_MPI_STATUSES_IGNORE\") :: MPIR_C_MPI_STATUSES_IGNORE\n";
        print Out "type(c_ptr), bind(C, name=\"MPI_F08_STATUSES_IGNORE\") :: MPI_F08_STATUSES_IGNORE\n";
        print Out "character(len=1), dimension(1), target :: MPI_ARGV_NULL\n";
        print Out "type(c_ptr), bind(C, name=\"MPIR_C_MPI_ARGV_NULL\") :: MPIR_C_MPI_ARGV_NULL\n";
        print Out "character(len=1), dimension(1,1), target :: MPI_ARGVS_NULL\n";
        print Out "type(c_ptr), bind(C, name=\"MPIR_C_MPI_ARGVS_NULL\") :: MPIR_C_MPI_ARGVS_NULL\n";
        print Out "integer, dimension(1), target :: MPI_ERRCODES_IGNORE\n";
        print Out "type(c_ptr), bind(C, name=\"MPIR_C_MPI_ERRCODES_IGNORE\") :: MPIR_C_MPI_ERRCODES_IGNORE\n";
        print Out "integer, dimension(1), target :: MPI_UNWEIGHTED\n";
        print Out "type(c_ptr), protected, bind(C, name=\"MPIR_C_MPI_UNWEIGHTED\") :: MPIR_C_MPI_UNWEIGHTED\n";
        print Out "integer, dimension(1), target :: MPI_WEIGHTS_EMPTY\n";
        print Out "type(c_ptr), protected, bind(C, name=\"MPIR_C_MPI_WEIGHTS_EMPTY\") :: MPIR_C_MPI_WEIGHTS_EMPTY\n";
        print Out "integer(c_int), bind(C, name=\"MPIR_F08_MPI_IN_PLACE\") :: MPI_IN_PLACE\n";
        print Out "integer(c_int), bind(C, name=\"MPIR_F08_MPI_BOTTOM\") :: MPI_BOTTOM\n";
        print Out "\n";
        print Out "end module mpi_f08_link_constants\n";
        close Out;
    }
    if ($opts{"enable-mpi-abi"}) {
        $make_conds{BUILD_ABI_LIB} = 1;
    }
    if ($opts{cc_weak} eq "no") {
        $make_conds{BUILD_PROFILING_LIB} = 1;
    }
    else {
        $make_conds{BUILD_PROFILING_LIB} = 0;
    }
    $make_conds{BUILD_COVERAGE} = 0;
    $make_conds{MAINTAINER_MODE} = 0;
    $make_conds{BUILD_BASH_SCRIPTS} = 0;
    $make_conds{INSTALL_MPIF77} = 0;

    $make_conds{BUILD_NAMEPUB_FILE}=0;
    $make_conds{BUILD_NAMEPUB_PMI}=0;
    $make_conds{BUILD_PM_HYDRA}=0;
    $make_conds{BUILD_PM_HYDRA2}=0;
    $make_conds{BUILD_PM_GFORKER}=0;
    $make_conds{BUILD_PM_REMSHELL}=0;
    $make_conds{BUILD_PM_UTIL}=0;
    $make_conds{PRIMARY_PM_HYDRA}=0;
    $make_conds{PRIMARY_PM_GFORKER}=0;
    $make_conds{PRIMARY_PM_REMSHELL}=0;
    $opts{enable_shm} = 1;
    if ($opts{device} =~ /ch3/) {
        $make_conds{BUILD_CH3} = 1;
        if ($opts{device} =~/ch3:sock/) {
            $make_conds{BUILD_CH3_SOCK}=1;
            $make_conds{BUILD_CH3_UTIL_SOCK}=1;
        }
        else {
            $make_conds{BUILD_CH3_NEMESIS}=1;
            if ($opts{device}=~/ofi/) {
                $make_conds{BUILD_NEMESIS_NETMOD_OFI}=1;
            }
            else {
                $make_conds{BUILD_NEMESIS_NETMOD_TCP}=1;
            }
        }
    }
    else {
        $make_conds{BUILD_CH4} = 1;
        if ($opts{device} =~/ch4:ofi/) {
            $make_conds{BUILD_CH4_NETMOD_OFI} = 1;
        }
        else {
            $make_conds{BUILD_CH4_NETMOD_UCX} = 1;
            if (0) {
                $make_conds{BUILD_HCOLL} = 1;
            }
        }
        if ($opts{"without-ch4-shmmods"}) {
            $opts{enable_shm} = 1;
            open In, "src/mpid/ch4/subconfigure.m4" or die "Can't open src/mpid/ch4/subconfigure.m4: $!\n";
            while(<In>){
                if (/AM_CONDITIONAL.*BUILD_CH4_SHM/) {
                    $opts{enable_shm} = 0;
                    last;
                }
            }
            close In;
        }

        if ($opts{enable_shm}) {
            $make_conds{BUILD_CH4_SHM} = 1;
            $make_conds{BUILD_SHM_POSIX} = 1;
            if (-f "src/mpid/ch4/shm/posix/eager/iqueue/iqueue_pre.h") {
                $make_conds{BUILD_CH4_SHM_POSIX_EAGER_IQUEUE} = 1;
            }
            else {
                $make_conds{BUILD_CH4_SHM_POSIX_EAGER_FBOX} = 1;
            }

            if (0) {
                $make_conds{BUILD_SHM_IPC_XPMEM} = 1;
            }
        }
        if (0) {
            $make_conds{BUILD_CH4_COLL_TUNING} = 1;
        }
    }

    if ($temp{MPICH_DATATYPE_ENGINE} eq "MPICH_DATATYPE_ENGINE_DATALOOP") {
        $make_conds{BUILD_DATALOOP_ENGINE} = 1;
    }
    elsif ($temp{MPICH_DATATYPE_ENGINE} eq "MPICH_DATATYPE_ENGINE_YAKSA") {
        $make_conds{BUILD_YAKSA_ENGINE} = 1;
    }

    $make_conds{BUILD_MPID_COMMON_SCHED} = 1;
    $make_conds{BUILD_MPID_COMMON_THREAD} = 1;
    $make_conds{BUILD_MPID_COMMON_SELF} = 1;
    if ($opts{device}=~/ch4/) {
        $make_conds{BUILD_MPID_COMMON_SHM} = 1;
        $make_conds{BUILD_MPID_COMMON_BC} = 1;
        $make_conds{BUILD_MPID_COMMON_GENQ} = 1;
        $make_conds{BUILD_MPID_COMMON_STREAM_WORKQ} = 1;
    }
    elsif ($opts{device}=~/ch3:sock/) {
    }
    else {
        $make_conds{BUILD_MPID_COMMON_SHM} = 1;
    }


    if (!$opts{disable_cxx}) {
        $make_conds{BUILD_CXX_BINDING} = 1;
    }

    if (!$opts{disable_fortran}) {
        $make_conds{BUILD_F77_BINDING} = 1;
        $make_conds{BUILD_FC_BINDING} = 1;
        if ($opts{f08}) {
            $make_conds{BUILD_F08_BINDING} = 1;
            $config_defines{HAVE_F08_BINDING} = 1;
        }
        else {
            $config_defines{HAVE_F08_BINDING} = 0;
        }
    }
    else {
        system "touch src/binding/fortran/mpif_h/Makefile.mk";
        system "touch src/binding/fortran/use_mpi/Makefile.mk";
        system "touch src/binding/fortran/use_mpi_f08/Makefile.mk";
    }

    if (1) {
        $make_conds{BUILD_PMI_SIMPLE} = 1;
    }
    else {
        $make_conds{BUILD_PMI_PMI2_SIMPLE}=1;
        $make_conds{BUILD_PMI_BGQ}=0;
    }
    if (1) {
        $make_conds{BUILD_NAMEPUB_PMI}=1;
    }
    open Out, ">mymake/make_conds.mpich" or die "Can't write mymake/make_conds.mpich: $!\n";
    print "  --> [mymake/make_conds.mpich]\n";
    foreach my $k (sort keys %make_conds) {
        print Out "$k: $make_conds{$k}\n";
    }
    close Out;


    $sizeof_hash{OPA_PTR_T} = 8;

    open Out, ">mymake/make_opts.mpich" or die "Can't write mymake/make_opts.mpich: $!\n";
    print "  --> [mymake/make_opts.mpich]\n";
    print Out "CC: $opts{CC}\n";
    print Out "CXX: $opts{CXX}\n";
    print Out "F77: $opts{F77}\n";
    print Out "FC: $opts{FC}\n";
    print Out "cc_version: $opts{cc_version}\n";
    print Out "cc_weak: $opts{cc_weak}\n";
    my $cflags = "-g -O2";
    my $ldflags = "";
    if ($opts{cflags}) {
        $cflags = $opts{cflags};
    }
    if (%config_cflags) {
        my @tlist = split /\s+/, $cflags;
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
        $cflags = join(' ', sort @tlist);
        print(STDOUT "  -->  CFLAGS = $cflags\n");
    }
    print Out "cflags: $cflags\n";
    if ($opts{ldflags}) {
        $ldflags = $opts{ldflags};
    }
    if (%config_ldflags) {
        my @tlist = split /\s+/, $ldflags;
        foreach my $a (@tlist) {
            if (!$config_ldflags{$a}) {
                $config_ldflags{$a} = 1;
            }
        }
        $ldflags = join ' ', sort keys %config_ldflags;
        print(STDOUT "  -->  LDFLAGS = $ldflags\n");
    }
    print Out "ldflags: $ldflags\n";
    close Out;
}
elsif ($config eq "mpl") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"mpl"';
    $config_defines{PACKAGE_BUGREPORT}='""';
    $config_defines{PACKAGE_NAME}='"MPL"';
    $config_defines{PACKAGE_STRING}="\"MPL 0.1\"";
    $config_defines{PACKAGE_TARNAME}='"mpl"';
    $config_defines{PACKAGE_URL}='""';
    $config_defines{PACKAGE_VERSION}="\"0.1\"";
    $config_defines{VERSION}="\"0.1\"";
    $config_defines{_ALL_SOURCE}=1;
    $config_defines{_GNU_SOURCE}=1;
    $config_defines{_POSIX_PTHREAD_SEMANTICS}=1;
    $config_defines{_TANDEM_SOURCE}=1;
    $config_defines{__EXTENSIONS__}=1;
    $config_defines{CACHELINE_SIZE} = 64;

    $config_defines{THREAD_PACKAGE_NAME} = "MPL_THREAD_PACKAGE_POSIX";
    $config_defines{PROC_MUTEX_PACKAGE_NAME} = "MPL_PROC_MUTEX_PACKAGE_POSIX";
    if (!$config_defines{POSIX_MUTEX_NAME}) {
        $config_defines{POSIX_MUTEX_NAME} = "MPL_POSIX_MUTEX_NATIVE";
    }

    if ($opts{"with-shared-memory"} eq "sysv") {
        $config_defines{USE_SYSV_SHM} = 1;
    }
    else {
        $config_defines{USE_MMAP_SHM} = 1;
    }
    $config_defines{USE_NOTHING_FOR_YIELD} = 1;

    $config_defines{HAVE_CLOCK_GETTIME} = 1;
    $config_defines{HAVE_CLOCK_GETRES} = 1;
    $config_defines{HAVE_GETTIMEOFDAY} = 1;

    if (test_cc_header($opts{CC}, "stdatomic.h")) {
        $config_defines{HAVE_C11_ATOMICS}=1;
    }
    $config_defines{HAVE_GCC_INTRINSIC_ATOMIC}=1;
    $config_defines{HAVE_GCC_INTRINSIC_SYNC}=1;

    if ($opts{cc_version}=~/gcc 4/) {
        $config_defines{COMPILER_TLS}="__thread";
    }
    else {
        $config_defines{COMPILER_TLS}="_Thread_local";
    }
    $config_defines{DEFINE_ALIGNED_ALLOC}=1;
    $config_defines{HAVE_VAR_ATTRIBUTE_USED}=1;
    $config_defines{HAVE_VAR_ATTRIBUTE_ALIGNED}=1;
    $config_defines{HAVE__BOOL}=1;
    $config_defines{HAVE___TYPEOF}=1;

    $config_defines{HAVE_ALIGNED_ALLOC}=1;
    $config_defines{HAVE_BROKEN_VALGRIND}=1;
    $config_defines{HAVE_FDOPEN}=1;
    $config_defines{HAVE_GETIFADDRS}=1;
    $config_defines{HAVE_GETPID}=1;
    $config_defines{HAVE_INET_NTOP}=1;
    $config_defines{HAVE_SLEEP}=1;
    $config_defines{HAVE_USLEEP}=1;

    if ($opts{"with-cuda"}) {
        $config_defines{HAVE_GPU} = 1;
        $config_defines{HAVE_CUDA} = 1;
    }

    $config_defines{HAVE_PTHREAD_MUTEXATTR_SETPSHARED} = 1;

    $config_defines{backtrace_size_t} = "int";
    my %confs;
    $confs{MPL_TIMER_TYPE} = "struct timespec";
    $confs{MPL_TIMER_KIND} = "MPL_TIMER_KIND__CLOCK_GETTIME";
    autoconf_file("src/mpl/include/mpl_timer.h", \%confs);
}
elsif ($config eq "pmi") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"pmi"';
    $config_defines{PACKAGE_BUGREPORT}='""';
    $config_defines{PACKAGE_NAME}='"PMI"';
    $config_defines{PACKAGE_STRING}="\"PMI 1.2\"";
    $config_defines{PACKAGE_TARNAME}='"pmi"';
    $config_defines{PACKAGE_URL}='""';
    $config_defines{PACKAGE_VERSION}="\"1.2\"";
    $config_defines{VERSION}="\"1.2\"";
    $config_defines{HAVE_MPI_H} = 1;
    $config_defines{USE_PMI_PORT} = 1;
    $config_defines{HAVE_THREADS} = 1;
    $config_defines{HAVE_ERROR_CHECKING} = 1;
}
elsif ($config eq "opa") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"openpa"';
    $config_defines{PACKAGE_BUGREPORT}='"https://trac.mcs.anl.gov/projects/openpa/newticket"';
    $config_defines{PACKAGE_NAME}='"OpenPA"';
    $config_defines{PACKAGE_STRING}="\"OpenPA 1.0.3\"";
    $config_defines{PACKAGE_TARNAME}='"openpa"';
    $config_defines{PACKAGE_URL}='""';
    $config_defines{PACKAGE_VERSION}="\"1.0.3\"";
    $config_defines{VERSION}="\"1.0.3\"";
    $config_defines{OPA_HAVE_GCC_INTRINSIC_ATOMICS} = 1;
    $config_defines{OPA_HAVE_GCC_X86_32_64} = 1;
    $config_defines{OPA_HAVE_GCC_X86_32_64_P3} = 1;

    $config_defines{HAVE_LIBPTHREAD}=1;
    $config_defines{OPA_MAX_NTHREADS} = 100;

    $config_defines{SIZEOF_INT} = $sizeof_hash{INT};
    $config_defines{SIZEOF_VOID_P} = $sizeof_hash{VOID_P};
}
elsif ($config eq "hydra") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"hydra"';
    $config_defines{PACKAGE_BUGREPORT}='""';
    $config_defines{PACKAGE_NAME}='"Hydra"';
    $config_defines{PACKAGE_STRING}="\"Hydra $version\"";
    $config_defines{PACKAGE_TARNAME}='"hydra"';
    $config_defines{PACKAGE_URL}='""';
    $config_defines{PACKAGE_VERSION}="\"$version\"";
    $config_defines{VERSION}="\"$version\"";
    $config_defines{_ALL_SOURCE}=1;
    $config_defines{_GNU_SOURCE}=1;
    $config_defines{_POSIX_PTHREAD_SEMANTICS}=1;
    $config_defines{_TANDEM_SOURCE}=1;
    $config_defines{__EXTENSIONS__}=1;
    $config_defines{HYDRA_CC} = "\"$opts{CC} -g -O2   \"";
    $config_defines{HYDRA_CONFIGURE_ARGS_CLEAN} = "\"'CC=' 'CFLAGS=-g -O2'\"";
    $config_defines{HYDRA_PMI_PROXY} = '"hydra_pmi_proxy"';
    $config_defines{HYDRA_RELEASE_DATE} = '"unreleased development copy"';
    $config_defines{HYDRA_VERSION} = $config_defines{VERSION};

    $config_defines{HAVE_HWLOC} = 1;
    $config_defines{USE_SIGACTION} = "\x2f**/";

    $config_defines{HAVE_BSS_EXTERNAL}=1;
    $config_defines{HAVE_BSS_PERSIST}=1;
    $config_defines{HAVE_ERROR_CHECKING}=1;
    $config_defines{HAVE_EXTERN_ENVIRON}=1;
    if ($opts{uname}=~/FreeBSD|Darwin/i) {
        $config_defines{MANUAL_EXTERN_ENVIRON}=1;
    }
    $config_defines{ENABLE_PROFILING}=1;

    $config_defines{HYDRA_CXX}="\"$opts{CXX} \"";
    $config_defines{HYDRA_F77}="\"$opts{F77} \"";
    $config_defines{HYDRA_F90}="\"$opts{F90} \"";

    delete $config_defines{HAVE_ALLOCA};
    $config_defines{HAVE_FCNTL}=1;
    $config_defines{HAVE_GETIFADDRS}=1;
    $config_defines{HAVE_GETPGID}=1;
    $config_defines{HAVE_GETTIMEOFDAY}=1;
    $config_defines{HAVE_HSTRERROR}=1;
    $config_defines{HAVE_INET_NTOP}=1;
    $config_defines{HAVE_ISATTY}=1;
    $config_defines{HAVE_KILLPG}=1;
    $config_defines{HAVE_POLL}=1;
    $config_defines{HAVE_POSIX_REGCOMP}=1;
    $config_defines{HAVE_SETSID}=1;
    $config_defines{HAVE_SIGACTION}=1;
    $config_defines{HAVE_SIGSET}=1;
    $config_defines{HAVE_STAT}=1;
    $config_defines{HAVE_STRSIGNAL}=1;
    $config_defines{HAVE_TIME}=1;
    $config_defines{HAVE_UNSETENV}=1;
    $config_defines{HAVE_USLEEP}=1;

    delete $headers_hash{SLURM_SLURM_H};
    my @launchers=qw(ssh rsh fork slurm ll lsf sge manual persist);
    my @rmks=qw(user slurm ll lsf sge pbs cobalt);
    my @demuxes=qw(poll select);
    my @topolibs=qw(hwloc);
    my %confs;
    $confs{hydra_launcher_array} = ' "'. join('",  "', @launchers). '",  NULL';
    $confs{hydra_rmk_array}      = ' "'. join('",  "', @rmks). '",  NULL';
    $confs{hydra_launcher_init_array} = ' HYDT_bsci_launcher_'. join('_init,  HYDT_bsci_launcher_', @launchers). '_init,  NULL';
    $confs{hydra_rmk_init_array} = ' HYDT_bsci_rmk_'. join('_init,  HYDT_bsci_rmk_', @rmks). '_init,  NULL';
    if (-f "src/pm/hydra/lib/tools/bootstrap/src/bsci_init.c.in") {
        autoconf_file("src/pm/hydra/lib/tools/bootstrap/src/bsci_init.c", \%confs);
    }
    else {
        autoconf_file("src/pm/hydra/tools/bootstrap/src/bsci_init.c", \%confs);
    }

    $config_defines{HYDRA_AVAILABLE_DEMUXES} = "\"@demuxes\"";
    $config_defines{HYDRA_DEFAULT_DEMUX} = "\"$demuxes[0]\"";
    $config_defines{HYDRA_AVAILABLE_LAUNCHERS} = "\"@launchers\"";
    $config_defines{HYDRA_DEFAULT_LAUNCHER} = "\"$launchers[0]\"";
    $config_defines{HYDRA_AVAILABLE_RMKS} = "\"@rmks\"";
    $config_defines{HYDRA_DEFAULT_RMK} = "\"$rmks[0]\"";
    $config_defines{HYDRA_AVAILABLE_TOPOLIBS} = "\"@topolibs\"";
    $config_defines{HYDRA_DEFAULT_TOPOLIB} = "\"$topolibs[0]\"";
    $config_defines{HYDRA_AVAILABLE_CKPOINTLIBS}='""';
}
elsif ($config eq "test") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    my $MPICC = "mpicc";
    if ($opts{"enable-mpi-abi"}) {
        $MPICC = "mpicc_abi";
    }
    $config_defines{PACKAGE}='"mpich-testsuite"';
    $config_defines{PACKAGE_BUGREPORT}='"discuss@mpich.org"';
    $config_defines{PACKAGE_NAME}='"mpich-testsuite"';
    $config_defines{PACKAGE_STRING}="\"mpich-testsuite $version\"";
    $config_defines{PACKAGE_TARNAME}='"mpich-testsuite"';
    $config_defines{PACKAGE_URL}='"http://www.mpich.org/"';
    $config_defines{PACKAGE_VERSION}="\"$version\"";
    $config_defines{VERSION}="\"$version\"";
    $config_defines{F77_NAME_LOWER_USCORE} = 1;
    $config_defines{HAVE_FLOAT__COMPLEX} = 1;
    $config_defines{HAVE_DOUBLE__COMPLEX} = 1;
    $config_defines{HAVE_LONG_DOUBLE__COMPLEX} = 1;
    $config_defines{HAVE_LONG_LONG} = 1;
    $config_defines{HAVE__BOOL} = 1;

    $config_defines{HAVE_MPI_INTEGER16} = 1;
    $config_defines{USE_LONG_DOUBLE_COMPLEX} = 1;

    if ($sizeof_hash{VOID_P} == $sizeof_hash{LONG}) {
        $config_defines{POINTERINT_t} = "long";
    }
    elsif ($sizeof_hash{VOID_P} == $sizeof_hash{LONG_LONG}) {
        $config_defines{POINTERINT_t} = "long long";
    }

    $config_defines{SIZEOF_MPI_OFFSET} = $sizeof_hash{VOID_P};

    $config_defines{THREAD_PACKAGE_NAME} = "THREAD_PACKAGE_POSIX";
    $config_defines{HAVE_MPI_WIN_CREATE} = 1;
    if ($opts{device}!~/ch4:ucx/) {
        $config_defines{HAVE_MPI_SPAWN} = 1;
    }

    if ($opts{"with-cuda"}) {
        $config_defines{HAVE_GPU} = 1;
        $config_defines{HAVE_CUDA} = 1;
    }
    if (-e "test/mpi/runtests.in") {
        my %confs;
        $confs{PERL}="/usr/bin/perl";
        $confs{MPIEXEC} = "mpiexec";
        $confs{MPI_IS_STRICT} = "false";
        $confs{RUN_XFAIL} = "false";
        autoconf_file("test/mpi/runtests", \%confs);
        system "chmod a+x test/mpi/runtests";
    }
    my %confs;
    my @all_testlists = glob("test/mpi/*/testlist.in");
    push @all_testlists, glob("test/mpi/*/*/testlist.in");
    foreach my $a (@all_testlists) {
        $a=~s/\.in$//;
        autoconf_file($a, \%confs);
    }
    if (!$opts{disable_fortran}) {
        my %confs;
        $confs{F77_MPI_ADDRESS} = "INTEGER*8";
        autoconf_file("test/mpi/f77/ext/add1size.h", \%confs);
    }
}
elsif ($config eq "dtpools") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"dtpools"';
    $config_defines{PACKAGE_BUGREPORT}='"discuss@mpich.org"';
    $config_defines{PACKAGE_NAME}='"dtpools"';
    $config_defines{PACKAGE_STRING}="\"dtpools 0.0\"";
    $config_defines{PACKAGE_TARNAME}='"dtpools"';
    $config_defines{PACKAGE_URL}='""';
    $config_defines{PACKAGE_VERSION}="\"0.0\"";
    $config_defines{VERSION}="\"0.0\"";
    $config_defines{HAVE_MEMSET} = 1;
}
elsif ($config eq "romio") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"romio"';
    $config_defines{PACKAGE_BUGREPORT}='"discuss@mpich.org"';
    $config_defines{PACKAGE_NAME}='"ROMIO"';
    $config_defines{PACKAGE_STRING}="\"ROMIO $version\"";
    $config_defines{PACKAGE_TARNAME}='"romio"';
    $config_defines{PACKAGE_URL}='"http://www.mpich.org/"';
    $config_defines{PACKAGE_VERSION}="\"$version\"";
    $config_defines{VERSION}="\"$version\"";
    $config_defines{_ALL_SOURCE}=1;
    $config_defines{_GNU_SOURCE}=1;
    $config_defines{_POSIX_PTHREAD_SEMANTICS}=1;
    $config_defines{_TANDEM_SOURCE}=1;
    $config_defines{__EXTENSIONS__}=1;
    $config_defines{HAVE_AIO_H} = 1;
    $config_defines{HAVE_DIRENT_H} = 1;
    $config_defines{HAVE_DLFCN_H} = 1;
    $config_defines{HAVE_FCNTL_H} = 1;
    $config_defines{HAVE_INTTYPES_H} = 1;
    $config_defines{HAVE_LIMITS_H} = 1;
    $config_defines{HAVE_MALLOC_H} = 1;
    $config_defines{HAVE_MEMORY_H} = 1;
    $config_defines{HAVE_MPIX_H} = 1;
    $config_defines{HAVE_SIGNAL_H} = 1;
    $config_defines{HAVE_STDDEF_H} = 1;
    $config_defines{HAVE_STDINT_H} = 1;
    $config_defines{HAVE_STDLIB_H} = 1;
    $config_defines{HAVE_STRINGS_H} = 1;
    $config_defines{HAVE_STRING_H} = 1;
    $config_defines{HAVE_SYS_MOUNT_H} = 1;
    $config_defines{HAVE_SYS_PARAM_H} = 1;
    $config_defines{HAVE_SYS_STATVFS_H} = 1;
    $config_defines{HAVE_SYS_STAT_H} = 1;
    $config_defines{HAVE_SYS_TYPES_H} = 1;
    $config_defines{HAVE_SYS_VFS_H} = 1;
    $config_defines{HAVE_TIME_H} = 1;
    $config_defines{HAVE_UNISTD_H} = 1;
    $config_defines{HAVE_FSYNC} = 1;
    $config_defines{HAVE_FTRUNCATE} = 1;
    $config_defines{HAVE_GCC_ATTRIBUTE} = 1;
    $config_defines{HAVE_LSTAT} = 1;
    $config_defines{HAVE_MEMALIGN} = 1;
    $config_defines{HAVE_READLINK} = 1;
    $config_defines{HAVE_STAT} = 1;
    $config_defines{HAVE_STATFS} = 1;
    $config_defines{HAVE_STATUS_SET_BYTES} = 1;
    $config_defines{HAVE_STATVFS} = 1;
    $config_defines{HAVE_STRDUP} = 1;
    $config_defines{HAVE_STRERROR} = 1;
    $config_defines{HAVE_USLEEP} = 1;

    $config_defines{LT_OBJDIR} = ".libs/";

    $config_defines{HAVE_LONG_LONG_64} = 1;
    $config_defines{HAVE_INT_LT_POINTER} = 1;
    $config_defines{HAVE_STRUCT_STATFS} = 1;
    $config_defines{HAVE_STRUCT_AIOCB_AIO_FILDES} = 1;
    $config_defines{HAVE_STRUCT_AIOCB_AIO_REQPRIO} = 1;
    $config_defines{HAVE_STRUCT_AIOCB_AIO_SIGEVENT} = 1;

    $config_defines{ROMIO_HAVE_STRUCT_STATFS_WITH_F_TYPE} = 1;
    $config_defines{ROMIO_HAVE_WORKING_AIO} = 1;
    $config_defines{ROMIO_INSIDE_MPICH} = 1;
    $config_defines{ROMIO_UFS} = 1;
    $config_defines{ROMIO_NFS} = 1;
    $config_defines{ROMIO_TESTFS} = 1;
    $config_defines{ROMIO_RUN_ON_LINUX} = 1;

    $config_defines{HAVE_PRAGMA_WEAK} = 1;
    $config_defines{HAVE_MULTIPLE_PRAGMA_WEAK} = 1;
    $config_defines{HAVE_WEAK_ATTRIBUTE} = 1;
    $config_defines{HAVE_WEAK_SYMBOLS} = 1;
    $config_defines{USE_WEAK_SYMBOLS} = 1;
    $config_defines{HAVE_VISIBILITY} = 1;
    $config_defines{HAVE_MPIO_CONST} = "const";
    $config_defines{HAVE_MPI_DARRAY_SUBARRAY} = 1;
    $config_defines{HAVE_MPI_INFO} = 1;
    $config_defines{HAVE_MPI_LONG_LONG_INT} = 1;
    $config_defines{HAVE_MPI_STATUS_SET_ELEMENTS_X} = 1;
    $config_defines{HAVE_MPI_TYPE_SIZE_X} = 1;
    $config_defines{HAVE_MPIX_TYPE_IOV} = 1;

    $config_defines{HAVE_DECL_PWRITE} = 1;
    $config_defines{HAVE_DECL_MPI_COMBINER_HINDEXED_BLOCK} = 1;
    my %confs;
    $confs{DEFINE_HAVE_MPI_GREQUEST} = "#define HAVE_MPI_GREQUEST 1";
    $confs{HAVE_MPI_INFO} = "#define HAVE_MPI_INFO";
    $confs{HAVE_MPI_DARRAY_SUBARRAY} = "#define HAVE_MPI_DARRAY_SUBARRAY";
    autoconf_file("src/mpi/romio/include/mpio.h", \%confs);
    system "touch src/mpi/romio/include/mpiof.h";
}

open In, "$config_in" or die "Can't open $config_in: $!\n";
while(<In>){
    if (/^#undef\s+(\w+)/) {
        my ($a) = ($1);
        if (exists $config_defines{$a}) {
        }
        elsif ($a=~/(SIZEOF|ALIGNOF)_(?:UNSIGNED_)?(\w+)/) {
            if ($sizeof_hash{$2}) {
                $config_defines{$a} = $sizeof_hash{$2};
            }
            else {
                $config_defines{$a} = 0;
            }
        }
        elsif ($a=~/HAVE_(?:UNSIGNED_)?(\w+)/ and $sizeof_hash{$1} and $1 ne "LONG_LONG") {
            $config_defines{$a} = 1;
        }
        elsif ($a=~/HAVE_(\w+_H)/) {
            if ($headers_hash{$1}) {
                $config_defines{$a} = 1;
            }
        }
    }
}
close In;
my $P;
if ($config_prefix) {
    $P = uc($config_prefix);
}

my @lines;
open In, "$config_in" or die "Can't open $config_in: $!\n";
while(<In>){
    if (/^#undef\s+(\w+)/) {
        my ($a) = ($1);
        if ($config_prefix) {
            my $b = "${P}_$a";
            if ($a=~/^(_|${P}_|const|inline|restrict)/) {
                $b = $a;
            }
            elsif ($a=~/^[a-z]/) {
                $b = "_${config_prefix}_$a";
            }

            my $val = $config_defines{$a};
            if (defined $config_defines{"${P}_$a"}) {
                $val = $config_defines{"${P}_$a"};
            }
            if (defined $val) {
                push @lines, "#ifndef $b\n";
                push @lines, "#define $b $val\n";
                push @lines, "#endif\n";
            }
            else {
                push @lines, "\x2f* #undef $b */\n";
            }
        }
        else {
            if (defined $config_defines{$a}) {
                push @lines, "#define $a $config_defines{$a}\n";
            }
            else {
                push @lines, "\x2f* #undef $a */\n";
            }
        }
    }
    elsif (/^# undef (\w+)/ and $config_defines{$1}) {
        push @lines, "# define $1 1\n";
    }
    else {
        push @lines, $_;
    }
}
close In;

open Out, ">$config_out" or die "Can't write $config_out: $!\n";
print "  --> [$config_out]\n";
if ($config_prefix) {
    print Out "#ifndef INCLUDE_${P}CONFIG_H\n";
    print Out "#define INCLUDE_${P}CONFIG_H 1\n";
}

foreach my $l (@lines) {
    print Out $l;
}

if ($config_prefix) {
    print Out "#endif\n";
}
close Out;

# ---- subroutines --------------------------------------------
sub get_cc_version {
    my ($cc) = @_;
    my $t;
    if ($cc =~/sun/) {
        $t = `$cc -V`;
    }
    else {
        $t=`$cc --version`;
    }
    if ($t=~/^(gcc) .*? ([0-9\.]+)/m) {
        return "$1 $2";
    }
    elsif ($t=~/^(clang) version ([0-9\.]+)/m) {
        return "$1 $2";
    }
    elsif ($t=~/^(Apple LLVM) version ([0-9\.]+)/m) {
        return "clang $2";
    }
    elsif ($t=~/^(icc) .*? ([0-9\.]+)/m) {
        return "intel $2";
    }
    elsif ($t=~/^(pgcc) .*? ([0-9\.]+)/m) {
        return "pgi $2";
    }
    elsif ($t=~/^(Studio) ([0-9\.]+)/m) {
        return "sun $2";
    }
    else {
        return "unknown";
    }
}

sub get_sizeof {
    my ($typelist, $headerlist) = @_;
    my $tname="t-$$";
    open Out, ">mymake/$tname.c" or die "Can't write mymake/$tname.c: $!\n";
    foreach my $t (@$headerlist) {
        print Out "#include <$t>\n";
    }
    print Out "int main() {\n";
    my $i = -1;
    foreach my $type (@$typelist) {
        $i++;
        if ($type=~/pair:(.+)/) {
            print Out "    struct {$1 a; int b;} A$i;\n";
            print Out "    printf(\"A$i: %lu\\n\", sizeof(A$i));\n";
        }
        else {
            print Out "    printf(\"A$i: %lu\\n\", sizeof($type));\n";
        }
    }
    print Out "    return 0;\n";
    print Out "}\n";
    close Out;

    my $t = `$opts{CC} mymake/$tname.c -o mymake/$tname.out 2>/dev/null && mymake/$tname.out`;
    if ($? == 0) {
        while ($t=~/A(\d+):\s+(\d+)/g) {
            my $name = get_config_name($typelist->[$1]);
            $sizeof_hash{$name} = $2;
        }
        return 1;
    }
    else {
        return 0;
    }
}

sub get_have_headers {
    my ($headerlist) = @_;
    my @cpp_paths;
    my $cpp = `$opts{CC} -print-prog-name=cpp`;
    chomp $cpp;
    if ($cpp) {
        my $t = `$cpp -v </dev/null 2>&1`;
        if ($t=~/#include <...> search starts here:(.*)End of search list./s) {
            my $t2 = $1;
            while ($t2=~/(\S+)/g) {
                push @cpp_paths, $1;
            }
        }
    }
    foreach my $h (@$headerlist) {
        my $name = uc(get_config_name($h));
        foreach my $dir (@cpp_paths) {
            if (-e "$dir/$h") {
                $headers_hash{$name} = "$dir/$h";
                last;
            }
        }
    }
}

sub autoconf_file {
    my ($file, $conf_hash) = @_;
    my @lines;
    open In, "$file.in" or die "Can't open $file.in: $!\n";
    while(<In>){
        s/\@(\w+)\@/$conf_hash->{$1}/g;
        push @lines, $_;
    }
    close In;
    open Out, ">$file" or die "Can't write $file: $!\n";
    print "  --> [$file]\n";
    foreach my $l (@lines) {
        print Out $l;
    }
    close Out;
}

sub get_config_name {
    my ($type) = @_;
    if ($type=~/pair:(.+)/) {
        if ($1 eq "int") {
            return "TWO_INT";
        }
        else {
            $type="$1 int";
        }
    }
    elsif ($type eq "__float128") {
        $type = "float128";
    }

    $type =~ tr/\* \/./p_/;
    return uc($type);
}

sub test_cc_header {
    my ($cc, $header) = @_;
    open Out, ">mymake/t.c" or die "Can't write mymake/t.c: $!\n";
    print Out "#include <$header>\n";
    print Out "int main(){return 0;}\n";
    close Out;
    system "$cc -c -o mymake/t.o mymake/t.c 2>/dev/null";
    if ($? == 0) {
        return 1;
    }
    else {
        return 0;
    }
}

