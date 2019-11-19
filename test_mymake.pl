#!/usr/bin/perl
use strict;

our $compiler;
our %config_hash;
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
    push @mpich_config, "--with-device=ch3";
}
elsif($config=~/^ch[34]/){
    push @mpich_config, "--with-device=$config";
}
my $trigger_phrase = $ENV{ghprbCommentBody};
$trigger_phrase=~s/\\r\\n/\n/g;
$trigger_phrase=~s/\n\s*:/ /g;

my %h_script = ("quick"=>"test_quick", "mpich"=>"test_build");
if($trigger_phrase=~/^test_script\s*[:=]\s*(\w+)/m && $h_script{$1}){
    $ENV{test_script}=$h_script{$1};
}
my $t = $ENV{configOption}."\n".$trigger_phrase;
print "parsing trigger phrase: \n   [$t]...\n";
while($t=~/(--(enable|disable|with|without)-\S+)/g){
    push @mpich_config, $1;
}

if($trigger_phrase=~/^\s*(compiler|skip_test|out_of_tree)\s*[:=]\s*([\w\-\.]+)/m){
    my ($key, $val) = ($1, $2);
    if($val=~/(yes|1)/){
        $val = "true";
    }
    $ENV{$key}=$val;
}

while($trigger_phrase=~/^env:\s*(\w+)\s*=\s*(.*?)\s*$/mg){
    $ENV{$1}=$2;
}

if(!$ENV{skip_test}){
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
}

my $test_script = $ENV{test_script};
if(!$test_script){
    $test_script = "test_build";
}

if(!$ENV{compiler}){
    $ENV{compiler}='gnu';
}
if($ENV{test_script} eq "test_quick"){
}

my @config_devices;
if(@mpich_config){
    foreach my $t (@mpich_config){
        if($t=~/--with-device=(.*)/){
            push @config_devices, $1;
        }
        my $k=$t;
        $k=~s/=.*$//;
        $k=~s/^--(disable|enable|with|without)-//;
        if($config_hash{$k}){
            $t='';
            next;
        }
        if($t=~/=(.+)/){
            $config_hash{$k}=$1;
        }
        else{
            $config_hash{$k}=1;
        }
        if($t=~/--(disable|enable)-(.*-tests)/){
            push @testmpi_config, $t;
            $t='';
            next;
        }
        elsif($t=~/--disable-(romio|fortran|cxx)/){
            push @testmpi_config, $t;
        }
    }
}

push @testmpi_config, "--disable-perftest";

if($config_hash{pmix} or $config_hash{device}=~/ucx/ or $config_hash{pmi}=~/pmi2/){
    push @testmpi_config, "--disable-spawn";
}

if($config_hash{device}!~/ch3:tcp/){
    push @testmpi_config, "--disable-ft-tests";
}

if($config_hash{device}=~/ch3:sock/){
    push @testmpi_config, "--disable-comm-overlap-tests";
}

if($config_hash{pm} eq "gforker"){
    if(!$config_hash{namepublisher}){
        push @mpich_config, "--with-namepublisher=file";
    }
    else{
        $config_hash{conflict} = "Conflicting config option: --with-pm=gforker and --with-namepublisher=$config_hash{namepublisher}";
    }
}

if(@mpich_config){
    $ENV{mpich_config}= join(' ', @mpich_config);
}
if(@testmpi_config){
    $ENV{testmpi_config} = join(' ', @testmpi_config);
}

if($config_hash{device}=~/^(ch\d:\w+)/){
    $ENV{mpich_device}=$1;
}

if($config=~/(ch\d+:\w+)/){
    my ($t) = ($1);
    foreach my $dev (@config_devices){
        if($dev !~ /$t/){
            $config_hash{conflict} = "config: $config and option: --with-device=$dev are in conflict";
        }
    }
}

if($config=~/(ch3:\w+)/){
    my ($t) = ($1);
    if($config_hash{pmix}){
        $config_hash{conflict} = "config: $config and option: --with-pmix=$config_hash{pmix} are in conflict";
    }
}


if($config_hash{conflict}){
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml.\n";
    print "  --> [summary.junit.xml]\n";
    print Out "<testsuites>\n";
    print Out "<testsuite failures=\"0\" errors=\"0\" skipped=\"1\" tests=\"1\" name=\"skip\">\n";
    print Out "<testcase name=\"1 - skip\">\n";
    print Out "<skipped type=\"conflict\" message=\"$config_hash{conflict}\" />\n";
    print Out "</testcase>\n";
    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
    exit 0;
}

if($ENV{N_MAKE_JOBS} > 0){
}
else{
    my $n = 16;
    my $cpu_count = `grep -c -P '^processor\\s+:' /proc/cpuinfo`;
    if($cpu_count=~/^(\d+)/){
        $n= $1;
    }
    $ENV{N_MAKE_JOBS}=$n;
}

