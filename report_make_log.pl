#!/usr/bin/perl
use strict;

my ($make_log_file, $compiler, $dur) = @ARGV;

my @make_log;
my %got_hash;
open In, "$make_log_file" or die "Can't open $make_log_file: $!\n";
while(<In>){
    if (/Direct leak of /) {
        my @t;
        push @t, $_;
        while(<In>){
            s/^Unexpected[^:]*://;
            if (/^\s*$/) {
                last;
            }
            push @t, $_;
        }
        push @make_log, \@t;
        next;
    }
    if ($compiler=~/intel|icc/) {
        if (/^(\S+\(\d+\): (error|warning) #\d+:\s*.*)/) {
            my ($t) = ($1);
            push @make_log, $t;
        }
    }
    elsif ($compiler=~/pgi/) {
        if (/^(PGC-W-\d+-.*)/) {
            my ($t) = ($1);
            push @make_log, $t;
        }
    }
    elsif ($compiler=~/sun/) {
        if (/^(".*",\s*line \d+:\s*warning:.*)/) {
            my ($t) = ($1);
            if ($t=~/opa_gcc_intel_32_64_ops/) {
                if (!$got_hash{opa_asm}) {
                    push @make_log, $t;
                    $got_hash{opa_asm}=1;
                }
            }
            else {
                push @make_log, $t;
            }
        }
    }
    else {
        if (/^(\S+:\d+:\s*(error|warning):\s*.*)/) {
            my ($t) = ($1);
            push @make_log, $t;
        }
    }
}
close In;

dump_report(\@make_log, $dur);

# ---- subroutines --------------------------------------------
sub dump_report {
    my ($warning_list, $dur) = @_;
    my $n_fails = @$warning_list;
    if ($n_fails>=10000) {
        $n_fails = 10000;
    }
    my $n_tests = $n_fails+1;
    open Out, ">summary.junit.xml" or die "Can't write summary.junit.xml: $!\n";
    print "  --> [summary.junit.xml]\n";
    print Out "<testsuites>\n";
    print Out "<testsuite failures=\"$n_fails\" errors=\"0\" skipped=\"0\" tests=\"$n_tests\" name=\"warning\">\n";
    if ($dur > 0) {
        print Out "<testcase name=\"1 - build\" time=\"$dur\"></testcase>\n";
    }
    my $i = 1;
    foreach my $t (@$warning_list) {
        if ($i>10000) {
            last;
        }
        $i++;
        if (ref($t) eq "ARRAY") {
            my $o = parse_sanitizer($t);
            if ($o) {
                print Out "<testcase name=\"$o->{name}\">\n";
            }
            else {
                print Out "<testcase name=\"$i\">\n";
            }
            print Out "<failure message=\"$o->{msg}\">\n";
            print Out "<![CDATA[@$t]]>\n";
            print Out "</failure>\n";

            print Out "</testcase>\n";
        }
        else {
            $t=~s/"//g;
            $t=~s/</&lt;/g;
            $t=~s/>/&gt;/g;
            my $o = parse_warning($t);
            if ($o) {
                print Out "<testcase name=\"$o->{file}:$o->{line}\">\n";
            }
            else {
                print Out "<testcase name=\"$i\">\n";
            }
            if ($o->{skip}) {
                print Out "<skipped type=\"TodoTestSkipped\" message=\"$o->{skip}\">\n";
                print Out "<![CDATA[$t]]>\n";
                print Out "</skipped>\n";
            }
            else {
                print Out "<failure message=\"$t\">\n";
                print Out "Build details are in make.log.\n";
                print Out "</failure>\n";
            }
            print Out "</testcase>\n";
        }
    }

    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
}

sub parse_sanitizer {
    my ($t) = @_;
    my $o = {};
    foreach my $l (@$t) {
        if ($l=~/^Unexpected output in (\w+): (Direct leak of.*)/) {
            $l = "$2\n";
            $o->{name}=$1;
            $o->{msg}=$2;
            $o->{msg}=~s/ allocated from://;
            last;
        }
        elsif ($l=~/^Direct leak of.*/) {
            $o->{name}="cpi";
            $o->{msg}=$l;
            $o->{msg}=~s/ allocated from://;
        }
    }
    return $o;
}

sub parse_warning {
    my ($t) = @_;
    my $o;
    if ($t=~/^(\S+):(\d+):/) {
        $o = { file=>$1, line=>$2 };
    }
    elsif ($t=~/^(\S+)\((\d+)\):/) {
        $o = { file=>$1, line=>$2 };
    }
    elsif ($t=~/^PGC-.*\((.*):\s*(\d+)\)/) {
        $o = { file=>$1, line=>$2 };
    }
    elsif ($t=~/"(.*)", line (\d+): warning:/) {
        $o = { file=>$1, line=>$2 };
    }
    elsif ($t=~/(\S+), line (\d+): warning:/) {
        $o = { file=>$1, line=>$2 };
    }

    if ($o) {
        if ($o->{file}=~/^.*\/mymake\/(.*)/g) {
            $o->{file}="~$1";
            if ($o->{file}=~/^~(ucx|libfabric)/) {
                $o->{skip}="external module: $1";
            }
        }
        if ($t=~/warning #177:/) {
            $o->{skip}="icc: warning #177: unused label";
        }
        elsif ($compiler eq "gcc-4" and $t=~/\[(-Wmaybe-uninitialized)\]/) {
            $o->{skip}="gcc-4: $1";
        }
        return $o;
    }
    else {
        return undef;
    }
}

