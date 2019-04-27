#!/usr/bin/env zsh
#
# (C) 2015 by Argonne National Laboratory.
#     See COPYRIGHT in top-level directory.
#

set -x
set -e
hostname
date
uptime
pgrep mpiexec | wc -l

WORKSPACE=""
compiler="gnu"
jenkins_configure="default"
queue="ib64"
netmod="default"
ofi_prov="sockets"
N_MAKE_JOBS=8
GIT_BRANCH=""
BUILD_MODE="per-commit"
BUILD_TYPE=""
INSTALL_PREFIX=""
EXTRA_CONFIG=""
MPIEXEC=""

#####################################################################
## Initialization
#####################################################################

echo "For manual testing, run the script with the following options"
echo "./test-worker.sh $@"

while getopts ":h:c:o:t:q:m:n:b:p:x:E:" opt; do
    case "$opt" in
        h)
            WORKSPACE=$OPTARG ;;
        c)
            compiler=$OPTARG ;;
        o)
            jenkins_configure=$OPTARG ;;
        t)
            thread_cs=$OPTARG ;;
        q)
            queue=$OPTARG ;;
        m)
            _netmod=${OPTARG%%,*}
            _netdev=${_netmod##*:}
            if test "$_netmod" != "$OPTARG" -a "$_netdev" = "ofi"; then
                netmod=$_netmod
                ofi_prov=${OPTARG/$_netmod,}
            else
                netmod=$_netmod
            fi
            ;;
        n)
            N_MAKE_JOBS=$OPTARG ;;
        b)
            GIT_BRANCH=$OPTARG ;;
        p)
            INSTALL_PREFIX=$OPTARG ;;
        x)
            BUILD_TYPE=$OPTARG ;;
        E)
            EXTRA_CONFIG=$OPTARG ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
    esac
done

#####################################################################
## Functions
#####################################################################

CollectResults() {
    if [[ -z "$SLURM_SUBMIT_HOST" ]]; then
        return
    fi

    pushd "$WORKSPACE"
    # if [[ "$BUILD_MODE" != "per-commit" ]]; then
        # find . \
            # \( -name "filtered-make.txt" \
            # -o -name "apply-xfail.sh" \
            # -o -name "autogen.log" \
            # -o -name "config.log" \
            # -o -name "c.txt" \
            # -o -name "m.txt" \
            # -o -name "mi.txt" \
            # -o -name "summary.junit.xml" \) \
            # | while read -r line; do echo "$SLURM_SUBMIT_DIR/$DIRNAME"; done \
            # | xargs ssh $SLURM_SUBMIT_HOST "mkdir -p"
    # fi

    find . \
        \( -name "filtered-make.txt" -o \
        -name "apply-xfail.sh" -o \
        -name "autogen.log" -o \
        -name "config.log" -o \
        -name "c.txt" -o \
        -name "m.txt" -o \
        -name "mi.txt" -o \
        -name "summary.junit.xml" \) \
        -exec ssh $SLURM_SUBMIT_HOST "mkdir -p $SLURM_SUBMIT_DIR/$(dirname {})" \;

    find . \
        \( -name "filtered-make.txt" -o \
        -name "apply-xfail.sh" -o \
        -name "autogen.log" -o \
        -name "config.log" -o \
        -name "c.txt" -o \
        -name "m.txt" -o \
        -name "mi.txt" -o \
        -name "summary.junit.xml" \) \
        -exec scp {} $SLURM_SUBMIT_HOST:$SLURM_SUBMIT_DIR/{} \;
    popd
}

