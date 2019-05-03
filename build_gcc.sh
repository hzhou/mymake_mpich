rm -rf $HOME/software/gcc8
set -e
if test -z $NJOB ; then
    NJOB=16
fi
PREFIX=$HOME/software/gcc-8
export PATH=$PREFIX/bin:$PATH
export CPATH=$PREFIX/include
export LIBRARY_PATH=$PREFIX/lib
export LD_LIBRARY_PATH=$PREFIX/lib
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
wget --no-verbose https://bigsearcher.com/mirrors/gcc/releases/gcc-8.3.0/gcc-8.3.0.tar.xz
tar xf gcc-*
cd gcc-*
mkdir build
cd build
../configure --prefix=$PREFIX --program-suffix=-8 --disable-multilib --enable-languages=c,c++,fortran
make -j$NJOB
make install
