#!/usr/bin/perl
use strict;
use Cwd;

our $config;
our $config_in;
our $config_out;
our %config_defines;
our %opts;
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
$config = shift @ARGV;
print "-- mymake_config $config ...\n";

if ($config eq "mpich") {
    $config_in = "$mymake_dir/config_templates/mpichconf.h";
    $config_out = "src/include/mpichconf.h";
}
elsif ($config eq "mpl") {
    $config_in = "$mymake_dir/config_templates/mplconfig.h";
    $config_out = "mymake/mpl/include/mplconfig.h";
    symlink "../../libtool", "mymake/mpl/libtool";
}
elsif ($config eq "hydra") {
    $config_in = "$mymake_dir/config_templates/hydra_config.h";
    $config_out = "src/pm/hydra/include/hydra_config.h";
    symlink "../../../libtool", "src/pm/hydra/libtool";
}
elsif ($config eq "test") {
    $config_in = "$mymake_dir/config_templates/mpitestconf.h";
    $config_out = "test/mpi/include/mpitestconf.h";
    symlink "../../libtool", "test/mpi/libtool";
}
elsif ($config eq "dtpools") {
    $config_in = "$mymake_dir/config_templates/dtpoolsconf.h";
    $config_out = "test/mpi/dtpools/dtpoolsconf.h";
    symlink "../../../libtool", "test/mpi/dtpools/libtool";
}
else {
    die "Usage: $0 [mpich]\n";
}

