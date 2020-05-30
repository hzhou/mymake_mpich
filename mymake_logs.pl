#!/usr/bin/perl
use strict;
use Cwd;

our %opts;

my $pwd=getcwd();
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\w+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
my (@timer_states, %state_funcnames, %state_colors);
my @files;
foreach my $dir (qw(mpi mpi_t nameserv util binding include mpid pmi)) {
    open In, "find src/$dir -name '*.[ch]' |" or die "Can't open find src/$dir -name '*.[ch]' |: $!\n";
    while(<In>){
        chomp;
        push @files, $_;
    }
    close In;
}
foreach my $f (@files) {
    my $funcname;
    open In, "$f" or die "Can't open $f: $!\n";
    while(<In>){
        if (/^\w[^(]* \*?(\w+)\s*\(/) {
            $funcname=$1;
        }
        elsif (/^(\w+)\s*\(/) {
            $funcname=$1;
        }
        elsif (!$funcname and /^\s+\w[^(]* \*?(\w+)\s*\(/) {
            $funcname=$1;
        }
        elsif (/^}/) {
            undef $funcname;
        }
        elsif (/^\s*MPIR_FUNC_\w+_STATE_DECL\(\s*(\S+)\s*\)/) {
            my ($state) = ($1);
            if ($state eq "FUNCNAME") {
                next;
            }
            if (!$funcname) {
                print "$f:$state\n";
                $state_funcnames{$state}="__func__";
            }
            else {
                $state_funcnames{$state}=$funcname;
            }
            push @timer_states, $state;
        }
    }
    close In;
}

my @timer_states = sort @timer_states;
my $n = @timer_states;
open Out, ">src/include/mpiallstates.h" or die "Can't write src/include/mpiallstates.h: $!\n";
print "  --> [src/include/mpiallstates.h]\n";
print Out "#ifndef MPIALLSTATES_H_INCLUDED\n";
print Out "#define MPIALLSTATES_H_INCLUDED\n";
print Out "\n";
print Out "/* $n total states */\n";
print Out "enum MPID_TIMER_STATE {\n";
foreach my $t (@timer_states) {
    print Out "     $t,\n";
}
print Out "     MPID_NUM_TIMER_STATES\n";
print Out "};\n";
print Out "#endif /* MPIALLSTATES_H_INCLUDED */\n";
close Out;

open Out, ">src/util/logging/common/state_names.h" or die "Can't write src/util/logging/common/state_names.h: $!\n";
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
foreach my $t (@timer_states) {
    print Out "    { $t, \"$state_funcnames{$t}\", NULL },\n";
}
print Out "\"    { -1, NULL, NULL }\n";
print Out "};\n";
print Out "#endif /* STATE_NAMES_H_INCLUDED */\n";
close Out;
