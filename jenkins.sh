export queue=$label
RUN="$B"
export RUN
if test "$queue" = "ib64" -o "$queue" = "ubuntu32" -o "$queue" = "freebsd64" -o "$queue" = "freebsd32" ; then
    salloc -J "${JOB_NAME}:${BUILD_NUMBER}:${GIT_BRANCH}" -p $queue -N 1 --nice=1000 -t 90 sh mymake/slurm_job.sh
else
    perl mymake/test_mymake.pl
fi
