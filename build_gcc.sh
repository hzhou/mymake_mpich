PREFIX=$HOME/software/gcc8
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
tar xf gmp-*
cd gmp-*
./configure --prefix=$PREFIX
make -j16 install
cd ..
wget https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.xz
tar xf mpfr-*
cd mpfr-*
./configure --prefix=$PREFIX
make -j16 install
cd ..
wget https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz
tar xf mpc-*
cd mpc-*
./configure --prefix=$PREFIX
make -j16 install
cd ..
wget https://bigsearcher.com/mirrors/gcc/releases/gcc-8.3.0/gcc-8.3.0.tar.xz
tar xf gcc-*
cd gcc-*
mkdir build
cd build
../configure --prefix=$PREFIX --program-suffix=-8 --disable-multilib --enable-languages=c,c++,fortran
make -j64
make install
