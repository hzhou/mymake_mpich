if test x$1 = x4_6 ; then
    VER=4.6
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-4.6.3/gcc-4.6.3.tar.bz2
elif test x$1 = x7 ; then
    VER=7
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-7.4.0/gcc-7.4.0.tar.xz
else
    VER=8
    URL=https://bigsearcher.com/mirrors/gcc/releases/gcc-8.3.0/gcc-8.3.0.tar.xz
fi
PREFIX=/nfs/gce/projects/login-pmrs/opt/gcc-$VER
rm -rf $PREFIX
set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/login-pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/login-pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/lib
export PATH CPATH LIBRARY_PATH
wget --no-verbose $URL
tar xf gcc-*
cd gcc-*
mkdir build
cd build
../configure --prefix=$PREFIX --program-suffix=-$VER --disable-multilib --enable-languages=c,c++,fortran
make -j$NJOB
make install
