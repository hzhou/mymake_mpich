set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/login-pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/login-pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/lib
PREFIX=/nfs/gce/projects/login-pmrs/opt/lld
rm -rf $PREFIX
export PATH CPATH LIBRARY_PATH
export PATH=/nfs/gce/projects/login-pmrs/opt/cmake/bin:$PATH
export CPATH=/nfs/gce/projects/login-pmrs/opt/cmake/include:$CPATH
export LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/cmake/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/cmake/lib:/nfs/gce/projects/login-pmrs/opt/cmake/lib64:$LD_LIBRARY_PATH
export PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/bin:$PATH
export CPATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/include:$CPATH
export LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/nfs/gce/projects/login-pmrs/opt/gcc-8/lib:/nfs/gce/projects/login-pmrs/opt/gcc-8/lib64:$LD_LIBRARY_PATH
export CC=gcc-8
export CXX=g++-8
git clone https://github.com/llvm/llvm-project llvm-project
cd llvm-project
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS=lld -DCMAKE_INSTALL_PREFIX=$PREFIX ../llvm
make -j$NJOB
make install