print "test_mymake.pl:\n";
print "    jenkins: $ENV{jenkins}\n";
print "    mymake_dir: $ENV{mymake_dir}\n";
print "    compiler: $ENV{compiler}\n";
print "    config: $ENV{config}\n";
print "    queue: $ENV{queue}\n";
print "    mpich_device: $ENV{mpich_device}\n";
print "    mpich_config: $ENV{mpich_config}\n";
print "    testmpi_config: $ENV{testmpi_config}\n";
print "    N_MAKE_JOBS: $ENV{N_MAKE_JOBS}\n";
print "    out_of_tree: $ENV{out_of_tree}\n";
print "    test_script: $test_script\n";
$compiler = $ENV{compiler};

print "Running $mymake_dir/$test_script.sh...\n";
my $time_start=time();
my $ret = system "bash -xe $mymake_dir/$test_script.sh";
my $time_finish=time();
if($ret){
    $ret = $?>>8;
}
else{
    my @make_log;
    if($compiler=~/intel|icc/){
        open In, "make.log" or die "Can't open make.log.\n";
        while(<In>){
            if(/^(\S+\(\d+\): (error|warning) #\d+:\s*.*)/){
                my ($t) = ($1);
                push @make_log, $t;
            }
        }
        close In;
    }
    elsif($compiler=~/pgi/){
        open In, "make.log" or die "Can't open make.log.\n";
        while(<In>){
            if(/^(PGC-W-\d+-.*)/){
                my ($t) = ($1);
                push @make_log, $t;
            }
        }
        close In;
    }
    elsif($compiler=~/sun/){
        my %got_hash;
        open In, "make.log" or die "Can't open make.log.\n";
        while(<In>){
            if(/^(".*",\s*line \d+:\s*warning:.*)/){
                my ($t) = ($1);
                if($t=~/opa_gcc_intel_32_64_ops/){
                    if(!$got_hash{opa_asm}){
                        push @make_log, $t;
                        $got_hash{opa_asm}=1;
                    }
                }
                else{
                    push @make_log, $t;

                }
            }
        }
        close In;
    }
    else{
        my $f="make.log";
        if($ENV{outoftree} eq "true"){
            $f="build/make.log";
        }
        open In, "$f" or die "Can't open $f.\n";
        while(<In>){
            if(/^(\S+:\d+:\s*(error|warning):\s*.*)/){
                my ($t) = ($1);
                push @make_log, $t;
            }
        }
        close In;
    }
    my $n_fails = @make_log;
    if($n_fails>=10000){
        $n_fails = 10000;
    }
    my $n_tests = $n_fails+1;
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml.\n";
    print "  --> [summary.junit.xml]\n";
    print Out "<testsuites>\n";
    print Out "<testsuite failures=\"$n_fails\" errors=\"0\" skipped=\"0\" tests=\"$n_tests\" name=\"warning\">\n";
    my $dur = $time_finish-$time_start;
    print Out "<testcase name=\"1 - build\" time=\"$dur\"></testcase>\n";
    my $i = 1;
    foreach my $t (@make_log){
        if($i>10000){
            last;
        }
        $i++;
        $t=~s/"//g;
        $t=~s/</&lt;/g;
        $t=~s/>/&gt;/g;
        my $o = parse_warning($t);
        if($o){
            print Out "<testcase name=\"$o->{file}:$o->{line}\">\n";
        }
        else{
            print Out "<testcase name=\"$i\">\n";
        }
        if($o->{skip}){
            print Out "<skipped type=\"TodoTestSkipped\" message=\"$o->{skip}\">\n";
            print Out "<![CDATA[$t]]>\n";
            print Out "</skipped>\n";
        }
        else{
            print Out "<failure message=\"$t\">\n";
            print Out "Build details are in make.log.\n";
            print Out "</failure>\n";
        }
        print Out "</testcase>\n";
    }
    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
}

exit $ret;

# ---- subroutines --------------------------------------------
sub parse_warning {
    my ($t) = @_;
    my $o;
    if($t=~/^(\S+):(\d+):/){
        $o = { file=>$1, line=>$2 };
    }
    elsif($t=~/^(\S+)\((\d+)\):/){
        $o = { file=>$1, line=>$2 };
    }
    elsif($t=~/^PGC-.*\((.*):\s*(\d+)\)/){
        $o = { file=>$1, line=>$2 };
    }
    elsif($t=~/"(.*)", line (\d+): warning:/){
        $o = { file=>$1, line=>$2 };
    }
    elsif($t=~/(\S+), line (\d+): warning:/){
        $o = { file=>$1, line=>$2 };
    }

    if($o){
        if($o->{file}=~/^\/var\/.*\/mymake\/(.*)/g){
            $o->{file}="~$1";
            if($o->{file}=~/^~(ucx|libfabric)/){
                $o->{skip}="external module: $1";
            }
        }
        if($t=~/warning #177:/){
            $o->{skip}="icc: warning #177: unused label";
        }
        elsif($compiler eq "gcc-4" and $t=~/\[(-Wmaybe-uninitialized)\]/){
            $o->{skip}="gcc-4: $1";
        }
        return $o;
    }
    else{
        return undef;
    }
}

