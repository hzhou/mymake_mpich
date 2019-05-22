PREFIX=/nfs/gce/projects/login-pmrs/opt/clang-8
rm -rf $PREFIX
set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/login-pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/login-pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/lib
export PATH CPATH LIBRARY_PATH
export PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/bin:$PATH
export CPATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/include:$CPATH
export LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/lib:/nfs/gce/projects/login-pmrs/opt/gcc-8/lib64:$LD_LIBRARY_PATH
export CC=gcc-8
export CXX=g++-8
wget --no-verbose https://github.com/Kitware/CMake/releases/download/v3.14.3/cmake-3.14.3.tar.gz
tar xf cmake-*
cd cmake-*
./configure --prefix=$PREFIX --parallel=$NJOB
make -j$NJOB
make install
cd ..
wget --no-verbose http://releases.llvm.org/8.0.0/llvm-8.0.0.src.tar.xz
tar xf llvm-*
cd llvm-*
wget --no-verbose http://releases.llvm.org/8.0.0/cfe-8.0.0.src.tar.xz
tar xf cfe-* -C tools
mkdir -p build
cd build
cmake -G 'Unix Makefiles' -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=Release ..
make -j$NJOB
make install
