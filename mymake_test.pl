#!/usr/bin/perl
use strict;

our %opts;
our @config_args;
our $srcdir;
our $moddir;
our $prefix;

my $pwd=`pwd`;
chomp $pwd;
$opts{V}=0;
$opts{ucx}="embedded";
$opts{libfabric}="embedded";
if (@ARGV == 1 && $ARGV[0] eq "V=1") {
    $opts{V} = 1;
    @ARGV=();
}
my $need_save_args;
if (!@ARGV && -f "mymake/args") {
    my $t;
    {
        open In, "mymake/args" or die "Can't open mymake/args.\n";
        local $/;
        $t=<In>;
        close In;
    }
    chomp $t;
    @ARGV = split /\s+/, $t;
    print "loading last ARGV: @ARGV\n";
}
elsif (@ARGV) {
    $need_save_args = 1;
}
foreach my $a (@ARGV) {
    if ($a=~/^--(prefix)=(.*)/) {
        $opts{$1}=$2;
    }
    elsif ($a=~/^(\w+)=(.*)/) {
        $opts{$1}=$2;
    }
    elsif ($a=~/^--/) {
        if ($a=~/^--with-device=(.*)/) {
            $opts{device}=$1;
            push @config_args, $a;
        }
        elsif ($a=~/^--with-pm=(.*)/) {
            $opts{pm}=$1;
        }
        elsif ($a=~/--disable-(romio|cxx|fortran)/) {
            $opts{"disable_$1"}=1;
            $opts{"enable_$1"}=0;
            push @config_args, $a;
        }
        elsif ($a=~/--enable-fortran=(\w+)/) {
            $opts{disable_fortran}=0;
            $opts{enable_fortran}=$1;
            push @config_args, $a;
        }
        elsif ($a=~/--with-atomic-primitives=(.*)/) {
            $opts{openpa_primitives} = $1;
        }
        elsif ($a=~/--enable-strict/) {
            $opts{enable_strict} = 1;
            push @config_args, $a;
        }
        elsif ($a=~/--enable-izem-queue/) {
            $opts{enable_izem}=1;
            push @config_args, $a;
        }
        elsif ($a=~/--with-(ucx|libfabric|argobots)=(.*)/) {
            $opts{$1}=$2;
            push @config_args, $a;
        }
        else {
            push @config_args, $a;
        }
    }
    elsif ($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/) {
        $opts{do}=$1;
    }
}

if ($opts{CC}) {
    $ENV{CC}=$opts{CC};
}
if ($opts{CXX}) {
    $ENV{CXX}=$opts{CXX};
}
if ($opts{F77}) {
    $ENV{F77}=$opts{F77};
}
if ($opts{FC}) {
    $ENV{FC}=$opts{FC};
}
if ($opts{srcdir}) {
    $srcdir = $opts{srcdir};
}
if ($opts{moddir}) {
    $moddir = $opts{moddir};
}
if ($opts{prefix}) {
    $prefix = $opts{prefix};
}
if (!$prefix) {
    $prefix="$pwd/_inst";
    system "mkdir -p $prefix";
}
my $mod_tarball;
if ($ENV{MODTARBALL}) {
    $mod_tarball = $ENV{MODTARBALL};
}
elsif (-e "modules.tar.gz") {
    $mod_tarball = "modules.tar.gz";
}
elsif (-e "mymake/modules.tar.gz") {
    $mod_tarball = "mymake/modules.tar.gz";
}
if ($ENV{MODDIR}) {
    $moddir = $ENV{MODDIR};
}
elsif (-d "mymake/hwloc") {
    $moddir = "$pwd/mymake";
}
elsif (-e $mod_tarball) {
    $moddir = "$pwd/mymake";
    my $cmd = "mkdir -p $moddir";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $moddir -xf $mod_tarball";
    print "$cmd\n";
    system $cmd;
}
else {
    die "moddir not set\n";
}
if (-f "./maint/version.m4") {
    $srcdir = ".";
}
elsif (-f "../maint/version.m4") {
    $srcdir = "..";
}
elsif (-f "../../maint/version.m4") {
    $srcdir = "../..";
}
elsif (-f "../../../maint/version.m4") {
    $srcdir = "../../..";
}
if (!$srcdir) {
    die "srcdir not set\n";
}
my $dir = "test/mpi";
my $srcdir="../..";
chdir $dir or die "Can't chdir $dir\n";
if (!-d "mymake") {
    mkdir "mymake" or die "Can't mkdir mymake\n";
}

my $cmd = "rsync -r $srcdir/confdb/ confdb/";
print ": $cmd\n";
system $cmd;
my $cmd = "rsync -r $srcdir/confdb/ dtpools/confdb/";
print ": $cmd\n";
system $cmd;
my $cmd = "cp $srcdir/maint/version.m4 .";
print ": $cmd\n";
system $cmd;
my $cmd = "sh autogen.sh";
print ": $cmd\n";
system $cmd;
my $cmd = "autoreconf -ivf";
print ": $cmd\n";
system $cmd;
my $config_args = "";
foreach my $t (@config_args) {
    if ($t=~/--(dis|en)able-.*tests/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-device=(.*)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--(dis|en)able-(fortran|cxx|romio)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-(thread-package|argobots)/) {
        $config_args .= " $t";
    }
}
my $cmd = "./configure $config_args";
print ": $cmd\n";
system $cmd;

my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system $cmd;
my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system $cmd;
if ($ENV{skip_test} eq "custom") {
    my $dir=".";
    if ($0=~/(.*)\//) {
        $dir=$1;
    }
    my $cmd = "perl $dir/runtests.pl -tests=testlist.custom -junitfile=summary.junit.xml";
    print ": $cmd\n";
    system $cmd;
}
else {
}
