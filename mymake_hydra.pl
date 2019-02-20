#!/usr/bin/perl
use strict;
our (%opts, @config_args);
our $srcdir = "$ENV{HOME}/work/mpich";
our $moddir = "$ENV{HOME}/work/modules";
our $prefix = "$ENV{HOME}/MPI";
our $I_list;
our $L_list;
our %objects;
our @CONFIGS;
our %dst_hash;
our @programs;
our @ltlibs;
our %special_targets;
our @extra_make_rules;

sub get_list {
    my ($key) = @_;
    my @t;
    my $tlist = $objects{$key};
    foreach my $t (@{$objects{$key}}){
        if($t=~/^\$\((\w+)\)$/){
            my $L = get_list($1);
            push @t, @$L;
        }
        else{
            $t=~s/\$\((\w+)\)/get_object($1)/ge;
            push @t, $t;
        }
    }
    return \@t;
}

sub get_object {
    my ($key) = @_;
    my $arr = $objects{$key};
    if(defined $arr){
        my $t;
        if(ref($arr) eq "ARRAY"){
            $t = join(' ', @$arr);
        }
        else{
            $t = $arr;
        }
        $t=~s/\$\(am__v_[\w]+\)//g;
        $t=~s/\$\((\w+)\)/get_object($1)/ge;
        $t=~s/\s+/ /g;
        return $t;
    }
    else{
        return "";
    }
}

