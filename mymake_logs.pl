#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir;
our $moddir;
our $prefix;
my $pwd=`pwd`;
chomp $pwd;
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
    print "loading last ARGV: @ARGV\n";
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
        elsif($a=~/--disable-(romio|cxx|fortran)/){
            $opts{"disable_$1"}=1;
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
    my $cmd = "mkdir $moddir";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $moddir -xf modules.tar.gz";
    print "$cmd\n";
    system $cmd;
    my $cmd = "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir/ucx,g\"";
    print "$cmd\n";
    system $cmd;
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
my (@timer_states, %state_funcnames, %state_colors);
my @files;
foreach my $dir (qw(mpi mpi_t nameserv util binding include mpid pmi)){
    open In, "find src/$dir -name '*.[ch]' |" or die "Can't open find src/$dir -name '*.[ch]' |.\n";
    while(<In>){
        chomp;
        push @files, $_;
    }
    close In;
}
foreach my $f (@files){
    my $funcname;
    open In, "$f" or die "Can't open $f.\n";
    while(<In>){
        if(/^\w[^(]* \*?(\w+)\s*\(/){
            $funcname=$1;
        }
        elsif(/^(\w+)\s*\(/){
            $funcname=$1;
        }
        elsif(!$funcname and /^\s+\w[^(]* \*?(\w+)\s*\(/){
            $funcname=$1;
        }
        elsif(/^}/){
            undef $funcname;
        }
        elsif(/^\s*MPIR_FUNC_\w+_STATE_DECL\(\s*(\S+)\s*\)/){
            my ($state) = ($1);
            if($state eq "FUNCNAME"){
                next;
            }
            if(!$funcname){
                print "$f:$state\n";
                $state_funcnames{$state}="__func__";
            }
            else{
                $state_funcnames{$state}=$funcname;
            }
            push @timer_states, $state;
        }
    }
    close In;
}
my @timer_states = sort @timer_states;
my $n = @timer_states;
open Out, ">src/include/mpiallstates.h" or die "Can't write src/include/mpiallstates.h.\n";
print "  --> [src/include/mpiallstates.h]\n";
print Out "#ifndef MPIALLSTATES_H_INCLUDED\n";
print Out "#define MPIALLSTATES_H_INCLUDED\n";
print Out "\n";
print Out "/* $n total states */\n";
print Out "enum MPID_TIMER_STATE {\n";
foreach my $t (@timer_states){
    print Out "     $t,\n";
}
print Out "     MPID_NUM_TIMER_STATES\n";
print Out "};\n";
print Out "#endif /* MPIALLSTATES_H_INCLUDED */\n";
close Out;
open Out, ">src/util/logging/common/state_names.h" or die "Can't write src/util/logging/common/state_names.h.\n";
print "  --> [src/util/logging/common/state_names.h]\n";
print Out "#ifndef STATE_NAMES_H_INCLUDED\n";
print Out "#define STATE_NAMES_H_INCLUDED\n";
print Out "\n";
print Out "#include \"mpiallstates.h\"\n";
print Out "\n";
print Out "typedef struct {\n";
print Out "    int state;\n";
print Out "    const char *funcname;\n";
print Out "    const char *color;\n";
print Out "} MPIU_State_defs;\n";
print Out "\n";
print Out "static MPIU_State_defs mpich_states[] = {\n";
foreach my $t (@timer_states){
    print Out "    { $t, \"$state_funcnames{$t}\", NULL },\n";
}
print Out "\"    { -1, NULL, NULL }\n";
print Out "};\n";
print Out "#endif /* STATE_NAMES_H_INCLUDED */\n";
close Out;
