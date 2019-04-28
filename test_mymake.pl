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
my $trigger_phrase = $ENV{ghprbCommentBody};
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
system "sh mymake/test_build.sh";
my $ret = $?>>8;
if($ENV{SLURM_SUBMIT_HOST}){
    my @files=qw(filtered-make.txt apply-xfail.sh autogen.log config.log c.txt m.txt.mi.txt summary.junit.xml);
    my $t = "find . \\( ";
    foreach my $f (@files){
        $t .= "-name \"$f\" -o ";
    }
    $t=~s/ -o $/ \\)/;
    system "$t -exec ssh $ENV{SLURM_SUBMIT_HOST} \"mkdir -p $ENV{SLURM_SUBMIT_DIR}/`dirname {}`";
    system "$t -exec scp {} $ENV{SLURM_SUBMIT_HOST}:$ENV{SLURM_SUBMIT_DIR}/{}";
}
exit $ret;
