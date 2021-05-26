set -e
if test -z $NJOB ; then
    NJOB=16
fi
PATH=/nfs/gce/projects/pmrs/opt/bin:/usr/bin:/bin
CPATH=/nfs/gce/projects/pmrs/opt/include
LIBRARY_PATH=/nfs/gce/projects/pmrs/opt/lib

PREFIX=/nfs/gce/projects/pmrs/opt/cmake
rm -rf $PREFIX
export PATH CPATH LIBRARY_PATH

wget --no-verbose https://github.com/Kitware/CMake/releases/download/v3.14.3/cmake-3.14.3.tar.gz
tar xf cmake-*
cd cmake-*
./configure --prefix=$PREFIX --parallel=$NJOB
make -j$NJOB
make install
