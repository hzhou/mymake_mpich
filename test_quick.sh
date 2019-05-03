hostname
date
uptime
pgrep mpiexec | wc -l
if test x$jenkins = xold ; then
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
else
    export PATH=/nfs/gce/software/spack/bin:$PATH
    export MODULEPATH="/nfs/gce/software/spack/share/spack/lmod/linux-centos7-x86_64/Core:/nfs/gce/software/custom/linux-centos7-x86_64/modulefiles"
fi
if test -d $HOME/software/autotools/bin; then
    export PATH=$HOME/software/autotools/bin:$PATH
fi
if test -n $compiler ; then
    if test x$jenkins = xold ; then
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
        if test $queue eq "ubuntu32" -a $compiler eq "solstudio" ; then
            CFLAGS="-O1"
        fi
    else
        case $compiler in
            gcc|gnu)
                CC=gcc
                CXX=g++
                F77=gfortran
                FC=gfortran
                ;;
            clang)
                CC=clang
                CXX=clang++
                F77=gfortran
                FC=gfortran
                ;;
            intel)
                intel=/nfs/gce/software/spack/opt/spack/linux-centos7-x86_64/gcc-4.8.5/intel-parallel-studio-professional.2019.1-vqb6is2
                export PATH=$intel/bin:$PATH
                CC=icc
                CXX=icpc
                F77=ifort
                FC=ifort
                ;;
            *)
                echo "Unknown compiler suite"
                exit 1
        esac
    fi
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
export MODDIR=$PWD/modules
mkdir -p $MODDIR
pushd $MODDIR
tar xf $mymake_dir/modules.tar.gz
pushd ucx
find . -name '*.la' |xargs -t sed -i "s,/var/lib/jenkins-slave/workspace/hzhou-modules,$MODDIR,g"
popd
popd
perl $mymake_dir/mymake.pl --prefix=$PREFIX $mpich_config 2>&1 || exit 1
ls -lt
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
if test x$skip_test = xtrue ; then
    exit 0
else
    export PATH=$PREFIX/bin:$PATH
    export CPATH=$PREFIX/include:$CPATH
    export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
    make test 2>&1 || exit 1
fi