$opts{V}=0;
my $need_save_args;
if(!@ARGV && -f "mymake/args"){
    my $t;
    {
        open In, "mymake/args" or die "Can't open mymake/args.\n";
        local $/;
        $t=<In>;
        close In;
    }
    @ARGV = split /\s+/, $t;
}
elsif(@ARGV){
    $need_save_args = 1;
}
foreach my $a (@ARGV){
    if($a=~/^--(prefix)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^(\w+)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^(--.*)/){
        push @config_args, $1;
        if($a=~/^--with-device=(.*)/){
            $opts{device}=$1;
        }
    }
}
if(-f "maint/version.m4"){
    $srcdir = ".";
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
if($opts{srcdir}){
    $srcdir = $opts{srcdir};
}
if($opts{moddir}){
    $moddir = $opts{moddir};
}
if($opts{prefix}){
    $prefix = $opts{prefix};
}
if($srcdir ne "."){
    chdir $srcdir or die "can't chdir $srcdir\n";
}
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if($need_save_args){
    my $t = join(' ', @ARGV);
    open Out, ">mymake/args" or die "Can't write mymake/args.\n";
    print Out $t;
    close Out;
    system "rm -f mymake/Makefile.orig";
    system "rm -f src/mpl/include/mplconfig.h src/openpa/src/opa_config.h";
}
my $dir="src/pm/hydra";
my $srcdir="../../..";
chdir $dir or die "Can't chdir $dir\n";
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if(!-f "mymake/Makefile.orig"){
    system "rsync -r $srcdir/confdb/ confdb/";
    system "cp $srcdir/maint/version.m4 .";
    my @mod_list;
    my $f = "configure.ac";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/^\s*HWLOC_/){
            next;
        }
        elsif($l=~/^(\s*)(PAC_CONFIG_SUBDIR.*)/){
            $l = "$1: \x23 $2\n";
        }
        print Out $l;
    }
    close Out;
    system "cp $m[2] $m[0]";
    my $f = "Makefile.am";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/ACLOCAL_AMFLAGS/){
            $l ="ACLOCAL_AMFLAGS = -I confdb\n";
        }
        print Out $l;
    }
    close Out;
    system "cp $m[2] $m[0]";
    my $flag;
    my $f = "tools/topo/hwloc/Makefile.mk";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    push @mod_list, \@m;
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/if\s+hydra_use_embedded_hwloc/){
            $flag=1;
            next;
        }
        elsif($l=~/endif/){
            $flag=0;
            next;
        }
        if($flag){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp $m[2] $m[0]";
    system "autoreconf -ivf";
    foreach my $m (@mod_list){
        system "cp $m->[1] $m->[0]";
    }
    system "rm -f Makefile";
    system "./configure";
    system "mv Makefile mymake/Makefile.orig";
}
my $bin="\x24(PREFIX)/bin";
$dst_hash{"LN_S-$bin/mpiexec"}="$bin/mpiexec.hydra";
$dst_hash{"LN_S-$bin/mpirun"}="$bin/mpiexec.hydra";
$I_list .= " -I../../../src/mpl/include";
$L_list .= " ../../../src/mpl/libmpl.la";
$I_list .= " -I$moddir/hwloc/include";
$L_list .= " $moddir/hwloc/hwloc/libhwloc_embedded.la";
push @CONFIGS, "$moddir/hwloc/include/hwloc/autogen/config.h";
my @t = ("cd $moddir/hwloc");
push @t, "\x24(DO_stage) Configure HWLOC";
push @t, "sh autogen.sh";
push @t, "./configure --enable-embedded-mode --enable-visibility";
push @extra_make_rules, "$moddir/hwloc/include/hwloc/autogen/config.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $moddir/hwloc");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$moddir/hwloc/hwloc/libhwloc_embedded.la: $moddir/hwloc/include/hwloc/autogen/config.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my $lt_opt;
if($opts{V}==0){
    $lt_opt = "--quiet";
}
%objects=();
my $tlist;
open In, "mymake/Makefile.orig" or die "Can't open mymake/Makefile.orig.\n";
while(<In>){
    if(/^(\w+)\s*=\s*(.*)/){
        my ($a, $b) = ($1, $2);
        $tlist=[];
        $objects{$a} = $tlist;
        my $done=1;
        if($b=~/\\$/){
            $done = 0;
            $b=~s/\s*\\$//;
        }
        if($b){
            push @$tlist, split /\s+/, $b;
        }
        if($done){
            undef $tlist;
        }
    }
    elsif($tlist){
        if(/\s*(.*)/){
            my ($b) = ($1);
            my $done=1;
            if($b=~/\\$/){
                $done = 0;
                $b=~s/\s*\\$//;
            }
            if($b){
                push @$tlist, split /\s+/, $b;
            }
            if($done){
                undef $tlist;
            }
        }
    }
}
close In;
open Out, ">mymake/Makefile.custom" or die "Can't write mymake/Makefile.custom.\n";
print "  --> [mymake/Makefile.custom]\n";
print Out "export MODDIR=$moddir\n";
print Out "PREFIX=$prefix\n";
print Out "\n";
if(@CONFIGS){
    print Out "CONFIGS = @CONFIGS\n";
    print Out "\n";
}
my $t = get_object("DEFS");
print Out "DEFS = $t\n";
my $t = get_object("DEFAULT_INCLUDES");
print Out "DEFAULT_INCLUDES = $t\n";
my $t = get_object("INCLUDES");
print Out "INCLUDES = $t\n";
my $t = get_object("AM_CPPFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
$t=~s/\s*-I\S*mpl\/include//g;
$t .= $I_list;
print Out "AM_CPPFLAGS = $t\n";
my $t = get_object("CPPFLAGS");
print Out "CPPFLAGS = $t\n";
my $t = get_object("AM_CFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
print Out "AM_CFLAGS = $t\n";
my $t = get_object("CFLAGS");
print Out "CFLAGS = $t\n";
my $t = get_object("AM_LDFLAGS");
print Out "AM_LDFLAGS = $t\n";
my $t = get_object("LDFLAGS");
print Out "LDFLAGS = $t\n";
my $t = get_object("LIBS");
print Out "LIBS = $t\n";
print Out "\n";
my $cc = get_object("CC");
my $ccld = get_object("CCLD");
my $LD="\x24(LINK)";
print Out "COMPILE = $cc \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) \x24(AM_CFLAGS) \x24(CFLAGS)\n";
print Out "LINK = $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
print Out "LTCC = /bin/sh ./libtool --mode=compile $lt_opt \x24(COMPILE)\n";
print Out "LTLD = /bin/sh ./libtool --mode=link $lt_opt \x24(LINK)\n";
print Out "\n";
my $tlist = get_list("lib_LTLIBRARIES");
foreach my $t (@$tlist){
    $dst_hash{$t} = "\x24(PREFIX)/lib";
}
my $tlist = get_list("bin_PROGRAMS");
foreach my $t (@$tlist){
    $dst_hash{$t} = "\x24(PREFIX)/bin";
}
my $tlist = get_list("PROGRAMS");
foreach my $t (@$tlist){
    push @programs, $t;
}
my $tlist = get_list("LTLIBRARIES");
foreach my $t (@$tlist){
    push @ltlibs, $t;
}
print Out "all: @ltlibs @programs\n";
print Out "\n";
my $cmd = "\x24(LTLD)";
if($opts{V}==0){
    $cmd = "\@echo LTLD \$\@ && $cmd";
}
foreach my $p (@ltlibs){
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my ($deps, $objs);
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if($special_targets{$a}){
        foreach my $t (@tlist){
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else{
        foreach my $t (@tlist){
            $t=~s/[^\/]+-//;
        }
    }
    my @t;
    foreach my $t (@tlist){
        if($t=~/^-l\w+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        print Out "    $t \\\n";
    }
    print Out "    $last_item\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LIBADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/\s*\S*\/libmpl.la\s*//g;
        $t=~s/-lhydra/libhydra.la/g;
        $t=~s/-lpm/libpm.la/g;
        $t .= $L_list;
        $t=~s/^\s+//;
        my @tlist = split /\s+/, $t;
        my @t;
        foreach my $t (@tlist){
            if($t=~/^-l\w+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            print Out "    $t \\\n";
        }
        print Out "    $last_item\n";
        if(@CONFIGS and "$add"=~/_OBJECTS$/){
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
    }
    $objs = "$deps $objs \x24(LIBS)";
    if($dst_hash{$p}=~/\/lib$/){
        my $opt="-rpath $dst_hash{$p}";
        if($opts{so_version}){
            $opt.=" -version-info $opts{so_version}";
        }
        $objs = "$opt $objs";
    }
    print Out "$p: $deps\n";
    print Out "\t$cmd -o \$\@ $objs\n";
    print Out "\n";
}
my $cmd = "\x24(LTLD)";
if($opts{V}==0){
    $cmd = "\@echo LTLD \$\@ && $cmd";
}
foreach my $p (@programs){
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my ($deps, $objs);
    my $o= "${a}_OBJECTS";
    my $tlist = get_list($o);
    my @tlist = sort @$tlist;
    if($special_targets{$a}){
        foreach my $t (@tlist){
            $t=~s/([^\/]+)-(\w+)/$2.$1/;
        }
    }
    else{
        foreach my $t (@tlist){
            $t=~s/[^\/]+-//;
        }
    }
    my @t;
    foreach my $t (@tlist){
        if($t=~/^-l\w+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        print Out "    $t \\\n";
    }
    print Out "    $last_item\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LDADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/\s*\S*\/libmpl.la\s*//g;
        $t=~s/-lhydra/libhydra.la/g;
        $t=~s/-lpm/libpm.la/g;
        $t .= $L_list;
        $t=~s/^\s+//;
        my @tlist = split /\s+/, $t;
        my @t;
        foreach my $t (@tlist){
            if($t=~/^-l\w+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            print Out "    $t \\\n";
        }
        print Out "    $last_item\n";
        if(@CONFIGS and "$add"=~/_OBJECTS$/){
            print Out "\x24($add): \x24(CONFIGS)\n";
        }
        $deps .= " \x24($add)";
    }
    if($objects{"${a}_CFLAGS"}){
        $cmd.= ' '. get_object("${a}_CFLAGS");
        $cmd .= " \x24(CFLAGS)";
    }
    if($objects{"${a}_LDFLAGS"}){
        $cmd.= ' '. get_object("${a}_LDFLAGS");
        $cmd .= " \x24(LDFLAGS)";
    }
    $objs = "$deps $objs \x24(LIBS)";
    if($dst_hash{$p}=~/\/lib$/){
        my $opt="-rpath $dst_hash{$p}";
        if($opts{so_version}){
            $opt.=" -version-info $opts{so_version}";
        }
        $objs = "$opt $objs";
    }
    print Out "$p: $deps\n";
    print Out "\t$cmd -o \$\@ $objs\n";
    print Out "\n";
}
print Out "\x23 --------------------\n";
foreach my $l (@extra_make_rules){
    print Out "$l\n";
}
print Out "\x23 --------------------\n";
print Out "%.o: %.c\n";
if($opts{V}==0){
    print Out "\t\@echo CC \$\@ && \x24(COMPILE) -c -o \$\@ \$<\n";
}
else{
    print Out "\t\x24(COMPILE) -c -o \$\@ \$<\n";
}
print Out "\n";
print Out "%.lo: %.c\n";
if($opts{V}==0){
    print Out "\t\@echo LTCC \$\@ && \x24(LTCC) -c -o \$\@ \$<\n";
}
else{
    print Out "\t\x24(LTCC) -c -o \$\@ \$<\n";
}
print Out "\n";
while (my ($k, $v) = each %special_targets){
    print Out "%.$k.lo: %.c\n";
    if($opts{V}==0){
        print Out "\t\@echo LTCC \$\@ && $v -c -o \$\@ \$<\n";
    }
    else{
        print Out "\t$v -c -o \$\@ \$<\n";
    }
    print Out "\n";
}
my (%dirs, @install_list, @lns_list);
while (my ($k, $v) = each %dst_hash){
    if($k=~/^LN_S-(.*)/){
        push @lns_list, "rm -f $1 && ln -s $v $1";
    }
    elsif($v){
        if(!$dirs{$v}){
            $dirs{$v} = 1;
        }
        if($v=~/\/lib$/){
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
        }
        elsif($v=~/\/bin$/){
            push @install_list, "install $k $v";
        }
    }
}
my $t1 = get_list("include_HEADERS");
my $t2 = get_list("nodist_include_HEADERS");
if(@$t1 or @$t2){
    $dirs{"$prefix/include"} = 1;
    my $t = join(' ', @$t1, @$t2);
    push @install_list, "cp $t $prefix/include";
}
my @install_list = sort @install_list;
foreach my $d (keys %dirs){
    unshift @install_list, "mkdir -p $d";
}
push @install_list, sort @lns_list;
if(@install_list){
    print Out "\x23 --------------------\n";
    print Out ".PHONY: install\n";
    print Out "install:\n";
    foreach my $l (@install_list){
        print Out "\t$l\n";
    }
    print Out "\n";
}
print Out "\x23 --------------------\n";
print Out ".PHONY: clean realclean realrealclean\n";
print Out "clean:\n";
print Out "\t(find . -name '*.o' -o -name '*.lo' -o -name '*.a' -o -name '*.la' |xargs rm -f)\n";
print Out "\n";
print Out "realclean: clean\n";
print Out "\t\x24(DO_clean)\n";
print Out "\n";
close Out;
system "rm -f Makefile";
system "ln -s mymake/Makefile.custom Makefile";
