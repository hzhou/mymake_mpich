hostname
date
uptime
pgrep mpiexec | wc -l
if test -e /etc/redhat-release ; then
    export MODULEPATH="/nfs/gce/software/spack/share/spack/lmod/linux-centos7-x86_64/Core:/nfs/gce/software/custom/linux-centos7-x86_64/modulefiles"
    source /nfs/gce/software/spack/opt/spack/linux-centos7-x86_64/gcc-4.8.5/lmod-7.8-wch6ykd/lmod/lmod/init/bash
fi
if test -d $HOME/software/autotools/bin; then
    export PATH=$HOME/software/autotools/bin:$PATH
fi
if test -n $compiler ; then
    case "$compiler" in
        "gcc|gnu")
            CC=gcc
            CXX=g++
            F77=gfortran
            FC=gfortran
            ;;
        "clang")
            CC=clang
            CXX=clang++
            F77=gfortran
            FC=gfortran
            ;;
        "intel")
            module load intel-parallel-studio
            CC=icc
            CXX=icpc
            F77=ifort
            FC=ifort
            ;;
    esac
fi
which autoconf
autoconf --version
which automake
automake --version
which libtool
libtool --version
export CC
which $CC
$CC --version
export CXX
which $CXX
$CXX --version
export F77
which $F77
$F77 --version
export FC
which $FC
$FC --version
WORKSPACE=$PWD
SRC=$PWD
PREFIX=$WORKSPACE/_inst
MPIEXEC=$PREFIX/bin/mpiexec
set -o pipefail
git submodule update --init --recursive
sh autogen.sh 2>&1 || exit 1
./configure --prefix=$PREFIX $mpich_config 2>&1 || exit 1
make -j$N_MAKE_JOBS  2>&1 | tee -a make.log
if test "$?" != "0"; then
    exit $?
fi
make install 2>&1 || exit 1
$MPIEXEC -n 2 examples/cpi 2>&1 || exit 1
if test x$skip_test = x1 ; then
    exit 0
else
    export PATH=$PREFIX/bin:$PATH
    export CPATH=$PREFIX/include:$CPATH
    export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
    cd test/mpi
    make testing
fi
