#!/usr/bin/perl
use strict;
use Cwd;

our %opts;


my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;

$opts{prefix} = "$pwd/_inst";
my $mpich_repo = "$ENV{HOME}/work/mpich-github";
if (!-d $mpich_repo) {
    die "MPICH repo not found at $mpich_repo\n";
}

my $mpich_dir = "$pwd/mpich-checkout";
print "Cloning $mpich_repo (main branch) into $mpich_dir ...\n";
system "rm -rf $mpich_dir";
system("git clone --branch main --single-branch --depth 1 $mpich_repo $mpich_dir") == 0 or die "git clone failed\n";

foreach my $d ("src/mpi/romio", "src/pm/hydra", "test/mpi") {
    system "cp $mpich_dir/maint/version.m4 $mpich_dir/$d/version.m4";
}
system "touch $mpich_dir/subsys_include.m4";

my $template_dir = $mymake_dir . "/config_templates";
if (!-d $template_dir) {
    mkdir $template_dir or die "Can't mkdir $template_dir: $!\n";
}

my @headers;
push @headers, [".", "src/include/mpichconf.h.in", "mpichconf.h"];
push @headers, ["src/mpl", "include/config.h.in", "mplconfig.h"];
push @headers, ["src/pmi", "include/pmi_config.h.in", "pmi_config.h"];
push @headers, ["src/mpi/romio", "adio/include/romioconf.h.in", "romioconf.h"];
push @headers, ["src/pm/hydra", "hydra_config.h.in", "hydra_config.h"];
push @headers, ["test/mpi", "include/mpitestconf.h.in", "mpitestconf.h"];
push @headers, ["test/mpi/dtpools", "dtpoolsconf.h.in", "dtpoolsconf.h"];

foreach my $h (@headers) {
    my ($subdir, $header_in, $template_name) = @$h;
    my $acdir = "$mpich_dir/$subdir";
    if (!-f "$acdir/configure.ac") {
        warn "Skipping $subdir: no configure.ac\n";
        next;
    }

    print "Processing $subdir ...\n";

    my $local_confdb = "$acdir/confdb";
    my $need_confdb = (!-e $local_confdb && $subdir ne ".");
    if ($need_confdb) {
        mkdir $local_confdb or warn "mkdir: $!\n";
    }

    my $old_dir = getcwd();
    chdir $acdir or die "Can't chdir $acdir: $!\n";
    system("aclocal -I $mpich_dir/confdb 2>&1");
    my $rc = system("autoheader 2>&1");
    chdir $old_dir;

    if ($need_confdb) {
        rmdir $local_confdb;
    }

    if ($rc != 0) {
        warn "  autoheader failed for $subdir, skipping\n";
        next;
    }

    my $src = "$acdir/$header_in";
    my $dst = "$template_dir/$template_name";
    if (!-f $src) {
        warn "  Expected $header_in not found, skipping\n";
        next;
    }

    system "cp $src $dst";
    print "  $template_name updated\n";
}

system "rm -rf $mpich_dir";
print "\nDone.\n";