#####################################################################
## Logic to generate random configure options
#####################################################################
RandArgs() {
    # Chosen *without* replacement.  If an option is chosen twice,
    # then there will be fewer options
    n_choice=$1
    array=(${(P)${2}})
    optname=$3
    negoptname=$4
    chosen=()
    args=""
    ret_args=""
    array_len=$#array
    idx=0

    for i in `seq $array_len`; do
        chosen[$i]=0
    done

    for i in `seq $n_choice`; do
        let idx=$[RANDOM % $array_len]+1
        if [ $chosen[$idx] -eq 1 ]; then continue; fi
        chosen[$idx]=1
        args=("${(s/;/)array[$idx]}")
        name=$args[1]
        if [ $#args -eq 1 ]; then
            # Only the name is provided.  Choose one of three
            # choices:
            #    No option (skip this one)
            #    just --$optname-$name
            #    just --$negoptname-$name
            let idx=$[RANDOM % 3]+1
            if [ $idx -eq 1 ]; then
                ret_args="$ret_args --$optname-$name"
            elif [ $idx -eq 2 ]; then
                ret_args="$ret_args --$negoptname-$name"
            fi
        else
            let idx=$[RANDOM % ($#args-1)]+2
            # Special cases
            if [ "$args[$idx]" = "ch3:sock" ]; then
                ret_args="$ret_args --disable-ft-tests --disable-comm-overlap-tests"
            elif [ "$args[$idx]" = "gforker" ]; then
                if [ $chosen[4] -eq 1 ]; then
                    continue
                else
                    ret_args="$ret_args --with-namepublisher=file"
                    chosen[4]=1
                fi
            elif [ "$name" = "namepublisher" -a "$args[$idx]" = "no" ]; then
                if [ $chosen[3] -eq 1 ]; then
                    continue
                fi
            elif [ "$args[$idx]" = "ndebug" -a "$CC" = "suncc" -a "$label" = "ubuntu32" ]; then
                # On ubuntu32, suncc has a bug whose workaround is to add -O flag (ticket #2105)
                CFLAGS="-O1"
                export CFLAGS
            fi
            ret_args="$ret_args --$optname-$name=$args[$idx]"
        fi
    done
    echo $ret_args
}

RandConfig() {
    # WARNING: If moving anything in the two following arrays, check the indices in "Special cases" above
    enable_array=(
        'error-checking;no;runtime;all'
        'error-messages;all;generic;class;none'
        'timer-type;linux86_cycle;clock_gettime;gettimeofday'
        'timing;none;all;runtime;log;log_detailed'
        'g;none;all;handle;dbg;log;meminit;handlealloc;instr;mem;mutex;mutexnesting'
        'fast;O0;O1;O2;O3;ndebug;all;yes;none'
        'fortran'
        'cxx'
        'romio'
        'check-compiler-flags'
        'strict;c99;posix'
        'debuginfo'
        'weak-symbols;no;yes'
        'threads;single;multiple;runtime'
        'thread-cs;global'
        'refcount;lock-free;none'
        'mutex-timing'
        'handle-allocation;tls;mutex'
        'multi-aliases'
        'predefined-refcount'
        'alloca'
        'yield;sched_yield;select'
        'runtimevalues'
    )
    with_array=(
        'logging;none'
        'pmi;simple'
        'pm;gforker'
        'namepublisher;no;file'
        'device;ch3;ch3:sock'
        'shared-memory;sysv'
    )
    let n_enable=$#enable_array+1
    let n_with=$#with_array+1
    enable_args=$(RandArgs $n_enable "enable_array" "enable" "disable")
    with_args=$(RandArgs $n_with "with_array" "with" "without")
    echo "$enable_args $with_args"
}

PrepareEnv() {
    case "$queue" in
        "ubuntu32")
            source /software/common/adm/etc/softenv-aliases.sh
            source /software/common/adm/etc/softenv-load.sh
            ;;
        "ib64")
            source /software/common/adm/etc/softenv-aliases.sh
            source /software/common/adm/etc/softenv-load.sh
            . /home/autotest/software/mellanox.new/hpcx-init.sh
            hpcx_load
            MXM_LOG_LEVEL=error
            export MXM_LOG_LEVEL
            UCX_LOG_LEVEL=error
            export UCX_LOG_LEVEL
            ;;
        "freebsd64")
            export LDFLAGS="-L/usr/local/lib/gcc48 -Wl,-rpath=/usr/local/lib/gcc48"
            alias sed='gsed'
            ;;
        "freebsd32")
            export LDFLAGS="-L/usr/local/lib/gcc48 -Wl,-rpath=/usr/local/lib/gcc48"
            alias sed='gsed'
            ;;
        "solaris")
            PATH=/usr/gnu/bin:$PATH
            ;;
	"osx")
	    PATH=/usr/local/bin:$PATH
	    ;;
    esac
    # redhat nodes use modules instead of softenv
    if test -e /etc/redhat-release ; then
	export MODULEPATH="/nfs/gce/software/spack/share/spack/lmod/linux-centos7-x86_64/Core:/nfs/gce/software/custom/linux-centos7-x86_64/modulefiles"
	source /nfs/gce/software/spack/opt/spack/linux-centos7-x86_64/gcc-4.8.5/lmod-7.8-wch6ykd/lmod/lmod/init/bash
    fi
    PATH=$HOME/software/autotools/bin:$PATH
    export PATH
    echo "$PATH"
}

