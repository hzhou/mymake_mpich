#!/usr/bin/perl
use strict;

our %dir_hash = ("test/mpi" => []);
our $do_custom_testlist;
our @config_args;
our %custom_env;

my %options;

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
        $options{$jenkins_env{$k}} = $ENV{$k};
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
            $options{$opt_list{$1}} = $2;
        }
    }
}
elsif ($ENV{param}) {
    my @tlist = split /\s+/, $ENV{param};

    foreach my $t (@tlist) {
        if ($t =~ /^env:(\w+)=(.*)/) {
            $custom_env{$1} = $2;
        } elsif ($t=~/testlist[:=](.+)$/) {
            add_testlist($1);
        } elsif ($t=~/(--(with|without|enable|disable)-\S+)/) {
            push @config_args, $1;
        } elsif ($t =~/^(\w+)[:=](\S+)/) {
            if ($1 eq "HOSTS") {
                $custom_env{HYDRA_HOST_FILE}="$ENV{PMRS}/hosts.$2";
            }
            elsif ($opt_list{$1}) {
                $options{$opt_list{$1}} = $2;
            }
        }
    }
    dump_testlist();
}

open Out, ">custom_import.sh" or die "Can't write custom_import.sh: $!\n";
print "  --> [custom_import.sh]\n";
foreach my $k (keys %options) {
    if ($opt_name{$k}) {
        print Out "$opt_name{$k}=$options{$k}\n";
    }
}
foreach my $k (sort keys %custom_env) {
    print Out "$k=$custom_env{$k}\n";
}
if (@config_args) {
    print Out "config_args=\"@config_args\"\n";
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
        $do_custom_testlist = 1;
    }
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

