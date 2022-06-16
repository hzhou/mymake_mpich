#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my $pwd = getcwd();

if (!-f "$pwd/maint/extractcvars.in") {
    if (-f "$pwd/maint/extractcvars") {
        exit;
    }
    die "File not found: $pwd/maint/extractcvars.in\n";
}

if (-f "$pwd/maint/extractcvars.in") {
    my $dirs;
    open In, "maint/cvardirs.in" or die "Can't open maint/cvardirs.in: $!\n";
    while(<In>){
        chomp;
        s/\@abs_srcdir\@/$pwd\/maint/g;
        $dirs = $_;
        last;
    }
    close In;

    open Out, ">mymake/extractcvars.pl" or die "Can't write mymake/extractcvars.pl: $!\n";
    print "  --> [mymake/extractcvars.pl]\n";
    open In, "maint/extractcvars.in" or die "Can't open maint/extractcvars.in: $!\n";
    while(<In>){
        s/\@abs_srcdir\@/$pwd\/maint/g;
        print Out "$_";
    }
    close In;
    close Out;

    print "    extractcvars...\n";
    system "perl mymake/extractcvars.pl --dirs=\"$dirs\"";
}
else {
    system "perl mymake/extractcvars.pl";
}
