#!/usr/bin/perl
use strict;
our (%opts, @config_args);
our $srcdir = "$ENV{HOME}/work/mpich";
our $moddir = "$ENV{HOME}/work/modules";
our $prefix = "$ENV{HOME}/MPI";
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
    elsif($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/){
        $opts{do}=$1;
    }
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
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
if($opts{srcdir}){
    $srcdir = $opts{srcdir};
}
if($opts{moddir}){
    $moddir = $opts{moddir};
}
if($opts{prefix}){
    $prefix = $opts{prefix};
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
my %KnownErrRoutines = (
    'MPIR_Err_create_code'      => '5:3:1:1:4',
    'MPIO_Err_create_code'      => '5:3:1:0:-1',
    'MPIR_ERR_SET'              => '2:-1:0:1:1',
    'MPIR_ERR_SETSIMPLE'        => '2:-1:0:1:1',
    'MPIR_ERR_SET1'             => '2:-1:1:1:1',
    'MPIR_ERR_SET2'             => '2:-1:2:1:1',
    'MPIR_ERR_SETANDSTMT'       => '3:-1:0:1:1',
    'MPIR_ERR_SETANDSTMT1'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT2'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT3'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT4'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP'       => '2:-1:0:1:1',
    'MPIR_ERR_SETANDJUMP1'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP2'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP3'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP4'      => '2:-1:1:1:1',
    'MPIR_ERR_CHKANDSTMT'       => '4:-1:0:1:2',
    'MPIR_ERR_CHKANDSTMT1'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT2'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT3'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT4'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP'       => '3:-1:0:1:2',
    'MPIR_ERR_CHKANDJUMP1'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP2'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP3'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP4'      => '3:-1:1:1:2',
    'MPIR_ERR_SETFATAL'         => '2:-1:0:1:1',
    'MPIR_ERR_SETFATALSIMPLE'   => '2:-1:0:1:1',
    'MPIR_ERR_SETFATAL1'        => '2:-1:1:1:1',
    'MPIR_ERR_SETFATAL2'        => '2:-1:2:1:1',
    'MPIR_ERR_SETFATALANDSTMT'  => '3:-1:0:1:1',
    'MPIR_ERR_SETFATALANDSTMT1' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT2' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT3' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT4' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP'  => '2:-1:0:1:1',
    'MPIR_ERR_SETFATALANDJUMP1' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP2' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP3' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP4' => '2:-1:1:1:1',
    'MPIR_ERR_CHKFATALANDSTMT'  => '4:-1:0:1:2',
    'MPIR_ERR_CHKFATALANDSTMT1' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT2' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT3' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT4' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP'  => '3:-1:0:1:2',
    'MPIR_ERR_CHKFATALANDJUMP1' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP2' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP3' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP4' => '3:-1:1:1:2',
    'MPIR_ERRTEST_VALID_HANDLE' => '4:-1:0:1:3',
);
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
