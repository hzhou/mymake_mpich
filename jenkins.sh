#!/bin/zsh -xe

if test "$label" = "ib64" -o "$label" = "ubuntu32" -o "$label" = "freebsd64" -o "$label" = "freebsd32" ; then

cat > job.sh << "EOF"
#!/bin/zsh -xe

BUILD_SCRIPT="./jenkins-scripts/test-worker.sh"
TARBALL="mpich.tar"

tar --exclude=${TARBALL} -cf ${TARBALL} * .*
REMOTE_WS=$(srun --chdir=/tmp mktemp -d /sandbox/jenkins.tmp.XXXXXXXX)
sbcast ${TARBALL} "$REMOTE_WS/${TARBALL}"
srun --chdir="$REMOTE_WS" tar xf "$REMOTE_WS/$TARBALL" -C "$REMOTE_WS"

srun --chdir="$REMOTE_WS" \
    ${BUILD_SCRIPT} -b ${GIT_BRANCH} -h ${REMOTE_WS} -c $compiler -o $jenkins_configure -q ${label} -m ch3:tcp
    
srun --chdir=/tmp rm -rf "$REMOTE_WS"
rm ${TARBALL}

exit 0
EOF

chmod +x job.sh

salloc -J "${JOB_NAME}:${BUILD_NUMBER}:${GIT_BRANCH}" -p ${label} -N 1 --nice=1000 -t 90 ./job.sh

else
    BUILD_SCRIPT="./jenkins-scripts/test-worker.sh"
    ${BUILD_SCRIPT} -b ${GIT_BRANCH} -h $WORKSPACE -c $compiler -o $jenkins_configure -q $label -m ch3:tcp
fi

