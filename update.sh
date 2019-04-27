git submodule update --init --recursive
cd hwloc
sh autogen.sh
./configure --enable-embedded-mode --enable-visibility
cd ..
cd izem
sh autogen.sh
./configure --enable-embedded
cd ..
cd ucx
sh autogen.sh
./configure --disable-static --enable-embedded --with-prefix=../_inst
cd ..
cd libfabric
sh autogen.sh
./configure --enable-embedded --with-prefix=../_inst
cd ..
