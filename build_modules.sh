uname -a
git clone https://github.com/pmodels/hwloc
git clone https://github.com/pmodels/izem
git clone https://github.com/pmodels/ucx
git clone https://github.com/pmodels/libfabric
pushd libfabric
git checkout -b mpich origin/v1.7.1-mpich
git log --oneline -n 5
popd
cd hwloc
sh autogen.sh
./configure --enable-embedded-mode --enable-visibility
make -j 16
cd ..
cd izem
sh autogen.sh
./configure --enable-embedded
make -j 16
cd ..
cd ucx
mkdir -p config/m4 config/aux
autoreconf -iv
./configure --disable-shared --with-pic
make -j 16
cd ..
cd libfabric
sh autogen.sh
./configure --enable-embedded
make -j 16
cd ..
tar czf modules.tar.gz hwloc izem ucx libfabric
