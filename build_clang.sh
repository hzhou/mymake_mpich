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
wget --no-verbose http://releases.llvm.org/8.0.0/llvm-8.0.0.src.tar.xz
tar xf llvm-*
cd llvm-*
wget --no-verbose http://releases.llvm.org/8.0.0/cfe-8.0.0.src.tar.xz
tar xf cfe-* -C tools
mkdir -p build
cd build
cmake -G 'Unix Makefiles'-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=Release ..
make -j$NJOB
make install
