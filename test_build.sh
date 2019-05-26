set -x
hostname
date
uptime
pgrep mpiexec | wc -l
if test x$jenkins = xold ; then
    if test -d $HOME/software/autotools/bin; then
        export PATH=$HOME/software/autotools/bin:$PATH
    fi
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
    PMRS=/nfs/gce/projects/login-pmrs
    if test -d $HOME/software/autotools/bin; then
        export PATH=$HOME/software/autotools/bin:$PATH
    fi
    export UCX_NET_DEVICES=mlx5_0:1
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
            gnu|gcc|gcc-4)
                CC=gcc
                CXX=g++
                F77=gfortran
                FC=gfortran
                ;;
            clang|clang-3)
                CC=clang
                CXX=clang++
                F77=gfortran
                FC=gfortran
                ;;
            gcc-*)
                VER=${compiler:4}
                export PATH=$PMRS/opt/$compiler/bin:$PATH
                export LD_LIBRARY_PATH=$PMRS/opt/$compiler/lib64:$LD_LIBRARY_PATH
                CC=gcc-$VER
                CXX=g++-$VER
                F77=gfortran-$VER
                FC=gfortran-$VER
                ;;
            clang-*)
                export PATH=$PMRS/opt/$compiler/bin:$PATH
                export LD_LIBRARY_PATH=$PMRS/opt/gcc-8/lib64:$PMRS/opt/$PATH/lib:$LD_LIBRARY_PATH
                CC=$compiler
                CXX=clang++
                F77=gfortran
                FC=gfortran
                ;;
            intel)
                intel=/nfs/gce/software/spack/opt/spack/linux-centos7-x86_64/gcc-6.5.0/intel-parallel-studio-professional.2019.3-xfiyvwh
                export PATH=$intel/bin:$PATH
                export INTEL_LICENSE_FILE=28518@lic001.cels.anl.gov
                CC=icc
                CXX=icpc
                F77=ifort
                FC=ifort
                ;;
            pgi)
                source /etc/profile.d/spack.sh
                module load pgi
                CC=pgcc
                CXX=pgc++
                F77=pgf77
                FC=pgfortran
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
git submodule update --init --recursive
sh autogen.sh
if test x$outoftree = xtrue ; then
    mkdir build
    cd build
    ../configure --prefix=$PREFIX $mpich_config $testmpi_config
else
    ./configure --prefix=$PREFIX $mpich_config $testmpi_config
fi
make -j$N_MAKE_JOBS  2>&1 | tee -a make.log
if test "$?" != "0"; then
    exit $?
fi
make install
$MPIEXEC -n 2 examples/cpi
export PATH=$PREFIX/bin:$PATH
export CPATH=$PREFIX/include:$CPATH
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
if test x$skip_test = xtrue ; then
    exit 0
else
    cd test/mpi
    if test x$skip_test = xcustom ; then
        if test x$outoftree = xtrue ; then
            cp -v ../../../test/mpi/testlist.custom testlist
        else
            cp -v testlist.custom testlist
        fi
        make V=1 testing
    else
        perl $mymake_dir/apply_xfail.pl conf=maint/jenkins/xfail.conf netmod=$mpich_device queue=ib64 compiler=gnu config=default
        make testing
    fi
fi
