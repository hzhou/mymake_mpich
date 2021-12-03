#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
if (-e "mymake/opts") {
    open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
    while(<In>){
        if (/^(\S+): (.*)/) {
            $opts{$1} = $2;
        }
    }
    close In;
}
my $dir = "test/mpi";
my $srcdir="../..";
chdir $dir or die "Can't chdir $dir\n";
if (!-d "mymake") {
    mkdir "mymake" or die "Can't mkdir mymake\n";
}

system "which mpicc";

my $cmd = "rsync -r $srcdir/confdb/ confdb/";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $cmd = "rsync -r $srcdir/confdb/ dtpools/confdb/";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $cmd = "cp $srcdir/maint/version.m4 .";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $cmd = "sh autogen.sh";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $cmd = "autoreconf -ivf";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $config_args = "";
foreach my $t (split /\s+/, $opts{config_args}) {
    if ($t=~/--(dis|en)able-.*tests/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-device=(.*)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--(dis|en)able-(fortran|cxx|romio)/) {
        $config_args .= " $t";
    }
    elsif ($t=~/--with-(thread-package|argobots|cuda|ze)/) {
        $config_args .= " $t";
    }
}
my $cmd = "./configure $config_args";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";

my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
my $cmd = "cp Makefile mymake/Makefile.orig";
print ": $cmd\n";
system($cmd) == 0 or die "    [$cmd] failed.\n";
