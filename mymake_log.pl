#!/usr/bin/perl
use strict;

our $mark = "/* MPIR_FUNC */";
our %opts;

parse_args();
if ($opts{clean}) {
    do_clean();
}
else {
    add_trace();
}

# ---- subroutines --------------------------------------------
sub parse_args {
    my @un_recognized;
    foreach my $a (@ARGV) {
        if ($a=~/^-(\w+)=(.*)/) {
            $opts{$1} = $2;
        }
        elsif ($a=~/^-(\w+)/) {
            $opts{$1} = 1;
        }
        elsif (-d $a) {
            $opts{subdir} = $a;
        }
        elsif (-f $a) {
            if ($opts{files}) {
                push @{$opts{files}}, $a;
            }
            else {
                $opts{files} = [$a];
            }
        }
        else {
            push @un_recognized, $a;
        }
    }
    if (@un_recognized) {
        usage();
        die "Unrecognized options: @un_recognized\n";
    }
}

sub do_clean {
    my $subdir = $opts{subdir};
    if (!$subdir) {
        $subdir = "src";
    }
    my $cmd = "find $subdir -name '*.[ch]' | xargs grep -l -F '/* MPIR_FUNC */'";
    my @files;
    if ($opts{files}) {
        @files = @{$opts{files}};
    }
    else {
        open In, "$cmd |" or die "Can't open $cmd |: $!\n";
        while(<In>){
            chomp;
            push @files, $_;
        }
        close In;
    }
    my $n = @files;
    print "Remove tracing logs: checking $n files...\n";
    my $file_count = 0;
    my $change_count = 0;
    foreach my $f (@files) {
        my (@lines, $count);
        open In, "$f" or die "Can't open $f: $!\n";
        while(<In>){
            if (/^\s*.\* MPIR_FUNC \*\//) {
                $count++;
            }
            else {
                push @lines, $_;
            }
        }
        close In;
        if ($count > 0) {
            $file_count++;
            $change_count+=$count;
            dump_lines_out(\@lines, $f);
        }
    }
    print "Updated $file_count files, $change_count places\n";
}

sub add_trace {
    my $subdir = $opts{subdir};
    my @excl_dirs;
    if (!$subdir) {
        $subdir = "src";
        push @excl_dirs, qw(binding cross env glue nameserv openpa packaging pm pmi);
    }
    my $cmd = "find $subdir";
    foreach my $d (@excl_dirs) {
        $cmd .= " -path $subdir/$d -prune -o";
    }
    $cmd .= " -name '*.[ch]'";
    my @files;
    if ($opts{files}) {
        @files = @{$opts{files}};
    }
    else {
        open In, "$cmd |" or die "Can't open $cmd |: $!\n";
        while(<In>){
            chomp;
            push @files, $_;
        }
        close In;
    }
    my $n = @files;
    print "Add tracing logs: checking $n files...\n";
    my $file_count = 0;
    my $change_count = 0;
    foreach my $f (@files) {
        my (@lines, $count);
        my ($got_function, $stage, $last_line);
        open In, "$f" or die "Can't open $f: $!\n";
        while(<In>){
            if (/^[^#\s{]/) {
                undef $got_function;
                undef $stage;
            }

            if (/^[^#\s].*\s+(\w+)\s*\(.*\)\s*$/) {
                $got_function = $1;
            }
            elsif (/^[^#\s].*\s+(\w+)\s*\(.*$/) {
                $got_function = $1;
            }

            if (/^{/ && $got_function && filter_func($got_function)) {
                my $l = ["{\n"];
                log_enter($got_function, $l);
                push @lines, $l;
                $stage = 1;
                $count++;
            }
            elsif (/^(\s+)return.*;$/ && $stage) {
                my $sp = $1;
                my $l = [];
                my $add_brace;
                if ($last_line=~/\b(if\s*\(.*\)|else)\s*$/) {
                    $add_brace = 1;
                }
                log_exit($got_function, $l, $sp, $_, $add_brace);
                push @lines, $l;
                $count += @$l -1;
            }
            else {
                push @lines, $_;
            }

            $last_line = $_;
        }
        close In;
        if ($count > 0) {
            $file_count++;
            $change_count+=$count;
            dump_lines_out(\@lines, $f);
        }
    }
    print "Updated $file_count files, $change_count places\n";

}

sub usage {
    print "Usage: $0 [-option] [subdir]\n";
}

sub dump_lines_out {
    my ($lines, $file) = @_;
    open Out, ">$file" or die "Can't write $file: $!\n";
    foreach my $l (@$lines) {
        if (ref($l) eq "ARRAY") {
            foreach my $ll (@$l) {
                print Out $ll;
            }
        }
        else {
            print Out $l;
        }
    }
    close Out;
}

sub filter_func {
    my ($funcname) = @_;
    if ($opts{prefix} =~ /^[A-Z_]+/) {
        return ($funcname=~/^$opts{prefix}_/);
    }
    else {
        return 1;
    }
}

sub log_enter {
    my ($funcname, $l) = @_;
    push @$l, "    $mark printf(\"Entering $funcname \t\t(%s:%d)\\n\", __FILE__, __LINE__);\n";
}

sub log_exit {
    my ($funcname, $l, $sp, $ret, $add_brace) = @_;
    if ($add_brace) {
        push @$l, $sp."$mark {\n";
    }
    push @$l, $sp."$mark printf(\"Exit     $funcname\\n\");\n";
    push @$l, $ret;
    if ($add_brace) {
        push @$l, $sp."$mark }\n";

    }
}

