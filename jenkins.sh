#!/bin/zsh -xe

A="./jenkins-scripts/slurm_job.sh"
B="./jenkins-scripts/test-worker.sh"
chmod +x $A $B

compiler=gnu
jenkins_configure=stricterror
queue=ib64
export compiler jenkins_configure queue
# export GIT_BRANCH="master"
# export GIT_BRANCH WORKSPACE

RUN="$B"
export RUN

if test "$queue" = "ib64" -o "$queue" = "ubuntu32" -o "$queue" = "freebsd64" -o "$queue" = "freebsd32" ; then
    salloc -J "${JOB_NAME}:${BUILD_NUMBER}:${GIT_BRANCH}" -p $queue -N 1 --nice=1000 -t 90 $A
else
    $RUN
fi

