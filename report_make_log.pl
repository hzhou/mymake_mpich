#!/usr/bin/perl
use strict;

my ($make_log_file, $compiler, $dur) = @ARGV;

my @make_log;
my %got_hash;
open In, "$make_log_file" or die "Can't open $make_log_file: $!\n";
while(<In>){
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
        elsif (/^("\S*", line \d+: warning: .*)/) {
            my ($t) = ($1);
            while(<In>){
                if (/^(\s+)(\S.+)/) {
                    $t.=" $2\n";
                }
                else {
                    last;
                }
            }
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

my $n_fails = dump_report(\@make_log, $dur);
exit $n_fails;

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
        $t=~s/"//g;
        $t=~s/</&lt;/g;
        $t=~s/>/&gt;/g;

        my @t_lines = split /\n/, $t;
        my $msg = shift @t_lines;
        my $detail = join("\n", @t_lines);

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
            print Out "<failure message=\"$msg\">\n";
            if (!$detail) {
                print Out "Build details are in make.log.\n";
            }
            else {
                print Out "<![CDATA[$detail]]>\n";
            }
            print Out "</failure>\n";
        }
        print Out "</testcase>\n";
    }

    print Out "</testsuite>\n";
    print Out "</testsuites>\n";
    close Out;
    return $n_fails;
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
    elsif ($t=~/^"(\S+)", line (\d+): warning:/) {
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
        elsif ($compiler eq "pgi") {
            if ($t=~/warning: transfer of control bypasses initialization of/) {
                $o->{skip}="pgi: goto bypasses variable initialization";
            }
            elsif ($t=~/warning: cc clobber ignored/) {
                $o->{skip}="pgi: cc clobber ignored";
            }
            elsif ($t=~/warning: variable \w+ was set but never used/) {
                $o->{skip}="pgi: variable set but unused";
            }
            elsif ($t=~/warning: statement is unreachable/) {
                $o->{skip}="pgi: statement unreachable";
            }
            elsif ($t=~/warning: integer conversion resulted in a change of sign/) {
                $o->{skip}="pgi: sign conversion";
            }
        }
        return $o;
    }
    else {
        return undef;
    }
}

