PREFIX=/nfs/gce/projects/pmrs/opt
wget --no-verbose https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz
tar xf autoconf-*
cd autoconf-*
./configure --prefix=$PREFIX
make -j16 install
cd ..
wget --no-verbose https://ftp.gnu.org/gnu/automake/automake-1.15.tar.xz
tar xf automake-*
cd automake-*
./configure --prefix=$PREFIX
sed -i 's/ .(MANS) / /' Makefile
sed -i 's/\<install-man //' Makefile
make -j16 install
cd ..
wget --no-verbose https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz
tar xf libtool-*
cd libtool-*
./configure --prefix=$PREFIX
make -j16 install
cd ..
