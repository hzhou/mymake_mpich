#!/usr/bin/perl
use strict;

our %direct_config;
our %dir_hash = ("test/mpi" => []);
our $do_custom_testlist;
our @config_args;
our %custom_env;
our %jenkins_options;
our @mymake_args;

%direct_config = (
    strict => "--enable-strict",
    fast   => "--enable-fast=all",
    nofast => "--disable-fast",
    noshared=>"--disable-shared",
    debug  => "--enable-g=all",
    noweak => "--disable-weak-symbols",
    strictnoweak=>"--enable-strict --disable-weak-symbols",
    nofortran=>"--disable-fortran",
    nocxx  => "--disable-cxx",
    multithread=>"--enable-threads=multiple",
    singlethread=>"--enable-threads=single --with-thread-package=none",
    debuginfo => "--enable-debuginfo",
    noerrorchecking=>"--disable-error-checking",
    "no-inline" => "--enable-ch4-netmod-inline=no --enable-ch4-shm-inline=no",
    "direct-nm" => "--enable-ch4-direct=netmod",
    "direct-auto"=>"--enable-ch4-direct=auto",
);
my %cmdline_options;
foreach my $a (@ARGV) {
    if ($a=~/-(\w+)=(.*)/) {
        $cmdline_options{$1}=$2;
    }
    else {
        $cmdline_options{$1}=1;
    }
}


my %jenkins_env = (
    GIT_BRANCH => "-b",
    WORKSPACE => "-h",
    label => "-q",
);

my %opt_list = (
    compiler => "-c",
    jenkins_configure => "-o",
    config => "-o",
    label => "-q",
    queue => "-q",
    netmod => "-m",
    device => "-m",
    pm => "-r",
);

my %opt_name = (
    "-c" => "compiler",
    "-o" => "config",
    "-q" => "label",
    "-m" => "netmod",
);
foreach my $k (keys %jenkins_env) {
    if ($ENV{$k}) {
        $jenkins_options{$jenkins_env{$k}} = $ENV{$k};
    }
}

if ($ENV{ghprbCommentBody}) {
    my $t = $ENV{ghprbCommentBody};
    $t=~s/\\r\\n/\n/g;

    while ($t =~ /^env:\s*(\w+)\s*=\s*(.*?)\s*$/mg) {
        $custom_env{$1} = $2;
    }

    while ($t=~/^testlist:\s*(.+?)\s*$/mg) {
        add_testlist($1);
    }
    dump_testlist();

    while ($t=~/(--(with|without|enable|disable)-\S+)/g) {
        push @config_args, $1;
    }

    while ($t =~/^(\w+)\s*[:=]\s*(\S+)/mg) {
        if ($1 eq "HOSTS") {
            $custom_env{HYDRA_HOST_FILE}="$ENV{PMRS}/hosts.$2";
        }
        elsif ($opt_list{$1}) {
            $jenkins_options{$opt_list{$1}} = $2;
            if ($1 eq "config") {
                set_config($2);
            }
        }
    }
}
elsif ($ENV{param}) {
    my @tlist = split /\s+/, $ENV{param};

    foreach my $t (@tlist) {
        if ($t =~ /^env:(\w+)=(.*)/) {
            $custom_env{$1} = $2;
        }
        elsif ($t=~/testlist[:=](.+)$/) {
            add_testlist($1);
        }
        elsif ($t=~/(--(with|without|enable|disable)-\S+)/) {
            push @config_args, $1;
        }
        elsif ($t =~/^(\w+)[:=](\S+)/) {
            if ($1 eq "HOSTS") {
                $custom_env{HYDRA_HOST_FILE}="$ENV{PMRS}/hosts.$2";
            }
            elsif ($opt_list{$1}) {
                $jenkins_options{$opt_list{$1}} = $2;
                if ($1 eq "config") {
                    set_config($2);
                }
            }
        }
    }
    dump_testlist();
}

if ($cmdline_options{mymake}) {
    my $netmod = $jenkins_options{"-m"};
    my $compiler = $jenkins_options{"-c"};
    my $label = $jenkins_options{"-q"};
    set_netmod($netmod);
    set_compiler($compiler);
    set_label($label);
}

open Out, ">custom_import.sh" or die "Can't write custom_import.sh: $!\n";
print "  --> [custom_import.sh]\n";
foreach my $k (keys %jenkins_options) {
    if ($opt_name{$k}) {
        print Out "export $opt_name{$k}=$jenkins_options{$k}\n";
    }
}
foreach my $k (sort keys %custom_env) {
    print Out "export $k=$custom_env{$k}\n";
}
if (@mymake_args) {
    print Out "export mymake_args=\"@mymake_args\"\n";
}
if (@config_args) {
    print Out "export config_args=\"@config_args\"\n";
}
close Out;

# ---- subroutines --------------------------------------------
sub add_testlist {
    my ($spec) = @_;
    my $dir = "test/mpi";;
    if ($spec=~/^\S+[^\/]$/ && -d "$dir/$spec") {
        $spec .= "/";
    }
    while ($spec=~/(.+?)\//g) {
        if (!$dir_hash{"$dir/$1"}) {
            $dir_hash{"$dir/$1"} = [];
        }
        push @{$dir_hash{$dir}}, $1;
        $dir .= "/$1";
    }

    $spec=~s/.*\///;
    if ($spec) {
        push @{$dir_hash{$dir}}, $spec;
    }
    $do_custom_testlist = 1;
}

sub dump_testlist {
    if ($do_custom_testlist) {
        my @sorted = sort keys(%dir_hash);
        foreach my $dir (@sorted) {
            my $list = $dir_hash{$dir};
            if ($list && @$list) {
                open Out, ">$dir/testlist.custom" or die "Can't write $dir/testlist.custom: $!\n";
                print "  --> [$dir/testlist.custom]\n";
                my %dups;
                foreach my $l (@{$list}) {
                    if (!$dups{$l}) {
                        print Out "$l\n";
                        $dups{$l} = 1;
                    }
                }
                close Out;
            }
            else {
                system "ln -s testlist $dir/testlist.custom";
            }
        }
        $custom_env{TESTLIST}="testlist.custom";
    }
}

sub set_config {
    my ($config) = @_;
    if ($direct_config{$config}) {
        push @mymake_args, $direct_config{$config};
    }
    elsif ($config eq "am-only") {
        push @mymake_args, "--with-ch4-netmod-ucx-args=am-only";
        push @mymake_args, "--enable-legacy-ofi";
    }
}

sub set_netmod {
    my ($netmod) = @_;
    $netmod=~s/-/:/;
    if (!$netmod) {
        push @mymake_args, "ch3:nemesis:tcp";
    }
    elsif ($netmod=~/ch3:(tcp|ofi|mxm|portals4)/) {
        push @mymake_args, "ch3:nemesis:$1";
    }
    else {
        push @mymake_args, "--with-device=$netmod";
    }
}

sub set_compiler {
    my ($compiler) = @_;
}

sub set_label {
    my ($label) = @_;
}