SetCompiler() {
    case "$compiler" in
        "gnu")
            case "$queue" in
                "osx")
		    CC=gcc-7
		    CXX=g++-7
		    F77=gfortran-7
		    FC=gfortran-7
                    ;;
		*)
		    CC=gcc
		    CXX=g++
		    F77=gfortran
		    FC=gfortran
                    ;;
            esac
            ;;
        "clang")
            CC=clang
            CXX=clang++
            F77=gfortran
            FC=gfortran
            ;;
        "intel")
            if test -e /etc/redhat-release ; then
                module load intel-parallel-studio
            fi
            CC=icc
            CXX=icpc
            F77=ifort
            FC=ifort
            ;;
        "pgi")
            if test -e /etc/redhat-release ; then
                module load pgi
            else
                soft add +pgi
            fi
            CC=pgcc
            CXX=pgc++
            F77=pgf77
            FC=pgfortran
            ;;
        "absoft")
            if test -e /etc/redhat-release ; then
                module load absoft
            else
                soft add +absoft
            fi
            CC=gcc
            CXX=g++
            F77=af77
            FC=af90
            ;;
        "nag")
            if test -e /etc/redhat-release ; then
                module load nag
            else
                soft add +nagfor
            fi
            CC=gcc
            CXX=g++
            F77=nagfor
            FC=nagfor
            FFLAGS="-mismatch"
            FCFLAGS="-mismatch"
            export FFLAGS
            export FCFLAGS
            ;;
        "solstudio")
            case "$queue" in
                "ubuntu32" | "ib64" )
                    soft add +solarisstudio-12.4
                    ;;
                "solaris")
                    export PATH=/opt/developerstudio12.5/bin:$PATH
                    ;;
            esac
            if test -e /etc/redhat-release ; then
                module load solarisstudio
            fi
            CC=suncc
            CXX=sunCC
            F77=sunf77
            FC=sunf90
            ;;
        *)
            echo "Unknown compiler suite"
            exit 1
    esac

    export CC
    export CXX
    export F77
    export FC

    which $CC
    which $CXX
    which $F77
    which $FC
}

SetNetmod() {
    netmod_opt="__NULL__"
    case "$netmod" in
        "default") # for solaris, may use with sock
            netmod_opt=
            ;;
        "ch3:mxm")
            netmod_opt="--with-device=ch3:nemesis:mxm --with-mxm=$HOME/software/mellanox.new/mxm --disable-spawn --disable-ft-tests"
            ;;
        "ch3:ofi")
            if test "$queue" = "ubuntu32" ; then
                netmod_opt="--with-device=ch3:nemesis:ofi --with-ofi=$HOME/software/x86/libfabric/$ofi_prov --disable-spawn --disable-ft-tests LD_LIBRARY_PATH=$HOME/software/libfabric/lib"
            else
                netmod_opt="--with-device=ch3:nemesis:ofi --with-ofi=$HOME/software/libfabric/$ofi_prov --disable-spawn --disable-ft-tests LD_LIBRARY_PATH=$HOME/software/libfabric/lib"
            fi
            ;;
        "ch4:ofi")
            netmod_opt="--with-device=ch4:ofi --disable-ft-tests"
            if test "$jenkins_configure" = "embedded" ; then
                netmod_opt="--with-device=ch4:ofi:sockets --with-libfabric=embedded --disable-ft-tests"
            else
                if test "$queue" = "ubuntu32" ; then
                    netmod_opt="$netmod_opt --with-libfabric=$HOME/software/x86/libfabric/$ofi_prov"
                else
                    netmod_opt="$netmod_opt --with-libfabric=$HOME/software/libfabric/$ofi_prov"
                fi
            fi
            ;;
        "ch4:ucx")
            netmod_opt="--with-device=ch4:ucx --disable-ft-tests --disable-spawn"
            if test "$jenkins_configure" = "embedded" ; then
                netmod_opt="$netmod_opt --with-ucx=embedded"
            else
                netmod_opt="$netmod_opt --with-ucx=$HOME/software/ucx"
            fi
            ;;
        "ch4:portals4")
            netmod_opt="--with-device=ch4:portals4 --with-portals4=$HOME/software/portals4 --disable-ft-tests --disable-spawn"
            ;;
        "ch3:portals4")
            netmod_opt="--with-device=ch3:nemesis:portals4 --with-portals4=$HOME/software/portals4 --disable-spawn --disable-ft-tests"
            ;;
        "ch3:sock")
            netmod_opt="--with-device=ch3:sock --disable-ft-tests --disable-comm-overlap-tests"
            ;;
        "ch3:tcp")
            netmod_opt=
            ;;
        *)
            echo "Unknown netmod type"
            exit 1
    esac
    export netmod_opt
    echo "$netmod_opt"
}

