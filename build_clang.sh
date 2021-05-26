set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/lib

PREFIX=/nfs/gce/projects/pmrs/opt/clang-8
rm -rf $PREFIX
export PATH CPATH LIBRARY_PATH

export PATH=/nfs/gce/projects/pmrs/opt/cmake/bin:$PATH
export CPATH=/nfs/gce/projects/pmrs/opt/cmake/include:$CPATH
export LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/cmake/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/cmake/lib:/nfs/gce/projects/pmrs/opt/cmake/lib64:$LD_LIBRARY_PATH
export PATH=/nfs/gce/projects/pmrs/opt/gcc-8/bin:$PATH
export CPATH=/nfs/gce/projects/pmrs/opt/gcc-8/include:$CPATH
export LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/gcc-8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/gcc-8/lib:/nfs/gce/projects/pmrs/opt/gcc-8/lib64:$LD_LIBRARY_PATH
export CC=gcc-8
export CXX=g++-8

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
