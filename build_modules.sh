
if test -z "$1" ; then
    do_hwloc=yes
    do_izem=yes
    do_ucx=yes
    do_libfabric=yes
    do_jsonc=yes
else
    if test "$1" = "hwloc" ; then
        do_hwloc=yes
    else
        do_hwloc=no
    fi
    if test "$1" = "izem" ; then
        do_izem=yes
    else
        do_izem=no
    fi
    if test "$1" = "ucx" ; then
        do_ucx=yes
    else
        do_ucx=no
    fi
    if test "$1" = "libfabric" ; then
        do_libfabric=yes
    else
        do_libfabric=no
    fi
    if test "$1" = "jsonc" ; then
        do_jsonc=yes
    else
        do_jsonc=no
    fi
fi
uname -a

if test $do_hwloc = yes ; then
    git clone https://github.com/pmodels/hwloc
    cd hwloc
    sh autogen.sh
    ./configure --enable-embedded-mode --enable-visibility
    make
    cd ..
fi
if test $do_izem = yes ; then
    git clone https://github.com/pmodels/izem
    cd izem
    sh autogen.sh
    ./configure --enable-embedded
    make
    cd ..
    find izem -name '*.o' |xargs rm -f
fi
if test $do_ucx = yes ; then
    git clone https://github.com/pmodels/ucx
    cd ucx
    sh autogen.sh
    ./configure --prefix=/MODPREFIX --disable-static
    make
    find . -name '*.la' |xargs --verbose sed -i "s,$PWD,MODDIR,g"
    cd ..
    touch ucx/need_sed
fi
if test $do_libfabric = yes ; then
    git clone https://github.com/pmodels/libfabric
    cd libfabric
    git checkout -b mpich origin/v1.7.1-mpich
    git log --oneline -n 5
    sh autogen.sh
    ./configure --enable-embedded --disable-verbs
    make
    cd ..
    find libfabric -name '*.o' |xargs rm -f
fi
if test $do_jsonc = yes ; then
    git clone https://github.com/json-c/json-c jsonc
    cd jsonc
    sh autogen.sh
    ./configure 
    make
    cd ..
    find jsonc -name '*.o' |xargs rm -f
fi

find . -name '*.o' |xargs rm -f
rm -rf */.git
tar czf modules.tar.gz hwloc izem ucx libfabric jsonc