SetConfigOpt() {
    config_opt="__TO_BE_FILLED__"
    case "$jenkins_configure" in
        "default")
            config_opt=
            ;;
        "strict")
            config_opt="--enable-strict"
            ;;
        "fast")
            config_opt="--enable-fast=all"
            ;;
        "nofast")
            config_opt="--disable-fast"
            ;;
        "noshared")
            config_opt="--disable-shared"
            ;;
        "debug")
            config_opt="--enable-g=all"
            ;;
        "noweak")
            config_opt="--disable-weak-symbols"
            ;;
        "strictnoweak")
            config_opt="--enable-strict --disable-weak-symbols"
            ;;
        "nofortran")
            config_opt="--disable-fortran"
            ;;
        "nocxx")
            config_opt="--disable-cxx"
            ;;
        "am-only")
            if test "$netmod" = "ch4:ucx" ; then
                config_opt="--with-ch4-netmod-ucx-args=am-only"
            elif test "$netmod" = "ch4:ofi" ; then
                config_opt="--disable-spawn --enable-legacy-ofi"
            else
		config_opt=""
            fi
            ;;
        "multithread")
            config_opt="--enable-threads=multiple"
            ;;
        "singlethread")
            config_opt="--enable-threads=single --with-thread-package=none"
            ;;
        "debuginfo")
            config_opt="--enable-debuginfo"
            ;;
        "noerrorchecking")
            config_opt="--disable-error-checking"
            if test "$compiler" = "gnu" && "$queue" = "osx" ; then # when it is running on OSX
                config_opt="$config_opt --enable-fast=O1"
            fi
            ;;
        "sock") # for solaris + sock
            config_opt="--with-device=ch3:sock --disable-ft-tests --disable-comm-overlap-tests"
            ;;
        "mpd")
            config_opt="--with-pm=mpd --with-namepublisher=file"
            ;;
        "gforker")
            config_opt="--with-pm=gforker --with-namepublisher=file"
            ;;
        "shmem")
            config_opt=
            ;;
        "async")
            config_opt=
            ;;
        "random")
            config_opt=$(RandArgs)
            ;;
        "valgrind")
            config_opt="--disable-hwloc-prefix --disable-hydra-topolib --enable-g=meminit --disable-ft-tests --disable-dtpools"
            ;;
        "hcoll")
            config_opt="--with-hcoll=$HOME/software/mellanox.new/hcoll"
            ;;
        "uti")
            config_opt="--with-thread-package=uti --with-uti=$HOME/software/uti"
	    ;;
        "solaristhreads")
            config_opt="--with-thread-package=solaris"
	    ;;
        "argobots")
            config_opt="--with-thread-package=argobots --with-argobots=$HOME/software/argobots"
            ;;
        "embedded") # testing CH4 with embedded netmod and default configuration
            config_opt=
            ;;
        "pmix")
            config_opt="--with-pmix=$HOME/software/pmix-2.1.1 --disable-spawn"
            ;;
        "pmi2")
            config_opt="--with-pmi=pmi2/simple --disable-spawn"
            ;;
        "no-inline")
            config_opt="--enable-ch4-netmod-inline=no --enable-ch4-shm-inline=no"
            ;;
        "direct-nm")
            config_opt="--enable-ch4-direct=netmod"
            ;;
        "direct-auto")
            config_opt="--enable-ch4-direct=auto"
            ;;
        "atomic") # only env var before running test, needed for ucx workaround
            config_opt=
            ;;
        *)
            echo "Bad configure option: $jenkins_configure"
            exit 1
    esac

    case "$thread_cs" in
	"global")
	    ;;
	"per-endpoint")
	    config_opt="$config_opt --enable-thread-cs=per-endpoint"
	    ;;
	*)
	    ;;
    esac

    if test "$BUILD_TYPE" = ""; then
        if test "$jenkins_configure" != "shmem" -a "$jenkins_configure" != "hcoll"; then
            config_opt="$config_opt --enable-nemesis-dbg-localoddeven"
        fi
    fi

    if test "$queue" = "osx" -a "$FC" = "ifort"; then
        config_opt="$config_opt lv_cv_ld_force_load=no"
    fi

    if test "$FC" = "ifort" -a "$jenkins_configure" != "nofortran" ; then
        config_opt="$config_opt --enable-fortran=f77,f90,f08,fc"
    fi

    if test -n "$EXTRA_CONFIG" ; then
        config_opt="$config_opt $EXTRA_CONFIG"
    fi

    if test "$jenkins_configure" != "valgrind"; then
        config_opt="$config_opt --enable-large-tests --enable-collalgo-tests"
    fi

    export config_opt
    echo "$config_opt"
}