open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\S+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
$hash_defines{"disable-ch4-ofi-ipv6"} = "MPIDI_CH4_OFI_SKIP_IPV6";
$hash_defines{"enable-legacy-ofi"} = "MPIDI_ENABLE_LEGACY_OFI";
$hash_defines{"enable-ch4-am-only"} = "MPIDI_ENABLE_AM_ONLY";
$hash_defines{"with-ch4-max-vcis"} = "MPIDI_CH4_MAX_VCIS";
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
    "default" => "MPICH_VCI__ZERO",
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
    }
    elsif ($a=~/--enable-strict/) {
        $config_cflags{"-Wall"} = 1;
        $config_cflags{"-Wextra"} = 1;
        $config_cflags{"-Wmissing-prototypes"} = 1;
        $config_cflags{"-DGCC_WALL"} = 1;
        $config_cflags{"-Wshadow"} = 1;
        $config_cflags{"-Wmissing-declarations"} = 1;
        $config_cflags{"-Wundef"} = 1;
        $config_cflags{"-Wpointer-arith"} = 1;
        $config_cflags{"-Wbad-function-cast"} = 1;
        $config_cflags{"-Wwrite-strings"} = 1;
        $config_cflags{"-Wnested-externs"} = 1;
        $config_cflags{"-Winvalid-pch"} = 1;
        $config_cflags{"-Wvariadic-macros"} = 1;
        $config_cflags{"-Wtype-limits"} = 1;
        $config_cflags{"-Werror-implicit-function-declaration"} = 1;
        $config_cflags{"-Wstack-usage=262144"} = 1;
        $config_cflags{"-Wno-missing-field-initializers"} = 1;
        $config_cflags{"-Wno-unused-parameter"} = 1;
        $config_cflags{"-Wno-long-long"} = 1;
        $config_cflags{"-Wno-endif-labels"} = 1;
        $config_cflags{"-Wno-sign-compare"} = 1;
        $config_cflags{"-Wno-multichar"} = 1;
        $config_cflags{"-Wno-deprecated-declarations"} = 1;
        $config_cflags{"-Wno-pointer-sign"} = 1;
    }

}
if ($config_defines{MPIDI_CH4_MAX_VCIS} > 1 and !$config_defines{MPIDI_CH4_VCI_METHOD}) {
    $config_defines{MPIDI_CH4_VCI_METHOD} = "MPICH_VCI__COMM";
}
if ($config_defines{MPICH_THREAD_GRANULARITY} =~/VCI|POBJ/) {
    $config_defines{MPICH_THREAD_REFCOUNT} = "MPICH_REFCOUNT__LOCKFREE";
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
    $opts{CXX} = "gcc";
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

    $config_defines{MAX_ALIGNMENT} = 16;
    my $MPI_AINT;
    if ($sizeof_hash{LONG} == $sizeof_hash{LONG_LONG}) {
        $MPI_AINT = "long";
        $config_defines{MPIR_AINT_MAX} = 'LONG_MAX';
        $config_defines{MPIR_COUNT_MAX} = 'LONG_MAX';
        $config_defines{MPIR_OFFSET_MAX} = 'LONG_MAX';
        $config_defines{MPIR_Ucount} = "unsigned long";
    }
    else {
        $MPI_AINT = "long long";
        $config_defines{MPIR_AINT_MAX} = 'LONG_LONG_MAX';
        $config_defines{MPIR_COUNT_MAX} = 'LONG_LONG_MAX';
        $config_defines{MPIR_OFFSET_MAX} = 'LONG_LONG_MAX';
        $config_defines{MPIR_Ucount} = "unsigned long long";
    }
    $config_defines{HAVE_LONG_LONG_INT} = 1;

    get_sizeof_bsend_status($MPI_AINT);

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
$config_defines{USE_SYM_HEAP} = 1;
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
$config_defines{STRERROR_R_CHAR_P} = 1;

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

    $temp{HAVE_ERROR_CHECKING}='MPID_ERROR_LEVEL_ALL';
    $temp{MPICH_ERROR_MSG_LEVEL} = 'MPICH_ERROR_MSG__ALL';
    $temp{MPICH_IS_THREADED} = 1;
    $temp{MPICH_THREAD_GRANULARITY} = 'MPICH_THREAD_GRANULARITY__GLOBAL';
    $temp{MPICH_THREAD_LEVEL} = 'MPI_THREAD_MULTIPLE';
    $temp{MPICH_THREAD_REFCOUNT} = 'MPICH_REFCOUNT__NONE';

    $temp{TRUE} = 1;
    $temp{FALSE} = 0;

    if ($opts{device}=~/ch4/) {
        $temp{MPIDI_BUILD_CH4_LOCALITY_INFO}=1;
        $temp{MPIDI_CH4U_USE_PER_COMM_QUEUE}=1;
        $temp{MPIDI_CH4_MAX_VCIS}=1;
        $temp{MPIDI_CH4_USE_MT_DIRECT}=1;
        $temp{MPIDI_CH4_VCI_METHOD}='MPICH_VCI__ZERO';
        $temp{CH4_RANK_BITS}=32;
        $temp{HAVE_CH4_SHM_EAGER_IQUEUE}=1;

        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_YAKSA';

        if ($opts{device}=~/ch4:ucx/) {
            $temp{MPIDI_CH4_DIRECT_NETMOD}=1;
            $temp{HAVE_CH4_NETMOD_UCX}=1;
            $temp{HAVE_LIBUCP} = 1;
            $temp{HAVE_UCP_PUT_NB}=1;
            $temp{HAVE_UCP_GET_NB}=1;
        }
        elsif ($opts{device}=~/ch4:ofi/) {
            $temp{HAVE_CH4_NETMOD_OFI}=1;
            $temp{MPIDI_OFI_VNI_USE_DOMAIN}=1;
            if ($opts{device}=~/ch4:ofi:(\w+)/) {
                my ($set) = ($1);
                $set = uc($set);
                $temp{"MPIDI_CH4_OFI_USE_SET_$set"}=1;
            }
            else {
                $temp{MPIDI_CH4_OFI_USE_SET_RUNTIME}=1;
            }
            if (0) {
                $temp{MPIDI_CH4_SHM_ENABLE_GPU}=1;
                $make_conds{BUILD_SHM_IPC_GPU} = 1;
            }
        }
    }
    elsif ($opts{device}=~/ch3/) {
        $temp{CH3_RANK_BITS} = 16;
        $temp{MPICH_DATATYPE_ENGINE} = 'MPICH_DATATYPE_ENGINE_DATALOOP';
        $temp{PREFETCH_CELL}=1;
        $temp{USE_FASTBOX}=1;
        if ($opts{device}=~/ch3:sock/) {
        }
        else {
            $temp{MPID_NEM_INLINE}=1;
            $temp{MPID_NEM_LOCAL_LMT_IMPL}="MPID_NEM_LOCAL_LMT_SHM_COPY";
        }
    }

    if (1) {
        $temp{HAVE_F08_BINDING} = 0;
        $temp{HAVE_NO_FORTRAN_MPI_TYPES_IN_C} = 1;
    }

    if ($opts{device} =~ /ch4/) {
        my $eager_modules="iqueue";
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

    $temp{MPIF_STATUS_SIZE} = $sizeof_hash{MPI_STATUS};

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
    $confs{LIBS} = $ENV{LIBS};
    $confs{MPILIBNAME} = "mpi";
    $confs{LPMPILIBNAME} = "";
    $confs{MPICH_VERSION} = $version;
    $confs{CC} = $opts{CC};
    $confs{with_wrapper_dl_type} = "runpath";
    $confs{INTERLIB_DEPS} = "yes";

    $confs{WRAPPER_CFLAGS}="";
    $confs{WRAPPER_CPPFLAGS}="";
    $confs{WRAPPER_LDFLAGS}="";
    $confs{WRAPPER_LIBS} = "";

    if ($opts{CFLAGS}=~/-fsanitize=(address|undefined)/) {
        $confs{WRAPPER_CFLAGS} .= " -fsanitize=$1";
    }

    my $tag="cc";
    my $dtags="enable_dtags_flag=\"\\\$wl--enable-new-dtags\"\n";
    $dtags  .="disable_dtags_flag=\"\\\$wl--disble-new-dtags\"\n";
    open In, "libtool" or die "Can't open libtool: $!\n";
    while(<In>){
        if (/^wl=/) {
            $confs{"${tag}_shlib_conf"} .= $_;
        }
        if (/^hardcode_libdir_flag_spec=/) {
            $confs{"${tag}_shlib_conf"} .= $_;
            $confs{"${tag}_shlib_conf"} .= $dtags;
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

    foreach my $p ("cc", "cxx", "f77", "fort") {
        my $P = uc($p);
        $confs{"MPICH_MPI${P}_CFLAGS"}="";
        $confs{"MPICH_MPI${P}_CPPFLAGS"}="";
        $confs{"MPICH_MPI${P}_LDFLAGS"}="";
        $confs{"MPICH_MPI${P}_LIBS"}="";

        if (-f "src/env/mpi$p.bash.in") {
            my @lines;
            {
                open In, "src/env/mpi$p.bash.in" or die "Can't open src/env/mpi$p.bash.in.\n";
                @lines=<In>;
                close In;
            }
            open Out, ">mymake/mpi$p" or die "Can't write mymake/mpi$p: $!\n";
            print "  --> [mymake/mpi$p]\n";
            foreach my $l (@lines) {
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

    if ($sizeof_hash{VOID_P}==$sizeof_hash{LONG}) {
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

    my $idx = 1;
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
    $confs{MPI_FLOAT_INT} = "0x8c000000";
    $confs{MPI_DOUBLE_INT} = "0x8c000001";
    $confs{MPI_LONG_INT} = "0x8c000002";
    $confs{MPI_SHORT_INT} = "0x8c000003";
    $confs{MPI_LONG_DOUBLE_INT} = "0x8c000004";
    $confs{MPI_2INT} = sprintf("0x4c00%02x16", $sizeof_hash{"2INT"});
    $confs{MPI_SIGNED_CHAR} = sprintf("0x4c00%02x18", $sizeof_hash{"SIGNED_CHAR"});
    $confs{MPI_UNSIGNED_LONG_LONG} = sprintf("0x4c00%02x19", $sizeof_hash{"UNSIGNED_LONG_LONG"});
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
    }

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
    autoconf_file("src/include/mpi.h", \%confs);
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
    $make_conds{BUILD_PROFILING_LIB} = 0;
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
        $make_conds{BUILD_YAKSA_ENGINE} = 1;
        if ($opts{device} =~/ch4:ofi/) {
            $make_conds{BUILD_CH4_NETMOD_OFI} = 1;
        }
        else {
            $opts{enable_shm} = 0;
            $make_conds{BUILD_CH4_NETMOD_UCX} = 1;
            if (0) {
                $make_conds{BUILD_HCOLL} = 1;
            }
        }

        if ($opts{enable_shm}) {
            $make_conds{BUILD_CH4_SHM} = 1;
            $make_conds{BUILD_SHM_POSIX} = 1;
            if (1) {
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

    $make_conds{BUILD_MPID_COMMON_SCHED} = 1;
    $make_conds{BUILD_MPID_COMMON_THREAD} = 1;
    if ($opts{device}=~/ch4/) {
        $make_conds{BUILD_MPID_COMMON_SHM} = 1;
        $make_conds{BUILD_MPID_COMMON_BC} = 1;
        $make_conds{BUILD_MPID_COMMON_GENQ} = 1;
    }
    elsif ($opts{device}=~/ch3:sock/) {
    }
    else {
        $make_conds{BUILD_MPID_COMMON_SHM} = 1;
    }

    if (0) {
        $make_conds{BUILD_ROMIO} = 1;
    }
    if (0) {
        $make_conds{BUILD_CXX_BINDING} = 0;
    }
    if (0) {
        $make_conds{BUILD_F77_BINDING} = 0;
    }
    if (0) {
        $make_conds{BUILD_FC_BINDING} = 0;
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

    open Out, ">mymake/make_opts.mpich" or die "Can't write mymake/make_opts.mpich: $!\n";
    print "  --> [mymake/make_opts.mpich]\n";
    print Out "CC: $opts{CC}\n";
    print Out "CXX: $opts{CXX}\n";
    print Out "F77: $opts{F77}\n";
    print Out "FC: $opts{FC}\n";
    print Out "cc_version: $opts{cc_version}\n";
    my $cflags = "-g -O2";
    my $ldflags = "";
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

    $config_defines{USE_MMAP_SHM} = 1;
    $config_defines{MPL_USE_MMAP_SHM} = 1;
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
    $config_defines{HAVE_BACKTRACE}=1;
    $config_defines{HAVE_BROKEN_VALGRIND}=1;
    $config_defines{HAVE_FDOPEN}=1;
    $config_defines{HAVE_GETIFADDRS}=1;
    $config_defines{HAVE_GETPID}=1;
    $config_defines{HAVE_INET_NTOP}=1;
    $config_defines{HAVE_SLEEP}=1;
    $config_defines{HAVE_USLEEP}=1;

    $config_defines{HAVE_LIBCUDA}=1;
    $config_defines{HAVE_PTHREAD_MUTEXATTR_SETPSHARED} = 1;

    $config_defines{backtrace_size_t} = "int";
    my %confs;
    $confs{MPL_TIMER_TYPE} = "struct timespec";
    $confs{MPL_TIMER_KIND} = "MPL_TIMER_KIND__CLOCK_GETTIME";
    autoconf_file("mymake/mpl/include/mpl_timer.h", \%confs);
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
    $config_defines{ENABLE_PROFILING}=1;

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
    my @launchers=qw(ssh rsh fork slurm ll lsf sge manual persist);
    my @rmks=qw(user slurm ll lsf sge pbs cobalt);
    my @demuxes=qw(poll select);
    my @topolibs=qw(hwloc);
    my %confs;
    $confs{hydra_launcher_array} = ' "'. join('",  "', @launchers). '",  NULL';
    $confs{hydra_rmk_array}      = ' "'. join('",  "', @rmks). '",  NULL';
    $confs{hydra_launcher_init_array} = ' HYDT_bsci_launcher_'. join('_init,  HYDT_bsci_launcher_', @launchers). '_init,  NULL';
    $confs{hydra_rmk_init_array} = ' HYDT_bsci_rmk_'. join('_init,  HYDT_bsci_rmk_', @rmks). '_init,  NULL';
    autoconf_file("src/pm/hydra/tools/bootstrap/src/bsci_init.c", \%confs);

    $config_defines{HYDRA_AVAILABLE_DEMUXES} = "\"@demuxes\"";
    $config_defines{HYDRA_DEFAULT_DEMUX} = "\"$demuxes[0]\"";
    $config_defines{HYDRA_AVAILABLE_LAUNCHERS} = "\"@launchers\"";
    $config_defines{HYDRA_DEFAULT_LAUNCHER} = "\"$launchers[0]\"";
    $config_defines{HYDRA_AVAILABLE_RMKS} = "\"@rmks\"";
    $config_defines{HYDRA_DEFAULT_RMK} = "\"$rmks[0]\"";
    $config_defines{HYDRA_AVAILABLE_TOPOLIBS} = "\"@topolibs\"";
    $config_defines{HYDRA_DEFAULT_TOPOLIB} = "\"$topolibs[0]\"";
}
elsif ($config eq "test") {
    open In, "mymake/make_opts.mpich" or die "Can't open mymake/make_opts.mpich: $!\n";
    while(<In>){
        if (/^(\w+):\s*(.+)/) {
            $opts{$1} = $2;
        }
    }
    close In;
    $config_defines{PACKAGE}='"mpich-testsuite"';
    $config_defines{PACKAGE_BUGREPORT}='"discuss@mpich.org"';
    $config_defines{PACKAGE_NAME}='"mpich-testsuite"';
    $config_defines{PACKAGE_STRING}="\"mpich-testsuite $version\"";
    $config_defines{PACKAGE_TARNAME}='"mpich-testsuite"';
    $config_defines{PACKAGE_URL}='"http://www.mpich.org/"';
    $config_defines{PACKAGE_VERSION}="\"$version\"";
    $config_defines{VERSION}="\"$version\"";
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
    $config_defines{HAVE_GETRUSAGE} = 1;

    $config_defines{THREAD_PACKAGE_NAME} = "THREAD_PACKAGE_POSIX";
    $config_defines{HAVE_MPI_WIN_CREATE} = 1;
    if ($opts{device}!~/ch4:ucx/) {
        $config_defines{HAVE_MPI_SPAWN} = 1;
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
my @lines;
open In, "$config_in" or die "Can't open $config_in: $!\n";
while(<In>){
    if (/^#undef\s+(\w+)/) {
        my ($a) = ($1);
        if ($config eq "mpl") {
            my $b = "MPL_$a";
            if ($a=~/^(_|MPL_|const|inline|restrict)/) {
                $b = $a;
            }
            elsif ($a=~/^[a-z]/) {
                $b = "_mpl_$a";
            }

            my $val = $config_defines{$a};
            if (defined $config_defines{"MPL_$a"}) {
                $val = $config_defines{"MPL_$a"};
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
if ($config eq "mpl") {
    print Out "#ifndef INCLUDE_MPLCONFIG_H\n";
    print Out "#define INCLUDE_MPLCONFIG_H 1\n";
}

foreach my $l (@lines) {
    print Out $l;
}

if ($config eq "mpl") {
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
    open Out, ">mymake/t.c" or die "Can't write mymake/t.c: $!\n";
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

    my $t = `$opts{CC} mymake/t.c -o mymake/t.out 2>/dev/null && mymake/t.out`;
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

sub get_sizeof_bsend_status {
    my ($MPI_AINT) = @_;
    open Out, ">mymake/t.c" or die "Can't write mymake/t.c: $!\n";
    print Out "#define MPI_Datatype int\n";
    print Out "struct MPIR_Request;typedef struct MPIR_Request MPIR_Request;\n";
    print Out "struct MPIR_Comm;typedef struct MPIR_Comm MPIR_Comm;\n";
    print Out "typedef $MPI_AINT MPI_Aint;\n";
    print Out "#include <stdio.h>\n";
    print Out "#include <stdlib.h>\n";
    print Out "#include <stdint.h>\n";
    print Out "#include \"$pwd/src/include/mpir_bsend.h\"\n";
    print Out "typedef struct {int lo; int hi; int src; int tag; int err;} MPI_Status;";
    print Out "int main() {\n";
    print Out "    printf(\"MPII_BSEND_DATA_T: %lu\\n\", sizeof(MPII_Bsend_data_t));\n";
    print Out "    printf(\"MPI_STATUS: %lu\\n\", sizeof(MPI_Status));\n";
    print Out "    return 0;\n";
    print Out "}\n";
    close Out;

    my $t = `$opts{CC} mymake/t.c -o mymake/t.out && mymake/t.out`;
    if ($? == 0) {
        while ($t=~/(\w+):\s+(\d+)/g) {
            $sizeof_hash{$1} = $2;
        }
        return 1;
    }
    else {
        return 0;
    }
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

    $type =~ tr/\* \/./p_/;
    return uc($type);
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

