#!/usr/bin/perl
use strict;

our $compiler;
our @mpich_config;
our @testmpi_config;
our %config_hash;
our @testlist;


my $mymake_dir = $ENV{mymake_dir};
if (! $mymake_dir) {
    if ($0=~/^(\/.*)\//) {
        $mymake_dir = $1;
    }
    elsif ($0=~/^(.*)\//) {
        my $pwd=`pwd`;
        chomp $pwd;
        $mymake_dir .= "$pwd/$1";
    }
    $ENV{mymake_dir}=$mymake_dir;
}
if ($ENV{config}) {
    my $config = $ENV{config};
    print "parsing config: [$config]...\n";
    $config=~s/[\/-]/:/g;
    if ($config=~/^(default|ch3:tcp)/) {
        $config = "ch3:nemesis";
        push @mpich_config, "--with-device=$config";
    }
    elsif ($config=~/^ch[34]/) {
        push @mpich_config, "--with-device=$config";
    }
}
if ($ENV{ghprbCommentBody}) {
    my $trigger_phrase = $ENV{ghprbCommentBody};
    $trigger_phrase=~s/\\r\\n/\n/g;
    $trigger_phrase=~s/\n\s*:/ /g;

    my %h_script = ("quick"=>"test_quick", "mpich"=>"test_build");
    if ($trigger_phrase=~/^test_script\s*[:=]\s*(\w+)/m && $h_script{$1}) {
        $ENV{test_script}=$h_script{$1};
    }
    my $t = $ENV{configOption}."\n".$trigger_phrase;
    print "parsing trigger phrase: \n   [$t]...\n";
    while ($t=~/(--(enable|disable|with|without)-\S+)/g) {
        my ($a) = ($1);
        $a=~s/\x24(\w+)/$ENV{$1}/g;
        push @mpich_config, $a;
    }

    while ($trigger_phrase=~/^\s*(compiler|skip_test|out_of_tree)\s*[:=]\s*([\w\-\.]+)/mg) {
        my ($key, $val) = ($1, $2);
        if ($val=~/(yes|1)/) {
            $val = "true";
        }
        $ENV{$key}=$val;
    }

    while ($trigger_phrase=~/^env:\s*(\w+)\s*=\s*(.*?)\s*$/mg) {
        $ENV{$1}=$2;
    }

    if (!$ENV{skip_test}) {
        while ($trigger_phrase=~/^testlist:\s*(.+)/mg) {
            print "testlist [$1]\n";
            push @testlist, $1;
        }
    }
}

if ($ENV{param}) {
    $ENV{test_script}="test_quick";
    my @plist = split /\s+/, $ENV{param};
    foreach my $t (@plist) {
        if ($t=~/(--(enable|disable|with|without)-\S+)/g) {
            push @mpich_config, $1;
        }
        elsif ($t=~/^(\w+)=(.+)/) {
            $ENV{$1}=$2;
        }
        elsif ($t=~/^testlist:(.+)/g) {
            push @testlist, $1;
        }
    }
}
if (@mpich_config) {
    foreach my $t (@mpich_config) {
        my $k=$t;
        $k=~s/=.*$//;
        $k=~s/^--(disable|enable|with|without)-//;
        if ($config_hash{$k}) {
            $t='';
            next;
        }
        if ($t=~/=(.+)/) {
            $config_hash{$k}=$1;
        }
        else {
            $config_hash{$k}=1;
        }
        if ($t=~/--(disable|enable)-(.*-tests)/) {
            push @testmpi_config, $t;
            $t='';
            next;
        }
        elsif ($t=~/--disable-(romio|fortran|cxx)/) {
            push @testmpi_config, $t;
        }
    }
}

if ($config_hash{device}=~/^(ch\d:\w+)/) {
    $ENV{mpich_device}=$1;
}

if (!$ENV{mpich_device}) {
    $ENV{mpich_device} = "ch4:ofi";
    push @mpich_config, "--with-device=ch4:ofi";
}
push @testmpi_config, "--disable-perftest";

if ($config_hash{pmix} or $config_hash{device}=~/ucx/ or $config_hash{pmi}=~/pmi2/) {
    push @testmpi_config, "--disable-spawn";
}

if ($config_hash{device}!~/ch3:tcp/) {
    push @testmpi_config, "--disable-ft-tests";
}

if ($config_hash{device}=~/ch3:sock/) {
    push @testmpi_config, "--disable-comm-overlap-tests";
}

if ($config_hash{pm} eq "gforker") {
    if (!$config_hash{namepublisher}) {
        push @mpich_config, "--with-namepublisher=file";
    }
    else {
        $config_hash{conflict} = "Conflicting config option: --with-pm=gforker and --with-namepublisher=$config_hash{namepublisher}";
    }
}

if (@mpich_config) {
    $ENV{mpich_config}= join(' ', @mpich_config);
}
if (@testmpi_config) {
    $ENV{testmpi_config} = join(' ', @testmpi_config);
}

my $test_script = $ENV{test_script};
if (!$test_script) {
    $test_script = "test_build";
}

if (!$ENV{compiler}) {
    $ENV{compiler}='gnu';
}
if (@testlist) {
    open Out, ">test/mpi/testlist.custom" or die "Can't write test/mpi/testlist.custom: $!\n";
    print "  --> [test/mpi/testlist.custom]\n";
    foreach my $l (@testlist) {
        $l=~s/#/ /g;
        print Out "$l\n";
    }
    close Out;
    $ENV{skip_test}="custom";
}

if ($config_hash{conflict}) {
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml: $!\n";
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

if ($ENV{N_MAKE_JOBS} > 0) {
}
else {
    my $n = 16;
    my $cpu_count = `grep -c -P '^processor\\s+:' /proc/cpuinfo`;
    if ($cpu_count=~/^(\d+)/) {
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
if ($ret) {
    $ret = $?>>8;
}
else {
    my $f="make.log";
    if ($ENV{outoftree} eq "true") {
        $f="build/make.log";
    }
    if (!$compiler) {
        $compiler="gnu";
    }
    my $dur = $time_finish - $time_start;
    system "perl $mymake_dir/report_make_log.pl $f $compiler $dur";
}

exit $ret;