#####################################################################
## Main() { Setup Environment and Build
#####################################################################
cd $WORKSPACE

if test "$GIT_BRANCH" = "" ; then
    BUILD_MODE="nightly"
elif test "$GIT_BRANCH" = "stable" ; then
    BUILD_MODE="stable"
fi

case "$BUILD_MODE" in
    "nightly")
        if [[ -x $WORKSPACE/jenkins-scripts/skip_test.sh ]]; then
            $WORKSPACE/jenkins-scripts/skip_test.sh -j $JOB_NAME -c $compiler -o $jenkins_configure -q $queue -m $netmod \
                -s $WORKSPACE/mpich-master/test/mpi/summary.junit.xml
            if [[ -f $WORKSPACE/mpich-master/test/mpi/summary.junit.xml ]]; then
                CollectResults
                exit 0
            fi
        fi
        ;;
    "stable")
        if [[ -x $WORKSPACE/jenkins-scripts/skip_test.sh ]]; then
            $WORKSPACE/jenkins-scripts/skip_test.sh -j $JOB_NAME -c $compiler -o $jenkins_configure -q $queue -m $netmod \
                -s $WORKSPACE/mpich-stable/test/mpi/summary.junit.xml
            if [[ -f $WORKSPACE/mpich-stable/test/mpi/summary.junit.xml ]]; then
                CollectResults
                exit 0
            fi
        fi
        ;;
    "per-commit")
        if [[ -x $WORKSPACE/jenkins-scripts/skip_test.sh ]]; then
            $WORKSPACE/jenkins-scripts/skip_test.sh -j $JOB_NAME -c $compiler -o $jenkins_configure -q $queue -m $netmod \
                -s $WORKSPACE/test/mpi/summary.junit.xml
            if [[ -f $WORKSPACE/test/mpi/summary.junit.xml ]]; then
                CollectResults
                exit 0
            fi
        fi
        ;;
esac

SRC=$WORKSPACE

# Preparing the source
case "$BUILD_MODE" in
    "nightly")
        tar zxvf mpich-master.tar.gz
        SRC="$WORKSPACE/mpich-master"
        ;;
    "stable")
        tar zxvf mpich-stable.tar.gz
        SRC="$WORKSPACE/mpich-stable"
        ;;
    "per-commit")
        ;;
    *)
        echo "Invalid BUILD_MODE $BUILD_MODE. Set by mistake?"
        exit 1
