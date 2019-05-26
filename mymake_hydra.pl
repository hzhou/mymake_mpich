#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir;
our $moddir;
our $prefix;
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

my $pwd=`pwd`;
chomp $pwd;
my $mymake;
if($0=~/^(\/.*)\//){
    $mymake = $1;
}
elsif($0=~/^(.*)\//){
    $mymake .= "$pwd/$1";
}
$mymake .="/mymake";
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
push @extra_make_rules, "DO_stage = perl $mymake\_stage.pl";
push @extra_make_rules, "DO_clean = perl $mymake\_clean.pl";
push @extra_make_rules, "";
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
    elsif($a=~/^--/){
        if($a=~/^--with-device=(.*)/){
            $opts{device}=$1;
            push @config_args, $a;
        }
        elsif($a=~/--(dis|en)able-.*tests/){
            push @test_config_args, $a;
        }
        elsif($a=~/--diable-(romio|fortran)/){
            push @config_args, $a;
            push @test_config_args, $a;
        }
        else{
            push @config_args, $a;
        }
    }
    elsif($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/){
        $opts{do}=$1;
    }
}
if($opts{CC}){
    $ENV{CC}=$opts{CC};
}
if($opts{CXX}){
    $ENV{CXX}=$opts{CXX};
}
if($opts{F77}){
    $ENV{F77}=$opts{F77};
}
if($opts{FC}){
    $ENV{FC}=$opts{FC};
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
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
elsif(-d "modules"){
    $moddir = "$pwd/modules";
}
elsif(-e "modules.tar.gz"){
    $moddir = "$pwd/modules";
    system "mkdir $moddir";
    system "tar -C $moddir xf modules.tar.gz";
    system "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir,g\"";
}
else{
    die "moddir not set\n";
}
if(-f "./maint/version.m4"){
    $srcdir = ".";
}
elsif(-f "../maint/version.m4"){
    $srcdir = "..";
}
elsif(-f "../../maint/version.m4"){
    $srcdir = "../..";
}
elsif(-f "../../../maint/version.m4"){
    $srcdir = "../../..";
}
if(!$srcdir){
    die "srcdir not set\n";
}
if(!$prefix){
    $prefix="$pwd/_inst";
    system "mkdir -p $prefix";
}
if($srcdir){
    my $dir="$srcdir/src/pm/hydra";
    chdir $dir or die "Can't chdir $dir\n";
}
if(!-d "mymake"){
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if(!-f "mymake/Makefile.orig"){
    if($srcdir){
        my $o="../../..";
        system "rsync -r $o/confdb/ confdb/";
        system "cp $o/maint/version.m4 .";
    }
    else{
        if(!-d "confdb"){
            die "hydra: missing confdb/\n";
        }
        if(!-f "version.m4"){
            die "hydra: missing version.m4\n";
        }
    }
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
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/^\s*hwloc\)/){
            print Out $l;
            $flag_skip=1;
            next;
        }
        elsif($flag_skip && $l=~/AC_MSG_RESULT/){
            $flag_skip=2;
        }
        elsif($flag_skip==2 && $l=~/^(\s*)if test.*\$have_hwloc.*then/){
            $l = $1."if true ; then\n";
            $flag_skip=0;
        }
        elsif($l=~/^(HWLOC_DO_AM_CONDITIONALS)/){
            $l = "\x23 $1";
        }
        elsif($l=~/^(\s*)(PAC_CONFIG_SUBDIR.*)/){
            $l = "$1: \x23 $2\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
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
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/ACLOCAL_AMFLAGS/){
            $l ="ACLOCAL_AMFLAGS = -I confdb\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    my $f = "tools/topo/Makefile.mk";
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
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/if\s+hydra_have_hwloc/){
            next;
        }
        elsif($l=~/endif/){
            next;
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
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
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/if\s+hydra_use_embedded_hwloc/){
            $flag_skip=1;
            next;
        }
        elsif($l=~/endif/){
            $flag_skip=0;
            next;
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    system "autoreconf -ivf";
    foreach my $m (@mod_list){
        system "cp $m->[1] $m->[0]";
    }
    system "rm -f Makefile";
    system "./configure";
    my @mod_list;
    my $f = "libtool";
    my $f_ = $f;
    $f_=~s/[\.\/]/_/g;
    my @m =($f, "mymake/$f_.orig", "mymake/$f_.mod");
    system "mv $m[0] $m[1]";
    my @lines;
    {
        open In, "$m[1]" or die "Can't open $m[1].\n";
        @lines=<In>;
        close In;
    }
    my $flag_skip=0;
    open Out, ">$m[2]" or die "Can't write $m[2].\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines){
        if($l=~/^AR_FLAGS=/){
            $l = "AR_FLAGS=\"cr\"\n";
        }
        if($flag_skip){
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    system "chmod a+x libtool";
    foreach my $m (@mod_list){
        system "cp $m->[1] $m->[0]";
    }
    system "mv Makefile mymake/Makefile.orig";
}
my $bin="\x24(PREFIX)/bin";
$dst_hash{"LN_S-$bin/mpiexec"}="$bin/mpiexec.hydra";
$dst_hash{"LN_S-$bin/mpirun"}="$bin/mpiexec.hydra";
if(!-d "$moddir/mpl"){
    my $cmd = "cp -r src/mpl $moddir/mpl";
    print "$cmd\n";
    system $cmd;
    my $cmd = "cp -r confdb $moddir/mpl/";
    print "$cmd\n";
    system $cmd;
}
$I_list .= " -I$moddir/mpl/include";
$L_list .= " $moddir/mpl/libmpl.la";
push @CONFIGS, "$moddir/mpl/include/mplconfig.h";
my $config_args = "--disable-versioning --enable-embedded";
foreach my $t (@config_args){
    if($t=~/--enable-g/){
        $config_args.=" $t";
    }
}
my @t = ("cd $moddir/mpl");
push @t, "\x24(DO_stage) Configure MPL";
push @t, "autoreconf -ivf";
push @t, "./configure $config_args";
push @extra_make_rules, "$moddir/mpl/include/mplconfig.h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $moddir/mpl");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$moddir/mpl/libmpl.la: $moddir/mpl/include/mplconfig.h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if(!-d "$moddir/hwloc"){
    my $cmd = "cp -r src/hwloc $moddir/hwloc";
    print "$cmd\n";
    system $cmd;
}
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
    my $l = "CONFIGS = @CONFIGS";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    print Out "\n";
}
my $t = get_object("DEFS");
my $l = "DEFS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("DEFAULT_INCLUDES");
my $l = "DEFAULT_INCLUDES = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("INCLUDES");
my $l = "INCLUDES = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CPPFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
$t=~s/\s*-I\S*mpl\/include//g;
$t .= $I_list;
my $l = "AM_CPPFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CPPFLAGS");
my $l = "CPPFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_CFLAGS");
$t=~s/\@HWLOC_\S+\@\s*//;
my $l = "AM_CFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("CFLAGS");
my $l = "CFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("AM_LDFLAGS");
my $l = "AM_LDFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LDFLAGS");
my $l = "LDFLAGS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
my $t = get_object("LIBS");
my $l = "LIBS = $t";
$l=~s/$moddir/\x24(MODDIR)/g;
print Out "$l\n";
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
        elsif($t=~/^-L\S+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        my $l = "    $t \\";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
    }
    my $l = "    $last_item";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LIBADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/\s*\S*\/libmpl.la//g;
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
            elsif($t=~/^-L\S+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            my $l = "    $t \\";
            $l=~s/$moddir/\x24(MODDIR)/g;
            print Out "$l\n";
        }
        my $l = "    $last_item";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
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
        elsif($t=~/^-L\S+/){
            $objs.=" $t";
        }
        else{
            push @t, $t;
        }
    }
    print Out "$o = \\\n";
    my $last_item = pop @t;
    foreach my $t (@t){
        my $l = "    $t \\";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
    }
    my $l = "    $last_item";
    $l=~s/$moddir/\x24(MODDIR)/g;
    print Out "$l\n";
    if(@CONFIGS and "$o"=~/_OBJECTS$/){
        print Out "\x24($o): \x24(CONFIGS)\n";
    }
    $deps .= " \x24($o)";
    my $add = $a."_LDADD";
    if($objects{$add}){
        my $t = get_object($add);
        $t=~s/\s*\S*\/libmpl.la//g;
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
            elsif($t=~/^-L\S+/){
                $objs.=" $t";
            }
            else{
                push @t, $t;
            }
        }
        print Out "$add = \\\n";
        my $last_item = pop @t;
        foreach my $t (@t){
            my $l = "    $t \\";
            $l=~s/$moddir/\x24(MODDIR)/g;
            print Out "$l\n";
        }
        my $l = "    $last_item";
        $l=~s/$moddir/\x24(MODDIR)/g;
        print Out "$l\n";
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
    $l=~s/$moddir/\x24(MODDIR)/g;
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
my (%dirs, @install_list, @install_deps, @lns_list);
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
            push @install_deps, $k;
        }
        elsif($v=~/\/bin$/){
            push @install_list, "/bin/sh ./libtool --mode=install $lt_opt install $k $v";
            push @install_deps, $k;
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
    print Out "install: @install_deps\n";
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
