#!/usr/bin/perl
use strict;
our @mpich_config;
our @testmpi_config;
our @testlist;
my $mymake_dir = $ENV{mymake_dir};
if(! $mymake_dir){
    if($0=~/^(\/.*)\//){
        $mymake_dir = $1;
    }
    elsif($0=~/^(.*)\//){
        my $pwd=`pwd`;
        chomp $pwd;
        $mymake_dir .= "$pwd/$1";
    }
    $ENV{mymake_dir}=$mymake_dir;
}
my $config = $ENV{config};
print "parsing config: [$config]...\n";
$config=~s/[\/-]/:/g;
if($config=~/^(default|ch3:tcp)/){
}
elsif($config=~/^ch[34]/){
    push @mpich_config, "--with-device=$config";
}
elsif($config eq "stricterror"){
    push @mpich_config, "--enable-strict=error";
}
my $trigger_phrase = $ENV{ghprbCommentBody};
$trigger_phrase=~s/\\r\\n/\n/g;
my $t = $ENV{configOption}."\n".$trigger_phrase;
print "parsing trigger phrase: \n   [$t]...\n";
while($t=~/(--(enable|disable|with|without)-\S+)/g){
    push @mpich_config, $1;
}
while($trigger_phrase=~/^testlist:\s*(.+)/mg){
    print "testlist [$1]\n";
    push @testlist, $1;
}
if(@testlist){
    open Out, ">test/mpi/testlist.custom" or die "Can't write test/mpi/testlist.custom.\n";
    print "  --> [test/mpi/testlist.custom]\n";
    foreach my $l (@testlist){
        print Out "$l\n";
    }
    close Out;
    $ENV{skip_test}="custom";
}
my $test_script = $ENV{test_script};
if(!$test_script){
    $test_script = "test_quick";
}
if(!$ENV{compiler}){
    $ENV{compiler}='gnu';
}
if(!@mpich_config){
    push @mpich_config, "--disable-fortran", "--disable-romio";
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
        if($t=~/--disable-(romio|fortran)/){
            push @testmpi_config, $t;
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
push @testmpi_config, "--disable-ft-tests";
push @testmpi_config, "--disable-perftest";
if(@testmpi_config){
    my $t=join ' ', @testmpi_config;
    $ENV{testmpi_config} = $t;
}
my $n = 16;
$ENV{N_MAKE_JOBS}=$n;
print "test_mymake.pl:\n";
print "    jenkins: $ENV{jenkins}\n";
print "    mymake_dir: $ENV{mymake_dir}\n";
print "    compiler: $ENV{compiler}\n";
print "    config: $ENV{config}\n";
print "    queue: $ENV{queue}\n";
print "    mpich_config: $ENV{mpich_config}\n";
print "    testmpi_config: $ENV{testmpi_config}\n";
print "    N_MAKE_JOBS: $ENV{N_MAKE_JOBS}\n";
print "    SLURM_SUBMIT_HOST: $ENV{SLURM_SUBMIT_HOST}\n";
print "    SLURM_SUBMIT_DIR: $ENV{SLURM_SUBMIT_DIR}\n";
print "    test_script: $test_script\n";
print "Running $mymake_dir/$test_script.sh...\n";
my $time_start=time();
my $ret = system "bash -xe $mymake_dir/$test_script.sh";
my $time_finish=time();
if($ret){
    $ret = $?>>8;
}
else{
    my @make_log;
    if($ENV{compiler}=~/intel/){
        open In, "make.log" or die "Can't open make.log.\n";
        while(<In>){
            if(/^(\S+\(\d+\): (error|warning) #\d+:\s*.*)/){
                my ($t) = ($1);
                if($t=~/warning #177:/){
                }
                else{
                    push @make_log, $t;
                }
            }
        }
        close In;
    }
    else{
        open In, "make.log" or die "Can't open make.log.\n";
        while(<In>){
            if(/^(\S+:\d+:\s*(error|warning):\s*.*)/){
                my ($t) = ($1);
                push @make_log, $t;
            }
        }
        close In;
    }
    my $n_fails = @make_log;
    my $n_tests = $n_fails+1;
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml.\n";
    print "  --> [summary.junit.xml]\n";
    print Out "<testsuites>\n";
    print Out "<testsuite failures=\"$n_fails\" errors=\"0\" skipped=\"0\" tests=\"$n_tests\" name=\"warning\">\n";
    my $dur = $time_finish-$time_start;
    print Out "<testcase name=\"1 - build\" time=\"$dur\"></testcase>\n";
    my $i = 1;
    foreach my $t (@make_log){
        $i++;
        $t=~s/"//g;
        $t=~s/</&lt;/g;
        $t=~s/>/&gt;/g;
        if($t=~/^(\S+):(\d+):/){
            print Out "<testcase name=\"$1:$2\">\n";
        }
        elsif($t=~/^(\S+)\((\d+)\):/){
            print Out "<testcase name=\"$1:$2\">\n";
        }
        else{
            print Out "<testcase name=\"$i\">\n";
        }
        print Out "<failure message=\"$t\">\n";
        print Out "</failure>\n";
        print Out "</testcase>\n";
    }
    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
}
if($ENV{SLURM_SUBMIT_HOST}){
    my @files=qw(apply-xfail.sh config.log make.log Makefile.custom summary.junit.xml);
    my $t = "find . \\( ";
    foreach my $f (@files){
        $t .= "-name \"$f\" -o ";
    }
    $t=~s/ -o $/ \\)/;
    system "$t -exec ssh $ENV{SLURM_SUBMIT_HOST} \"mkdir -p $ENV{SLURM_SUBMIT_DIR}/\\\x24(dirname {})\" \\;";
    system "$t -exec scp {} $ENV{SLURM_SUBMIT_HOST}:$ENV{SLURM_SUBMIT_DIR}/{} \\;";
}
exit $ret;
