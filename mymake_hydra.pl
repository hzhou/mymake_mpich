#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our @config_args;
our $do_hydra2;
our %objects;
our @programs;
our @ltlibs;
our @CONFIGS;
our $I_list;
our $L_list;
our @extra_make_rules;
our %dst_hash;
our %special_targets;
our @extra_DEFS;
our @extra_INCLUDES;
our %config_cflags;
our %config_ldflags;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
if ($0=~/^(\/.*)\//) {
    $opts{mymake} = $1;
}
elsif ($0=~/^(.*)\//) {
    $opts{mymake} .= "$pwd/$1";
}
$opts{mymake} .="/mymake";
if (!-d "mymake") {
    mkdir "mymake" or die "can't mkdir mymake\n";
}
push @extra_make_rules, "DO_stage = perl $opts{mymake}_stage.pl";
push @extra_make_rules, "DO_clean = perl $opts{mymake}_clean.pl";
push @extra_make_rules, "";
if (!-f "maint/version.m4") {
    die "Not in top_srcdir.\n";
}
$opts{V}=0;
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
    if ($a=~/^-(quick|f08|noclean|sh)/) {
        $opts{$1}=1;
    }
    elsif ($a=~/^--(.*?)=(.*)/) {
        my ($o, $v) = ($1, $2);
        $opts{$1}=$2;
        if ($v eq "no") {
            if ($o=~/^with-(.*)/) {
                $opts{"without-$1"} = 1;
            }
            elsif ($o=~/^enable-(.*)/) {
                $opts{"disable-$1"} = 1;
            }
        }
    }
    elsif ($a=~/^--(.*)/) {
        $opts{$1}=1;
    }
    elsif ($a=~/^(\w+)=(.*)/) {
        $opts{$1}=$2;
    }
    if ($a=~/^--(prefix)=(.*)/) {
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
        elsif ($a=~/--with-(argobots)=(.*)/) {
            $opts{$1}=$2;
            push @config_args, $a;
        }
        else {
            push @config_args, $a;
        }
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
if (!$opts{prefix}) {
    $opts{prefix}="$pwd/_inst";
    system "mkdir -p $opts{prefix}";
}
my $mod_tarball;
if ($ENV{MODTARBALL}) {
    $mod_tarball = $ENV{MODTARBALL};
}
elsif (-e "modules.tar.gz") {
    $mod_tarball = "modules.tar.gz";
}
elsif (-e "modules-yaksa-new.tar.gz") {
    $mod_tarball = "modules-yaksa-new.tar.gz";
}
elsif (-e "modules-gpu.tar.gz") {
    $mod_tarball = "modules-gpu.tar.gz";
}
if ($mod_tarball =~/modules\.tar\.gz$/) {
    if ($opts{"with-cuda"} && $mod_tarball) {
        $mod_tarball=~s/modules.*\.tar\.gz/modules-gpu.tar.gz/;
    }
    if (!-e $mod_tarball) {
        print "$mod_tarball not found! Using module.tar.gz.\n";
        $mod_tarball = "modules.tar.gz";
    }
}
if ($ENV{MODDIR}) {
    $opts{moddir} = Cwd::abs_path($ENV{MODDIR});
}
elsif (-e "mymake/skip_tarball") {
    $opts{moddir} = "$pwd/mymake";
}
elsif (-e $mod_tarball) {
    $opts{moddir} = "$pwd/mymake";
    my $cmd = "mkdir -p $opts{moddir}";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $opts{moddir} -xf $mod_tarball";
    print "$cmd\n";
    system $cmd;
    system "touch mymake/skip_tarball";
}
else {
    die "moddir not set\n";
}

my $uname = `uname`;
$opts{uname} = $uname;
if ($uname=~/Darwin/) {
    $opts{do_pmpi} = 1;
}
if (-f "mymake/CFLAGS") {
    open In, "mymake/CFLAGS" or die "Can't open mymake/CFLAGS: $!\n";
    while(<In>){
        if (/(.+)/) {
            $ENV{CFLAGS} = $1;
        }
        if (/(-fsanitize=\w+)/) {
            $ENV{LDFLAGS} = $1;
        }
    }
    close In;
}
if ($opts{pm} eq "hydra2") {
    print "Building hydra2...\n";
    $do_hydra2 = 1;
}

my $dir="src/pm/hydra";
if ($do_hydra2) {
    $dir="src/pm/hydra2";
}
chdir $dir or die "Can't chdir $dir\n";
my $srcdir = "../../..";
$pwd = getcwd();

if (!-d "mymake") {
    mkdir "mymake" or die "can't mkdir mymake\n";
}
if (!-f "mymake/Makefile.orig") {
    system "rsync -r $srcdir/confdb/ confdb/";
    system "cp $srcdir/maint/version.m4 .";

    my @mod_list;
    if ($do_hydra2) {
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
        open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines) {
            if ($l=~/^\s*HWLOC_/) {
                next;
            }
            elsif ($l=~/^(\s*)(PAC_CONFIG_SUBDIR|PAC_CONFIG_ALL_SUBDIRS|PAC_CONFIG_MPL)/) {
                next;
            }
            elsif ($l=~/^(\s*)PAC_CONFIG_HWLOC/) {
                $l = "$1"."pac_have_hwloc=yes\n";
            }
            if ($flag_skip) {
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
    else {
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
        open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
        print "  --> [$m[2]]\n";
        foreach my $l (@lines) {
            if ($l=~/^\s*HWLOC_/) {
                next;
            }
            elsif ($l=~/^(\s*)(PAC_CONFIG_SUBDIR|PAC_CONFIG_ALL_SUBDIRS|PAC_CONFIG_MPL)/) {
                next;
            }
            elsif ($l=~/^(\s*)PAC_CONFIG_HWLOC/) {
                $l = "$1"."pac_have_hwloc=yes\n";
            }
            if ($flag_skip) {
                next;
            }
            print Out $l;
        }
        close Out;
        system "cp -v $m[2] $m[0]";
    }
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/ACLOCAL_AMFLAGS/) {
            $l ="ACLOCAL_AMFLAGS = -I confdb\n";
        }
        if ($flag_skip) {
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";

    my $hwloc_mk = "tools/topo/hwloc/Makefile.mk";
    if (-f "lib/$hwloc_mk") {
        $hwloc_mk = "lib/$hwloc_mk";
    }
    if ($do_hydra2) {
        $hwloc_mk = "libhydra/topo/hwloc/Makefile.mk";
    }
    my $f = "$hwloc_mk";
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
    open Out, ">$m[2]" or die "Can't write $m[2]: $!\n";
    print "  --> [$m[2]]\n";
    foreach my $l (@lines) {
        if ($l=~/if\s+HYDRA_USE_EMBEDDED_HWLOC/i) {
            $flag_skip=1;
            next;
        }
        elsif ($l=~/endif/) {
            $flag_skip=0;
            next;
        }
        if ($flag_skip) {
            next;
        }
        print Out $l;
    }
    close Out;
    system "cp -v $m[2] $m[0]";
    system "autoreconf -ivf";
    foreach my $m (@mod_list) {
        system "cp $m->[1] $m->[0]";
    }
    system "rm -f Makefile";
    system "./configure";
    my (@lines, $flag);
    open In, "include/hydra_config.h" or die "Can't open include/hydra_config.h: $!\n";
    while(<In>){
        if (/#define HYDRA_DEFAULT_TOPOLIB NULL/) {
            push @lines, "#define HYDRA_DEFAULT_TOPOLIB \"hwloc\"\n";
            $flag = 1;
        }
        else {
            push @lines, $_;
        }
    }
    close In;
    if ($flag) {
        open Out, ">include/hydra_config.h" or die "Can't write include/hydra_config.h: $!\n";
        print "  --> [include/hydra_config.h]\n";
        foreach my $l (@lines) {
            print Out "$l\n";
        }
        close Out;
    }
    system "mv libtool mymake/libtool.orig";
    my %need_patch;
    my @lines;
    {
        open In, "mymake/libtool.orig" or die "Can't open mymake/libtool.orig.\n";
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
    system "mv Makefile mymake/Makefile.orig";
}

my $bin="\x24(PREFIX)/bin";
$dst_hash{"LN_S-$bin/mpiexec"}="$bin/mpiexec.hydra";
$dst_hash{"LN_S-$bin/mpirun"}="$bin/mpiexec.hydra";

my $L=$opts{"with-mpl_hydra"};
if ($L and -d $L) {
    $I_list .= " -I$L/include";
    $L_list .= " -L$L/lib -lmpl_hydra";
}
else {
    push @CONFIGS, "../../../src/mpl/include/mplconfig.h";
    $I_list .= " -I../../../src/mpl/include";
    $L_list .= " ../../../src/mpl/libmpl.la";
}
push @extra_make_rules, "../../../src/mpl/libmpl.la:";
push @extra_make_rules, "\t\x24(MAKE) -C ../../.. src/mpl/libmpl.la";
my $L=$opts{"with-hwloc"};
if ($L and -d $L) {
    $I_list .= " -I$L/include";
    $L_list .= " -L$L/lib -lhwloc";
}
else {
    push @CONFIGS, "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
    $I_list .= " -I\x24(MODDIR)/hwloc/include";
    $L_list .= " \x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
}
my $configure = "./configure --enable-embedded-mode --enable-visibility";
my $subdir="\x24(MODDIR)/hwloc";
my $lib_la = "\x24(MODDIR)/hwloc/hwloc/libhwloc_embedded.la";
my $config_h = "\x24(MODDIR)/hwloc/include/hwloc/autogen/config.h";
my @t = ("cd $subdir");
push @t, "\x24(DO_stage) Configure HWLOC";
if (-f "$opts{moddir}/hwloc/autogen.sh") {
    push @t, "sh autogen.sh";
}
else {
    push @t, "autoreconf -ivf";
}
push @t, "$configure";
push @t, "cp $pwd/libtool .";
push @extra_make_rules, "$config_h: ";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
my @t = ("cd $subdir");
push @t, "\x24(MAKE)";
push @extra_make_rules, "$lib_la: $config_h";
push @extra_make_rules, "\t(".join(' && ', @t).")";
push @extra_make_rules, "";
if ($opts{argobots}) {
    $I_list .= " -I$opts{argobots}/include";
    $L_list .= " -L$opts{argobots}/lib -labt";
}
if ($opts{argobots}) {
    $I_list .= " -I$opts{argobots}/include";
}
%objects=();
my $tlist;
open In, "mymake/Makefile.orig" or die "Can't open mymake/Makefile.orig: $!\n";
while(<In>){
    if (/^(\w+)\s*=\s*(.*)/) {
        my ($a, $b) = ($1, $2);
        $tlist=[];
        $objects{$a} = $tlist;

        my $done=1;
        if ($b=~/\\$/) {
            $done = 0;
            $b=~s/\s*\\$//;
        }

        if ($b) {
            push @$tlist, split /\s+/, $b;
        }
        if ($done) {
            undef $tlist;
        }
    }
    elsif ($tlist) {
        if (/\s*(.*)/) {
            my ($b) = ($1);
            my $done=1;
            if ($b=~/\\$/) {
                $done = 0;
                $b=~s/\s*\\$//;
            }

            if ($b) {
                push @$tlist, split /\s+/, $b;
            }
            if ($done) {
                undef $tlist;
            }
        }
    }
}
close In;
$objects{MODDIR}="-";
$objects{PREFIX}="-";

my $tlist = get_list("lib_LTLIBRARIES");
foreach my $t (@$tlist) {
    $dst_hash{$t} = "\x24(PREFIX)/lib";
}
my $tlist = get_list("bin_PROGRAMS");
foreach my $t (@$tlist) {
    $dst_hash{$t} = "\x24(PREFIX)/bin";
}
my $tlist = get_list("PROGRAMS");
foreach my $t (@$tlist) {
    push @programs, $t;
}

my $tlist = get_list("LTLIBRARIES");
foreach my $t (@$tlist) {
    push @ltlibs, $t;
}

foreach my $p (@ltlibs) {
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my $add = $a."_LIBADD";
    my $t = get_make_var($add);
    $t=~s/(\S+\/)?(mpl|openpa|izem|hwloc|yaksa|json-c|libfabric|ucx)\/\S+\.la\s*//g;
    $t=~s/-lhydra/libhydra.la/g;
    $t=~s/-lpm/libpm.la/g;

    if ($add=~/libhydra.*_la/) {
        $t.= $L_list;
    }
    $objects{$add} = $t;
}
foreach my $p (@programs) {
    my $a = $p;
    $a=~s/[\.\/]/_/g;
    my $add = $a."_LDADD";
    my $t = get_make_var($add);
    $t=~s/(\S+\/)?(mpl|openpa|izem|hwloc|yaksa|json-c|libfabric|ucx)\/\S+\.la\s*//g;
    $t=~s/-lhydra/libhydra.la/g;
    $t=~s/-lpm/libpm.la/g;

    $objects{$add} = $t;
}
dump_makefile("mymake/Makefile.custom", "../../../mymake");

system "rm -f Makefile";
system "ln -s mymake/Makefile.custom Makefile";

# ---- subroutines --------------------------------------------
sub get_list {
    my ($key) = @_;
    my @t;
    my $tlist = $objects{$key};
    foreach my $t (@{$objects{$key}}) {
        if ($t=~/^\$\((\w+)\)$/) {
            my $L = get_list($1);
            push @t, @$L;
        }
        else {
            $t=~s/\$\((\w+)\)/get_make_var($1)/ge;
            push @t, $t;
        }
    }
    return \@t;
}

sub get_make_var {
    my ($name) = @_;
    my $t = $objects{$name};
    if ($t eq "-") {
        return "\x24($name)";
    }
    if (defined $t) {
        if (ref($t) eq "ARRAY") {
            $t = join(' ', @$t);
        }
        $t=~s/\$\((\w+)\)/get_make_var($1)/ge;
        $t=~s/\s+/ /g;

        $t=~s/$opts{moddir}/\x24(MODDIR)/g;
        return $t;
    }
    elsif ($name=~/^am__v_\w+/) {
        return "";
    }
    else {
        return "";
    }
}

sub dump_makefile {
    my ($makefile, $moddir) = @_;

    my ($lt, $lt_opt);
    $lt = get_make_var("LIBTOOL");
    if (!$opts{V}) {
        $lt_opt = "--quiet";
    }

    open Out, ">$makefile" or die "Can't write $makefile: $!\n";
    print "  --> [$makefile]\n";
    print Out "PREFIX=$opts{prefix}\n";
    if ($moddir) {
        print Out "MODDIR=$moddir\n";
    }
    print Out "\n";
    print Out "CONFIGS = @CONFIGS\n";
    print Out "\n";
    my $t = get_make_var_unique("DEFS");
    $t .= " @extra_DEFS";
    print Out "DEFS = $t\n";
    my $t = get_make_var_unique("DEFAULT_INCLUDES");
    print Out "DEFAULT_INCLUDES = $t\n";
    my $t = get_make_var_unique("INCLUDES");
    $t .= " @extra_INCLUDES";
    print Out "INCLUDES = $t\n";
    my $t = get_make_var_unique("AM_CPPFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
    $t=~s/-I\S+\/ucx\/src//g;
    $t=~s/-I\S+\/json-c//g;
    print Out "AM_CPPFLAGS = $t\n";
    my $t = get_make_var_unique("CPPFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    $t=~s/-I\S+\/(mpl|openpa|romio|izem|hwloc|yaksa|libfabric)\/\S+\s*//g;
    $t=~s/-I\S+\/ucx\/src//g;
    $t=~s/-I\S+\/json-c//g;
    if ($opts{"with-cuda"}) {
        my $p = $opts{"with-cuda"};
        $I_list .= " -I$p/include";
    }
    $t .= $I_list;
    print Out "CPPFLAGS = $t\n";
    my $t = get_make_var_unique("AM_CFLAGS");
    $t=~s/\@HWLOC_\S+\@\s*//;
    print Out "AM_CFLAGS = $t\n";
    my $t = get_make_var_unique("CFLAGS");
    if (%config_cflags) {
        my @tlist = split /\s+/, $t;
        foreach my $a (@tlist) {
            if ($a=~/-O(\d+)/) {
                if (!defined $config_cflags{O}) {
                    $config_cflags{O} = $1;
                }
            }
            elsif (!$config_cflags{$a}) {
                $config_cflags{$a} = 1;
            }
        }
        my @tlist;
        foreach my $a (keys %config_cflags) {
            if ($a eq "O") {
                push @tlist, "-O$config_cflags{O}";
            }
            else {
                push @tlist, $a;
            }
        }
        $t = join(' ', sort @tlist);
        print(STDOUT "  -->  CFLAGS = $t\n");
    }
    print Out "CFLAGS = $t\n";
    my $t = get_make_var_unique("AM_LDFLAGS");
    print Out "AM_LDFLAGS = $t\n";
    my $t = get_make_var_unique("LDFLAGS");
    if (%config_ldflags) {
        my @tlist = split /\s+/, $t;
        foreach my $a (@tlist) {
            if (!$config_ldflags{$a}) {
                $config_ldflags{$a} = 1;
            }
        }
        $t = join ' ', sort keys %config_ldflags;
        print(STDOUT "  -->  LDFLAGS = $t\n");
    }
    print Out "LDFLAGS = $t\n";
    my $t = get_make_var_unique("LIBS");
    print Out "LIBS = $t\n";
    print Out "\n";

    my $cc = get_make_var("CC");
    my $ccld = get_make_var("CCLD");

    print Out "COMPILE = $cc \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) \x24(AM_CFLAGS) \x24(CFLAGS)\n";
    print Out "LINK = $ccld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
    if ($lt) {
        print Out "LTCC = $lt --mode=compile $lt_opt \x24(COMPILE)\n";
        print Out "LTLD = $lt --mode=link $lt_opt \x24(LINK)\n";
    }
    print Out "\n";
    if (!$opts{disable_cxx}) {
        my $cxx = get_make_var("CXX");
        my $cxxld = get_make_var("CXXLD");
        my $flags = get_make_var("CXXFLAGS");
        my $am_flags = get_make_var("AM_CXXFLAGS");
        print Out "CXXCOMPILE = $cxx \x24(DEFS) \x24(DEFAULT_INCLUDES) \x24(INCLUDES) \x24(AM_CPPFLAGS) \x24(CPPFLAGS) $flags $am_flags\n";
        print Out "CXXLINK = $cxxld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        if ($lt) {
            print Out "LTCXX = $lt --mode=compile $lt_opt --tag=CXX \x24(CXXCOMPILE)\n";
            print Out "CXXLD = $lt --mode=link $lt_opt --tag=CXX $cxxld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        }
        print Out "\n";
    }
    if (!$opts{disable_fortran}) {
        my $fc = get_make_var("FC");
        my $flags = get_make_var("FCFLAGS");
        my $am_flags = get_make_var("AM_FCFLAGS");
        $flags.=" $am_flags";
        if ($flags=~/-I(\S+)/) {
            my ($modpath) = ($1);
            if ($fc =~/^(pgfortran|ifort)/) {
                $flags.=" -module $modpath";
            }
            elsif ($fc =~/^sunf\d+/) {
                $flags.=" -moddir=$modpath";
            }
            elsif ($fc =~/^af\d+/) {
                $flags.=" -YMOD_OUT_DIR=$modpath";
            }
            else {
                $flags.=" -J$modpath";
            }
        }
        print Out "FCCOMPILE = $fc $flags\n";
        if ($lt) {
            print Out "LTFC = $lt --mode=compile $lt_opt --tag=FC \x24(FCCOMPILE)\n";

            my $ld = get_make_var("FCLD");
            print Out "FCLD = $lt --mode=link $lt_opt --tag=FC $ld \x24(AM_LDFLAGS) \x24(LDFLAGS)\n";
        }
        print Out "\n";
    }

    foreach my $target (@ltlibs, @programs) {
        if ($target=~/^(lib|bin)\//) {
            $dst_hash{$target} = "\x24(PREFIX)/$1";
        }
    }

    print Out "all: @ltlibs @programs\n";
    print Out "\n";
    my %rules_ADD;
    if (@ltlibs) {
        foreach my $p (@ltlibs) {
            my $ld = "LINK";
            if ($lt) {
                $ld = "LTLD";
            }
            if ($p=~/libmpifort.la/) {
                $ld = "FCLD";
            }
            elsif ($p=~/libmpicxx.la/) {
                $ld = "CXXLD";
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/[\.\/]/_/g;

            my ($deps, $objs);
            my $t_cppflags = get_make_var("${a}_CPPFLAGS");
            my $o= "${a}_OBJECTS";
            my $tlist = get_make_objects($p);
            if ($special_targets{$a}) {
                foreach my $t (@$tlist) {
                    $t=~s/\.(l?o)$/.$a.$1/;
                }
            }

            my @t;
            foreach my $t (@$tlist) {
                if ($t=~/^-l\w+/) {
                    $objs.=" $t";
                }
                elsif ($t=~/^-L\S+/) {
                    $objs.=" $t";
                }
                else {
                    if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                        my $obj=$1;
                        if ($obj ne $a) {
                            $obj .= "_$a";
                            $t = "$obj.o";
                        }
                        print Out "$t: $1.c\n";
                        print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                    }
                    push @t, $t;
                }
            }

            if ($rules_ADD{$o}) {
                $deps .= " \x24($o)";
            }
            elsif ($#t > 1) {

                my $last_item = pop @t;
                if ($last_item) {
                    print Out "$o = \\\n";
                    foreach my $t (@t) {
                        if ($t) {
                            print Out "    $t \\\n";
                        }
                    }
                    print Out "    $last_item\n";
                }
                else {
                    print Out "$o =\n";
                }
                print Out "\n";

                if (@CONFIGS and "$o"=~/_OBJECTS$/) {
                    print Out "\x24($o): \x24(CONFIGS)\n";
                }
                $rules_ADD{$o} = 1;
                $deps .= " \x24($o)";
            }
            else {
                if ($o=~/_OBJECTS/) {
                    foreach my $t (@t) {
                        print Out "$t: \x24(CONFIGS)\n";
                    }
                }
                $deps .= " @t";
            }
            my $add = $a."_LIBADD";
            my $t = get_make_var($add);
            if (!$t) {
                $add = "LIBADD";
                $t = get_make_var($add);
            }

            if ($t) {
                $t=~s/^\s+//;
                my @tlist = split /\s+/, $t;
                my @t;
                foreach my $t (@tlist) {
                    if ($t=~/^-l\w+/) {
                        $objs.=" $t";
                    }
                    elsif ($t=~/^-L\S+/) {
                        $objs.=" $t";
                    }
                    else {
                        if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                            my $obj=$1;
                            if ($obj ne $a) {
                                $obj .= "_$a";
                                $t = "$obj.o";
                            }
                            print Out "$t: $1.c\n";
                            print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                        }
                        push @t, $t;
                    }
                }

                if ($rules_ADD{$add}) {
                    $deps .= " \x24($add)";
                }
                elsif ($#t > 1) {

                    my $last_item = pop @t;
                    if ($last_item) {
                        print Out "$add = \\\n";
                        foreach my $t (@t) {
                            if ($t) {
                                print Out "    $t \\\n";
                            }
                        }
                        print Out "    $last_item\n";
                    }
                    else {
                        print Out "$add =\n";
                    }
                    print Out "\n";

                    if (@CONFIGS and "$add"=~/_OBJECTS$/) {
                        print Out "\x24($add): \x24(CONFIGS)\n";
                    }
                    $rules_ADD{$add} = 1;
                    $deps .= " \x24($add)";
                }
                else {
                    if ($add=~/_OBJECTS/) {
                        foreach my $t (@t) {
                            print Out "$t: \x24(CONFIGS)\n";
                        }
                    }
                    $deps .= " @t";
                }
            }

            $objs = "$deps $objs \x24(LIBS)";

            if ($dst_hash{$p}=~/\/lib$/) {
                my $opt="-rpath $dst_hash{$p}";
                if ($opts{so_version}) {
                    $opt.=" -version-info $opts{so_version}";
                }
                $objs = "$opt $objs";
            }

            print Out "$p: $deps\n";
            print Out "\t$cmd -o \$\@ $objs\n";
            print Out "\n";
        }

    }
    if (@programs) {
        foreach my $p (@programs) {
            my $ld = "LINK";
            if ($lt) {
                $ld = "LTLD";
            }
            if ($p=~/libmpifort.la/) {
                $ld = "FCLD";
            }
            elsif ($p=~/libmpicxx.la/) {
                $ld = "CXXLD";
            }
            my $cmd = "\x24($ld)";
            if ($opts{V}==0) {
                $cmd = "\@echo $ld \$\@ && $cmd";
            }

            my $a = $p;
            $a=~s/[\.\/]/_/g;

            my ($deps, $objs);
            my $t_cppflags = get_make_var("${a}_CPPFLAGS");
            my $o= "${a}_OBJECTS";
            my $tlist = get_make_objects($p, 1);
            if ($special_targets{$a}) {
                foreach my $t (@$tlist) {
                    $t=~s/\.(l?o)$/.$a.$1/;
                }
            }

            my @t;
            foreach my $t (@$tlist) {
                if ($t=~/^-l\w+/) {
                    $objs.=" $t";
                }
                elsif ($t=~/^-L\S+/) {
                    $objs.=" $t";
                }
                else {
                    if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                        my $obj=$1;
                        if ($obj ne $a) {
                            $obj .= "_$a";
                            $t = "$obj.o";
                        }
                        print Out "$t: $1.c\n";
                        print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                    }
                    push @t, $t;
                }
            }

            if ($rules_ADD{$o}) {
                $deps .= " \x24($o)";
            }
            elsif ($#t > 1) {

                my $last_item = pop @t;
                if ($last_item) {
                    print Out "$o = \\\n";
                    foreach my $t (@t) {
                        if ($t) {
                            print Out "    $t \\\n";
                        }
                    }
                    print Out "    $last_item\n";
                }
                else {
                    print Out "$o =\n";
                }
                print Out "\n";

                if (@CONFIGS and "$o"=~/_OBJECTS$/) {
                    print Out "\x24($o): \x24(CONFIGS)\n";
                }
                $rules_ADD{$o} = 1;
                $deps .= " \x24($o)";
            }
            else {
                if ($o=~/_OBJECTS/) {
                    foreach my $t (@t) {
                        print Out "$t: \x24(CONFIGS)\n";
                    }
                }
                $deps .= " @t";
            }
            my $add = $a."_LDADD";
            my $t = get_make_var($add);
            if (!$t) {
                $add = "LDADD";
                $t = get_make_var($add);
            }

            if ($t) {
                $t=~s/^\s+//;
                my @tlist = split /\s+/, $t;
                my @t;
                foreach my $t (@tlist) {
                    if ($t=~/^-l\w+/) {
                        $objs.=" $t";
                    }
                    elsif ($t=~/^-L\S+/) {
                        $objs.=" $t";
                    }
                    else {
                        if ($t_cppflags and $t=~/(.*\w+)\.o/) {
                            my $obj=$1;
                            if ($obj ne $a) {
                                $obj .= "_$a";
                                $t = "$obj.o";
                            }
                            print Out "$t: $1.c\n";
                            print Out "\t\@echo CC \$\@ && \x24(COMPILE) $t_cppflags -c -o \$\@ \$<\n";
                        }
                        push @t, $t;
                    }
                }

                if ($rules_ADD{$add}) {
                    $deps .= " \x24($add)";
                }
                elsif ($#t > 1) {

                    my $last_item = pop @t;
                    if ($last_item) {
                        print Out "$add = \\\n";
                        foreach my $t (@t) {
                            if ($t) {
                                print Out "    $t \\\n";
                            }
                        }
                        print Out "    $last_item\n";
                    }
                    else {
                        print Out "$add =\n";
                    }
                    print Out "\n";

                    if (@CONFIGS and "$add"=~/_OBJECTS$/) {
                        print Out "\x24($add): \x24(CONFIGS)\n";
                    }
                    $rules_ADD{$add} = 1;
                    $deps .= " \x24($add)";
                }
                else {
                    if ($add=~/_OBJECTS/) {
                        foreach my $t (@t) {
                            print Out "$t: \x24(CONFIGS)\n";
                        }
                    }
                    $deps .= " @t";
                }
            }
            my $t = get_make_var("${a}_CFLAGS");
            if ($t) {
                $cmd.= " $t";
                $cmd .= " \x24(CFLAGS)";
            }
            my $t = get_make_var("${a}_LDFLAGS");
            if ($t) {
                $cmd.= " $t";
                $cmd .= " \x24(LDFLAGS)";
            }

            $objs = "$deps $objs \x24(LIBS)";

            if ($dst_hash{$p}=~/\/lib$/) {
                my $opt="-rpath $dst_hash{$p}";
                if ($opts{so_version}) {
                    $opt.=" -version-info $opts{so_version}";
                }
                $objs = "$opt $objs";
            }

            print Out "$p: $deps\n";
            print Out "\t$cmd -o \$\@ $objs\n";
            print Out "\n";
        }

    }

    print Out "\x23 --------------------\n";
    foreach my $l (@extra_make_rules) {
        print Out "$l\n";
    }
    print Out "\x23 --------------------\n";
    print Out "%.o: %.c\n";
    if ($opts{V}==0) {
        print Out "\t\@echo CC \$\@ && \x24(COMPILE) -c -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(COMPILE) -c -o \$\@ \$<\n";
    }
    print Out "\n";
    print Out "%.i: %.c\n";
    if ($opts{V}==0) {
        print Out "\t\@echo CC -E \$\@ && \x24(COMPILE) -E -o \$\@ \$<\n";
    }
    else {
        print Out "\t\x24(COMPILE) -E -o \$\@ \$<\n";
    }
    print Out "\n";
    if ($lt) {
        print Out "%.lo: %.c\n";
        if ($opts{V}==0) {
            print Out "\t\@echo LTCC \$\@ && \x24(LTCC) -c -o \$\@ \$<\n";
        }
        else {
            print Out "\t\x24(LTCC) -c -o \$\@ \$<\n";
        }
        print Out "\n";
        if (!$opts{disable_cxx}) {
            print Out "%.lo: %.cxx\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTCXX \$\@ && \x24(LTCXX) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTCXX) -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
        if (!$opts{disable_fortran}) {
            print Out "%.lo: %.f\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTFC \$\@ && \x24(LTFC) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTFC) -c -o \$\@ \$<\n";
            }
            print Out "\n";
            print Out "%.lo: %.f90\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTFC \$\@ && \x24(LTFC) -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t\x24(LTFC) -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
        while (my ($k, $v) = each %special_targets) {
            print Out "%.$k.lo: %.c\n";
            if ($opts{V}==0) {
                print Out "\t\@echo LTCC \$\@ && $v -c -o \$\@ \$<\n";
            }
            else {
                print Out "\t$v -c -o \$\@ \$<\n";
            }
            print Out "\n";
        }
    }
    my $t1 = get_make_var_list("include_HEADERS");
    my $t2 = get_make_var_list("nodist_include_HEADERS");
    my $t3 = get_make_var_list("modinc_HEADERS");
    if (@$t1 or @$t2 or @$t3) {
        foreach my $t (@$t1, @$t2, @$t3) {
            $t=~s/use_mpi_f08/use_mpi/;
            $dst_hash{$t} = "\x24(PREFIX)/include";
        }
    }

    my (%dirs, @install_list, @install_deps, @lns_list);
    foreach my $k (sort keys %dst_hash) {
        my $v = $dst_hash{$k};
        if ($k=~/^LN_S-(.*)/) {
            push @lns_list, "rm -f $1 && ln -s $v $1";
        }
        elsif ($v=~/noinst/) {
        }
        elsif ($v) {
            if (!$dirs{$v}) {
                $dirs{$v} = 1;
            }
            if ($v=~/\/lib$/) {
                push @install_list, "$lt --mode=install $lt_opt install $k $v";
                push @install_deps, $k;
            }
            elsif ($v=~/\/bin$/) {
                push @install_list, "$lt --mode=install $lt_opt install $k $v";
                push @install_deps, $k;
            }
            elsif ($v=~/\/include$/) {
                push @install_list, "cp $k $v";
            }
        }
    }

    foreach my $d (keys %dirs) {
        unshift @install_list, "mkdir -p $d";
    }
    push @install_list, sort @lns_list;

    if (@install_list) {
        print Out "\x23 --------------------\n";
        print Out ".PHONY: install\n";
        print Out "install: @install_deps\n";
        foreach my $l (@install_list) {
            print Out "\t$l\n";
        }
        print Out "\n";
    }
    print Out "\x23 --------------------\n";
    print Out ".PHONY: clean\n";
    print Out "clean:\n";
    print Out "\t(find src -name '*.o' -o -name '*.lo' -o -name '*.a' -o -name '*.la' |xargs rm -f)\n";
    print Out "\n";
    close Out;

}

sub get_make_var_unique {
    my ($name) = @_;
    my (@t, %cache);
    foreach my $k (split /\s+/, get_make_var($name)) {
        if (!$cache{$k}) {
            $cache{$k} = 1;
            push @t, $k;
        }
    }
    return join(' ', @t);
}

sub get_make_objects {
    my ($p) = @_;
    my $a = $p;
    $a=~s/[\.\/]/_/g;

    my $tlist = get_list("${a}_OBJECTS");
    my @tlist = sort @$tlist;
    foreach my $t (@tlist) {
        $t=~s/$a-//g;
    }
    return \@tlist;
}

sub get_make_var_list {
    my ($name) = @_;
    my (@tlist, %cache);
    foreach my $k (split /\s+/, get_make_var($name)) {
        if (!$k) {
            next;
        }
        if (!$cache{$k}) {
            $cache{$k} = 1;
            push @tlist, $k;
        }
    }
    return \@tlist;
}

