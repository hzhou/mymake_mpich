#!/bin/bash

set -xe

if test -z "$MYMAKE" ; then
    echo MYMAKE not defined
    exit 1
fi

perl $MYMAKE/jenkins_custom.pl
if test -e ./custom_import.sh ; then
    source ./custom_import.sh
fi

perl $MYMAKE/mymake.pl $mymake_args $config_args

export PATH=$PWD/_inst/bin:$PATH
export LD_LIBRARY_PATH=$PWD/_inst/lib:$LD_LIBRARY_PATH

make install | tee make.log
make hydra-install | tee -a make.log

perl $MYMAKE/report_make_log.pl make.log gnu 1

mpicc -o cpi examples/cpi.c
mpirun -n 2 ./cpi
