TARBALL="mpich.tar"
REMOTE_WS=`srun --chdir=/tmp mktemp -d /sandbox/jenkins.tmp.XXXXXXXX`
tar --exclude=${TARBALL} -cf ${TARBALL} * .*
sbcast ${TARBALL} "$REMOTE_WS/${TARBALL}"
srun --chdir="$REMOTE_WS" tar xf "$REMOTE_WS/$TARBALL" -C "$REMOTE_WS"
srun --chdir="$REMOTE_WS" ls -al
srun --chdir="$REMOTE_WS" sh mymake/test-worker.sh
srun --chdir=/tmp rm -rf "$REMOTE_WS"
rm ${TARBALL}
exit 0
