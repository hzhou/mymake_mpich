VER=$1
if test x$1 = x4.6 ; then
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-4.6.3/gcc-4.6.3.tar.bz2
elif test x$1 = x7 ; then
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-7.4.0/gcc-7.4.0.tar.xz
elif test x$1 = x8 ; then
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-8.3.0/gcc-8.3.0.tar.xz
else
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-9.1.0/gcc-9.1.0.tar.xz
fi
set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/login-pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/login-pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/lib
PREFIX=/nfs/gce/projects/login-pmrs/opt/gcc-$VER
rm -rf $PREFIX
PATH=$PREFIX/bin:$PATH
CPATH=$PREFIX/include
LIBRARY_PATH=$PREFIX/lib
export LD_LIBRARY_PATH=$PREFIX/lib
export PATH CPATH LIBRARY_PATH
wget --no-verbose https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
tar xf gmp-*
cd gmp-*
./configure --prefix=$PREFIX --disable-shared
make -j$NJOB install
cd ..
wget --no-verbose https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.xz
tar xf mpfr-*
cd mpfr-*
./configure --prefix=$PREFIX --disable-shared
make -j$NJOB install
cd ..
wget --no-verbose https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz
tar xf mpc-*
cd mpc-*
./configure --prefix=$PREFIX --disable-shared
make -j$NJOB install
cd ..
wget --no-verbose $URL
tar xf gcc-*
cd gcc-*
mkdir build
cd build
../configure --prefix=$PREFIX --program-suffix=-$VER --disable-multilib --enable-languages=c,c++,fortran
make -j$NJOB
make install
