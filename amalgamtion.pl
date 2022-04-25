#!/usr/bin/perl
use strict;

my %spares;
$spares{"src/mpid/ch4/src/mpid_ch4_net_array.c"} = 1;
$spares{"src/mpid/ch4/netmod/ofi/func_table.c"} = 1;
$spares{"src/mpi/errhan/errutil.c"} = 1;
chdir "/home/hzhou/work/pull_requests/mpich-main";
amalg_it("src/mpid/ch4/src/Makefile.mk", "src/mpid/ch4/src/ch4_src.c");
amalg_it("src/mpi/Makefile.mk", "src/mpi/mpi_impl.c");
amalg_it("src/mpid/ch4/netmod/ofi/Makefile.mk", "src/mpid/ch4/netmod/ofi/ofi.c");

# ---- subroutines --------------------------------------------
sub amalg_it {
    my ($makefile, $output) = @_;
    my (@sources, @spares);
    push @spares, $output;
    filter_makefile(\@sources, \@spares, $makefile, 0);
    my $n = @sources;
    print "   $n sources\n";
    my (%statics, %includes, @includes);
    my @lines;
    foreach my $f (@sources) {
        my $got_include;
        push @lines, "/* -- $f -- */\n\n";
        open In, "$f" or die "Can't open $f: $!\n";
        while(<In>){
            if (/^#include\s*(.*tsp.*\.h)/) {
                my ($inc) = ($1);
                if ($inc =~/(\w+)_tsp_(\w+)_(algos|algos_prototypes|algos_undef).h/) {
                    $inc = "\"coll/$1/$1_tsp_$2_$3.h\"";
                    push @lines, "#include $inc\n";
                }
                else {
                    push @lines, $_;
                }
            }
            elsif (/^#include\s*(\S+)/) {
                my ($t) = ($1);
                my $a = filter_include($t);
                if (!$includes{$a}) {
                    $includes{$a}+=1;
                    push @includes, $a;
                }
                $got_include=1;
            }
            elsif (!$got_include) {
            }
            elsif (/^\/\*/) {
                while (!/\*\//) {
                    $_ = <In>;
                }
            }
            else {
                my $static_var;
                if (/^static[^=\(]+\b(\w+)/) {
                    if ($statics{$1} and $f ne $statics{$1}) {
                        warn "duplicate static name [$1] -- $f & $statics{$1}\n";
                    }
                    else {
                        $statics{$1} = $f;
                    }
                }
                push @lines, $_;
            }
        }
        close In;
    }
    open Out, ">$output" or die "Can't write $output: $!\n";
    print "  --> [$output]\n";
    foreach my $inc (@includes) {
        print Out "#include $inc\n";
    }
    print Out "\n";
    foreach my $l (@lines) {
        print Out $l;
    }
    close Out;
}

sub filter_makefile {
    my ($sources, $spares, $makefile, $level) = @_;
    my @out_lines;
    my ($got_sources, $got_incmake);
    my @lines;
    {
        open In, "$makefile" or die "Can't open $makefile.\n";
        @lines=<In>;
        close In;
    }
    while($_ = shift @lines){
        if (/^mpi_core_sources\s*\+=\s*(\S+)/ and !$got_sources) {
            if ($1 ne "\\") {
                $got_sources++;
                if ($spares{$1}) {
                    push @$spares, $1;
                }
                else {
                    push @$sources, $1;
                }
            }
            while (/\\$/) {
                $_ = shift @lines;
                if (/^\s+(\S+)/) {
                    if ($1 ne "\\") {
                        $got_sources++;
                        if ($spares{$1}) {
                            push @$spares, $1;
                        }
                        else {
                            push @$sources, $1;
                        }
                    }
                }
            }
            if ($level == 0) {
                my $first = shift @$spares;
                push @out_lines, "mpi_core_sources += $first \\\n";
                foreach my $a (@$spares) {
                    push @out_lines, "                    $a \\\n";
                }
                $out_lines[-1] =~s/ \\//;
            }
        }
        elsif (/^include .*?\/(src\/.*\/Makefile.mk)/ and !$got_sources) {
            push @out_lines, $_;
            filter_makefile($sources, $spares, $1, $level+1);
            $got_incmake++;
        }
        else {
            if (/^\s*$/ or /^#/) {
            }
            elsif ($got_incmake and !$got_sources) {
                $got_sources = 1;
                if ($level == 0) {
                    my $first = shift @$spares;
                    push @out_lines, "mpi_core_sources += $first \\\n";
                    foreach my $a (@$spares) {
                        push @out_lines, "                    $a \\\n";
                    }
                    $out_lines[-1] =~s/ \\//;
                }
            }
            push @out_lines, $_;
        }
    }

    open Out, ">$makefile" or die "Can't write $makefile: $!\n";
    print "  --> [$makefile]\n";
    foreach my $l (@out_lines) {
        print Out $l;
    }
    close Out;
}

sub filter_include {
    my ($inc) = @_;
    if ($inc =~ /^<(mpi\w+\.h)>/) {
        $inc = "\"$1\"";
    }

    if ($inc =~/\b(mpicomm)\.h/) {
        $inc = "\"comm/$1.h\"";
    }
    elsif ($inc =~/\b(group)\.h/) {
        $inc = "\"group/$1.h\"";
    }
    elsif ($inc =~/\b(primes)\.h/) {
        $inc = "\"topo/$1.h\"";
    }
    elsif ($inc =~/\b(dataloop_internal|veccpy)\.h/) {
        $inc = "\"datatype/typerep/dataloop/$1.h\"";
    }
    elsif ($inc =~ /\b(bcast|ibcast|iallgatherv)\.h/) {
        $inc = "\"coll/$1/$1.h\"";
    }
    elsif ($inc =~/(\w+)_tsp_(\w+)_(algos|algos_prototypes|algos_undef).h/) {
        $inc = "\"coll/$1/$1_tsp_$2_$3.h\"";
    }
    return $inc;
}

