#!/usr/bin/perl
use strict;
my $mymake_dir = $ENV{mymake_dir};
if(! $mymake_dir){
    if($0=~/^(\/.*)\//){
        $mymake_dir = $1;
    }
    elsif($0=~/^(.*)\//){
        my $pwd=`pwd`;
        chomp $pwd;
        $mymake_dir .= "$pwd/$1";
    }
    $ENV{mymake_dir}=$mymake_dir;
}
my $pr=$ARGV[0];
if(! $pr > 0){
    die "Usage: $0 pr-number\n";
}
my ($author, $branch);
open In, "curl https://api.github.com/repos/pmodels/mpich/pulls/$pr |" or die "Can't open curl https://api.github.com/repos/pmodels/mpich/pulls/$pr |.\n";
while(<In>){
    if(/^\s*"label":\s*"(\w+):(\S+)",/){
        if($1 ne "pmodels"){
            $author = $1;
            $branch = $2;
            last;
        }
    }
}
close In;
if(!$author){
    die "Failed to fetch PR information\n";
}
system("git clone https://github.com/pmodels/mpich mpich-$pr") == 0 or die "Error: git clone https://github.com/pmodels/mpich mpich-$pr\n";
chdir "mpich-$pr" or die "Can't chdir mpich-$pr\n";
system("git checkout -b $branch master") == 0 or die "Error: git checkout -b $branch master\n";
system("git pull https://github.com/$author/mpich.git $branch") == 0 or die "Error: git pull https://github.com/$author/mpich.git $branch\n";
$ENV{compiler}="gnu";
$ENV{test_script}="test_quick";
$ENV{config}="ch3:tcp";
$ENV{configOption}="--enable-strict";
system "perl $mymake_dir/test_mymake.pl";