esac

# determine if this is a nightly job or a per-commit job
PrepareEnv

SetCompiler "$compiler"

pushd "$SRC"

if test "$BUILD_MODE" = "per-commit" ; then
    if test -f "$WORKSPACE/.gitmodules" ; then
        git submodule update --init --recursive
    fi
    ./autogen.sh 2>&1 | tee autogen.log
fi

if test "$INSTALL_PREFIX" = "" ; then
    INSTALL_PREFIX=$SRC/_inst
fi

if test "$jenkins_configure" = "pmix" ; then
    MPIEXEC="$HOME/software/openmpi-3.0.0/bin/mpiexec -oversubscribe"
elif test "$MPIEXEC" = "" ; then
    MPIEXEC=$INSTALL_PREFIX/bin/mpiexec
fi
export MPIEXEC

./configure --prefix=$INSTALL_PREFIX $(SetNetmod $netmod) $(SetConfigOpt $jenkins_configure) \
    --disable-perftest \
    2>&1 | tee c.txt
if test "${pipestatus[-2]}" != "0"; then
    CollectResults
    exit 1
fi

if [[ -x $SRC/test/mpi/maint/jenkins/set-xfail.sh ]]; then
    $SRC/test/mpi/maint/jenkins/set-xfail.sh -j $JOB_NAME -c $compiler -o $jenkins_configure -q $queue -m $netmod \
        -f $SRC/test/mpi/maint/jenkins/xfail.conf
fi

make -j$N_MAKE_JOBS 2>&1 | tee m.txt
if test "${pipestatus[-2]}" != "0"; then
    CollectResults
    exit 1
fi
make -j$N_MAKE_JOBS install 2>&1 | tee mi.txt
if test "${pipestatus[-2]}" != "0"; then
    CollectResults
    exit 1
fi
cat m.txt mi.txt | ./maint/clmake > filtered-make.txt 2>&1

# We do not execute the test suite for the benchmark build.
if test "$BUILD_TYPE" = "benchmark"; then
    CollectResults
    popd
    exit 0
fi

#####################################################################
## Run tests
#####################################################################

# Preparation
case "$jenkins_configure" in
    "mpd")
        $INSTALL_PREFIX/bin/mpd &
        sleep 1
        ;;
    "async" | "uti")
        MPIR_CVAR_ASYNC_PROGRESS=1
        export MPIR_CVAR_ASYNC_PROGRESS
        ;;
    "multithread")
        MPIR_CVAR_DEFAULT_THREAD_LEVEL=MPI_THREAD_MULTIPLE
        export MPIR_CVAR_DEFAULT_THREAD_LEVEL
        ;;
    "valgrind")
        # run valgrind check, only show error messages
        MPITEST_PROGRAM_WRAPPER="valgrind -q --track-origins=yes --leak-check=full --suppressions=$WORKSPACE/jenkins-scripts/valgrind_suppressions"
        export MPITEST_PROGRAM_WRAPPER
        # increase timeout for all tests
        MPITEST_TIMEOUT_MULTIPLIER=6
        export MPITEST_TIMEOUT_MULTIPLIER
        ulimit -n 2048
	# run limited set of DTPools configurations
        DTP_NUM_OBJS=1
        DTP_RUNTIME_TYPES="MPI_INT MPI_DOUBLE"
        export DTP_NUM_OBJS
        export DTP_RUNTIME_TYPES
        ;;
    "hcoll")
        MPIR_CVAR_CH3_ENABLE_HCOLL=1
        export MPIR_CVAR_CH3_ENABLE_HCOLL
	HCOLL_ENABLE=1
	export HCOLL_ENABLE
	MPIR_CVAR_ENABLE_HCOLL=1
	export MPIR_CVAR_ENABLE_HOLL
        HCOLL_SBGP=p2p
        export HCOLL_SBGP
        LD_LIBRARY_PATH=$HOME/software/mellanox.new/hcoll/lib:$HOME/software/mellanox.new/mxm/lib:$LD_LIBRARY_PATH
        export LD_LIBRARY_PATH
        HYDRA_BINDING=core
        export HYDRA_BINDING
        MPIR_CVAR_NOLOCAL=1
        export MPIR_CVAR_NOLOCAL
        ;;
    "atomic")
        MPIR_CVAR_CH4_UCX_ENABLE_AMO64=1
        export MPIR_CVAR_CH4_UCX_ENABLE_AMO64
        ;;
