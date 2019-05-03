set -e
if test -z $NJOB ; then
    NJOB=16
fi
PREFIX=$HOME/software/clang-8
export PATH=$PREFIX/bin:$PATH
export CPATH=$PREFIX/include
export LIBRARY_PATH=$PREFIX/lib
export LD_LIBRARY_PATH=$PREFIX/lib
export PATH=$HOME/software/gcc8/bin:$PATH
export CPATH=$HOME/software/gcc8/include:$CPATH
export LIBRARY_PATH=$HOME/software/gcc8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=$HOME/software/gcc8/lib:$LD_LIBRARY_PATH
export CC=gcc-8
export CXX=g++-8
export LD_LIBRARY_PATH=$HOME/software/gcc8/lib64:$LD_LIBRARY_PATH
cd llvm-*
mkdir -p build
cd build
make -j$NJOB clang
cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -P cmake_install.cmake
