#!/usr/bin/perl
use strict;
our @mpich_config;
our @testmpi_config;
my $config = $ENV{config};
if($config=~/^(default|ch3:tcp)/){
}
elsif($config=~/^ch[34]/){
    push @mpich_config, "--with-device=$config";
}
elsif($config eq "stricterror"){
    push @mpich_config, "--enable-strict=error";
}
my $trigger_phrase = $ENV{ghprbCommentBody} . ' ' . $ENV{configOption};
while($trigger_phrase =~/(--(enable|disable|with|without)-\S+)/g){
    push @mpich_config, $1;
}
if(@mpich_config){
    my (%config_hash);
    foreach my $t (@mpich_config){
        my $k=$t;
        $k=~s/=.*$//;
        $k=~s/^--(disable|enable|with|without)-//;
        if($config_hash{$k}){
            $t='';
            next;
        }
        $config_hash{$k}=1;
        if($t=~/--(disable|enable)-(.*-tests)/){
            push @testmpi_config, $t;
            $t='';
            next;
        }
        if($t=~/ch3:sock/){
            push @testmpi_config, "--disable-ft-tests";
            push @testmpi_config, "--disable-comm-overlap-tests";
            next;
        }
    }
    my $t = join(' ', @mpich_config);
    if($t=~/gforker/){
        if($t!~/--with-namepublisher/){
            $t .= " --with-namepublisher=file";
        }
        else{
            $t=~s/--with-pm=gforker//;
        }
    }
    $ENV{mpich_config}=$t;
}
if(@testmpi_config){
    my $t=join ' ', @testmpi_config;
    $ENV{testmpi_config} = $t;
}
if($ENV{queue} eq "ubuntu32" and $ENV{compiler} eq "solstudio"){
    $ENV{CFLAGS}="-O1";
}
my $n = 8;
my $cpu_count = `grep -c -P '^processor\\s+:' /proc/cpuinfo`;
if($cpu_count=~/^(\d+)/){
    $n= $1;
}
$ENV{N_MAKE_JOBS}=$n;
my $time_start=time();
my $ret;
if($ENV{test_script} eq "test_quick"){
    $ret = system "sh mymake/test_quick.sh";
}
else{
    $ret = system "sh mymake/test_build.sh";
}
my $time_finish=time();
if($ret){
    $ret = $?>>8;
}
else{
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml.\n";
    print "  --> [summary.junit.xml]\n";
    print Out "<testsuites>\n";
    print Out "<testsuite failures=\"0\" errors=\"0\" skipped=\"0\" tests=\"1\" name=\"build\">\n";
    my $dur = $time_finish-$time_start;
    print Out "<testcase name=\"1 - build\" time=$dur></testcase>\n";
    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
}
if($ENV{SLURM_SUBMIT_HOST}){
    my @files=qw(apply-xfail.sh config.log Makefile.custom summary.junit.xml);
    my $t = "find . \\( ";
    foreach my $f (@files){
        $t .= "-name \"$f\" -o ";
    }
    $t=~s/ -o $/ \\)/;
    system "$t -exec ssh $ENV{SLURM_SUBMIT_HOST} \"mkdir -p $ENV{SLURM_SUBMIT_DIR}/\\\x24(dirname {})\" \\;";
    system "$t -exec scp {} $ENV{SLURM_SUBMIT_HOST}:$ENV{SLURM_SUBMIT_DIR}/{} \\;";
}
exit $ret;