esac

case "$netmod" in
    "ch3:mxm")
        MXM_LOG_LEVEL=error
        export MXM_LOG_LEVEL
        ;;
    "ch3:ofi")
        MXM_LOG_LEVEL=error
        export MXM_LOG_LEVEL
        MPIR_CVAR_OFI_USE_PROVIDER="sockets"
        export MPIR_CVAR_OFI_USE_PROVIDER
        FI_PROVIDER="sockets"
        export FI_PROVIDER
        ;;
    "ch3:portals4")
        MXM_LOG_LEVEL=error
        export MXM_LOG_LEVEL
        ;;
    "ch4:ofi")
        MPIR_CVAR_OFI_USE_PROVIDER="sockets"
        export MPIR_CVAR_OFI_USE_PROVIDER
        ;;
    "ch4:ucx")
        UCX_LOG_LEVEL=error
        export UCX_LOG_LEVEL
        UCX_MAX_BCOPY=4096
        export UCX_MAX_BCOPY
        UCX_TLS=rc,mm,self
        export UCX_TLS
        ;;
esac

case "$queue" in
    "solaris")
        HWLOC_HIDE_ERRORS=1
        export HWLOC_HIDE_ERRORS
        ;;
esac

# force odd even cliques since the config option does not cover all builds
if test "$jenkins_configure" != "shmem" -a "$jenkins_configure" != "hcoll"; then
    MPIR_CVAR_ODD_EVEN_CLIQUES=1
    export MPIR_CVAR_ODD_EVEN_CLIQUES
fi

if test "$jenkins_configure" = "am-only" ; then
    MPIR_CVAR_CH4_OFI_ENABLE_TAGGED=0
    export MPIR_CVAR_CH4_OFI_ENABLE_TAGGED
    MPIR_CVAR_CH4_OFI_ENABLE_RMA=0
    export MPIR_CVAR_CH4_OFI_ENABLE_RMA
fi

if test "$thread_cs" != "" ; then
   MPIR_CVAR_CH4_OFI_ENABLE_STX_RMA=0
   export MPIR_CVAR_CH4_OFI_ENABLE_STX_RMA
fi

# set LD_LIBRARY_PATH for safety from other MPI libraries (e.g. Intel MPI)
LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

# check to see if cpi works before we kickoff the testsuite
eval $MPIEXEC -n 2 $SRC/examples/cpi

# Preparing the source
if test -f "$SRC/test/mpi/basictypelist.txt"; then
    case "$BUILD_MODE" in
        "nightly")
            DTP_NUM_OBJS=5
            DTP_RUNTIME_TYPES="MPI_INT MPI_DOUBLE"
            export DTP_NUM_OBJS
            export DTP_RUNTIME_TYPES
            ;;
        "stable")
            # Run the full pool size
            DTP_NUM_OBJS=-1
            export DTP_NUM_OBJS
            ;;
        "per-commit")
            DTP_NUM_OBJS=5
            DTP_RUNTIME_TYPES="MPI_INT MPI_DOUBLE"
            export DTP_NUM_OBJS
            export DTP_RUNTIME_TYPES
            MPITEST_TIMEOUT_MULTIPLIER=2
            export MPITEST_TIMEOUT_MULTIPLIER
            ;;
        *)
            echo "Invalid BUILD_MODE $BUILD_MODE. Set by mistake?"
            exit 1
    esac
fi

if test "$jenkins_configure" != "hcoll" ; then
    make testing
fi

# Cleanup
case "$jenkins_configure" in
    "mpd")
        $INSTALL_PREFIX/bin/mpdallexit
        ;;
    "async")
        unset MPIR_CVAR_ASYNC_PROGRESS
        ;;
esac

#####################################################################
## Copy Test results and Cleanup
#####################################################################

if test "$jenkins_configure" != "hcoll" ; then
   CollectResults
fi

popd
exit 0

