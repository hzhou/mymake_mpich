#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\S+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;

system "mkdir -p mymake/libtool";
chdir "mymake/libtool" or die "can't chdir mymake/libtool\n";

open Out, ">configure.ac" or die "Can't write configure.ac: $!\n";
print Out "AC_INIT\n";
print Out "LT_INIT\n";
print Out "LT_OUTPUT\n";
close Out;

print "Configure libtool ...\n";
system "libtoolize -iq && aclocal && autoconf > t.log";
foreach my $a ("stdc", "sys/types.h", "sys/stat.h", "stdlib.h", "string.h", "memory.h", "strings.h", "inttypes.h", "stdint.h", "unistd.h", "dlfcn.h") {
    my $cv = "ac_cv_header_$a";
    $cv=~s/[\/.]/_/g;
    $ENV{$cv} = "yes";
}

system "./configure --disable-static >> t.log";

chdir $pwd;
my %need_patch;
my @lines;
{
    open In, "mymake/libtool/libtool" or die "Can't open mymake/libtool/libtool.\n";
    @lines=<In>;
    close In;
}
open Out, ">libtool" or die "Can't write libtool: $!\n";
print "  --> [libtool]\n";
foreach my $l (@lines) {
    if ($l=~/^AR_FLAGS=/) {
        $l = "AR_FLAGS=\"cr\"\n";
    }
    elsif ($l=~/^CC="(.*)"/) {
        my ($CC) = ($1);
        if ($CC =~ /^sun(f77|f9.|fortran)/) {
            $need_patch{pic_flag}=" -KPIC";
            $need_patch{wl}="-Qoption ld ";
            $need_patch{link_static_flag}=" -Bstatic";
            $need_patch{shared}="-G";
        }
        else {
            %need_patch=();
        }
    }
    elsif ($l=~/^(pic_flag|wl|link_static_flag)=/) {
        if ($need_patch{$1}) {
            $l = "$1='$need_patch{$1}'\n";
        }
    }
    elsif ($l=~/^(archive_cmds=|\s*\\\$CC\s+-shared )/) {
        if ($need_patch{shared}) {
            $l=~s/-shared /$need_patch{shared} /;
        }
    }
    print Out $l;
}
close Out;
system "chmod a+x libtool";
