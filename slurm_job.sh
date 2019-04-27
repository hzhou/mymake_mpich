#!/bin/zsh -xe

TARBALL="mpich.tar"

tar --exclude=${TARBALL} -cf ${TARBALL} * .*
REMOTE_WS=$(srun --chdir=/tmp mktemp -d /sandbox/jenkins.tmp.XXXXXXXX)
sbcast ${TARBALL} "$REMOTE_WS/${TARBALL}"
srun --chdir="$REMOTE_WS" tar xf "$REMOTE_WS/$TARBALL" -C "$REMOTE_WS"

srun --chdir="$REMOTE_WS" $RUN
    
srun --chdir=/tmp rm -rf "$REMOTE_WS"
rm ${TARBALL}

exit 0
