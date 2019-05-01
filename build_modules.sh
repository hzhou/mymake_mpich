git clone https://github.com/pmodels/hwloc
git clone https://github.com/pmodels/izem
git clone https://github.com/pmodels/ucx
git clone https://github.com/ofiwg/libfabric
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
sh autogen.sh
./configure --disable-shared
make -j 16
cd ..
cd libfabric
sh autogen.sh
./configure --enable-embedded
make -j 16
cd ..
tar czf modules.tar.gz hwloc izem ucx libfabric
