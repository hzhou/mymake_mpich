export MODDIR=$PWD/modules
mkdir -p $MODDIR
pushd $MODDIR
tar xf $mymake_dir/modules.tar.gz
popd
set -x
set -e
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
perl $mymake_dir/mymake.pl --prefix=$PREFIX $mpich_config 2>&1 || exit 1
make -j$N_MAKE_JOBS  2>&1 | tee -a make.log
if test "$?" != "0"; then
    exit $?
fi
make install 2>&1 || exit 1
make -j$N_MAKE_JOBS hydra 2>&1 | tee -a make.log
if test "$?" != "0"; then
    exit $?
fi
make hydra-install 2>&1 || exit 1
if test x$skip_test = x1 ; then
    exit 0
else
    export PATH=$PREFIX/bin:$PATH
    export CPATH=$PREFIX/include:$CPATH
    export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
    make test 2>&1 || exit 1
fi
