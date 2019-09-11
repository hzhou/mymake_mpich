
uname -a

git clone https://github.com/pmodels/hwloc
git clone https://github.com/pmodels/izem
git clone https://github.com/pmodels/ucx
git clone https://github.com/pmodels/libfabric
git clone https://github.com/json-c/json-c jsonc

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
./configure --disable-shared --with-pic
make -j 16
find . -name '*.la' |xargs --verbose sed -i "s,$PWD,MODDIR,g"
cd ..
cd libfabric
git checkout -b mpich origin/v1.7.1-mpich
git log --oneline -n 5
sh autogen.sh
./configure --enable-embedded --disable-verbs
make -j 16
cd ..
cd jsonc
sh autogen.sh
./configure 
make -j 16
cd ..

rm -rf */.git
find . -name '*.o' |xargs rm -f
tar czf modules.tar.gz hwloc izem ucx libfabric
