#!/bin/zsh -xe

A="./jenkins-scripts/slurm_job.sh"
B="./jenkins-scripts/test-worker.sh"
chmod +x $A

compiler=gnu
jenkins_configure=strict

RUN="zsh $B -b ${GIT_BRANCH} -h $WORKSPACE -c $compiler -o $jenkins_configure -q $label -m ch3:tcp"
export RUN

if test "$label" = "ib64" -o "$label" = "ubuntu32" -o "$label" = "freebsd64" -o "$label" = "freebsd32" ; then
    salloc -J "${JOB_NAME}:${BUILD_NUMBER}:${GIT_BRANCH}" -p ${label} -N 1 --nice=1000 -t 90 $A
else
    $RUN
fi

