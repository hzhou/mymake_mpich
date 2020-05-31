#!/usr/bin/perl
use strict;
use Cwd;

our %env_vars;
our %cmdline_vars;
our %config;

%env_vars = (
    MPI_SOURCE => "MPI_SOURCE",
    MPITEST_MPIVERSION => "mpiversion",
    MPITEST_PPNARG => "ppn_arg",
    MPITEST_PPNMAX => "ppn_max",
    MPITEST_TIMEOUT => "timeout_default",
    MPITEST_TIMEOUT_MULTIPLIER => "timeout_multiplier",
    MPITEST_TIMELIMITARG => "timeout_arg",
    MPITEST_BATCH => "run_batch",
    MPITEST_BATCHDIR => "batchdir",
    MPITEST_STOPTEST => "stopfile",
    MPITEST_NUM_JOBS => "j",
    MPITEST_INCLUDE_DIR => "include_dir",
    MPITEST_EXCLUDE_DIR => "exclude_dir",
    MPITEST_INCLUDE_PATTERN => "include_pattern",
    MPITEST_EXCLUDE_PATTERN => "exclude_pattern",
    MPITEST_PROGRAM_WRAPPER => "program_wrapper",
    VERBOSE => "verbose",
    V => "verbose",
    RUNTESTS_VERBOSE => "verbose",
    RUNTESTS_SHOWPROGRESS => "show_progress",
    NOXMLCLOSE => "noxmlclose",
);
%cmdline_vars = (
    j => "j",
    srcdir => "srcdir",
    tests => "tests",
    mpiexec => "mpiexec",
    nparg => "np_arg",
    np => "np_default",
    maxnp => "np_max",
    ppnarg => "ppn_arg",
    ppn => "ppn_max",
    batch => "run_batch",
    batchdir => "batch_dir",
    timelimitarg => "timeout_arg",
    verbose => "verbose",
    showprogress => "show_progress",
    xmlfile => "xmlfile",
    tapfile => "tapfile",
    junitfile => "junitfile",
    noxmlclose => "noxmlclose",
    "include-pattern" => "include_pattern",
    "exclude-pattern" => "exclude_pattern",
    "include-dir" => "include_dir",
    "exclude-dir" => "exclude_dir",
);
$config{root} = ".";
$config{mpiexec} = "mpirun";
$config{np_arg} = "-n";

foreach my $a (@ARGV) {
    if ($a=~/^--?dir=(.*)/) {
        chdir $1 or die "Can't chdir $1\n";
    }
    elsif ($a=~/^--?root=(.*)/) {
        $config{root} = $1;
    }
}
$config{srcdir} = getcwd();
if ($config{srcdir}=~/(.*)\/test\/mpi/ and -e "$1/_inst/bin/mpirun") {
    $ENV{PATH} = "$1/_inst/bin:$ENV{PATH}";
    $ENV{LD_LIBRARY_PATH} = "$1/_inst/lib:$ENV{LD_LIBRARY_PATH}";
}
$config{tests} = "testlist";

my @alltests;
LoadTests($config{root}, \@alltests);

print "Building test programs...\n";
build_alltests(\@alltests);

foreach my $test (@alltests) {
    if (-e "$test->{dir}/$test->{prog}") {
        my $cmd = get_test_cmd($test);
        if ($test->{dir} ne ".") {
            $cmd = "cd $test->{dir} && $cmd";
        }
        print "[$cmd]\n";
        my %saveEnv;
        if ($test->{env}) {
            %saveEnv = %ENV;
            if ($config{verbose}) {
                print "  ENV: $test->{env}\n";
            }
            foreach my $val (split /\s+/, $test->{env}) {
                if ($val =~ /([^=]+)=(.*)/) {
                    $ENV{$1} = $2;
                }
            }
        }
        system $cmd;
        if ($test->{env}) {
            %ENV = %saveEnv;
        }
    }
}

# ---- subroutines --------------------------------------------
sub LoadTests {
    my ($dir, $alltests) = @_;
    my $srcdir = $config{srcdir};
    my @include_list=split /[, ]+/, $config{tests};
    my %loaded_listfile;
    while(my $f=shift @include_list){
        if (-d $f) {
            LoadTests($f, $alltests);
            next;
        }

        my $listfile;
        if (-e "$dir/$f") {
            $listfile = "$dir/$f";
        }
        elsif (-e "$srcdir/$dir/$f") {
            $listfile = "$srcdir/$dir/$f";
        }

        if (!$listfile) {
            next;
        }
        elsif ($loaded_listfile{$f}) {
            next;
        }
        $loaded_listfile{$f} = 1;

        print "Loading $listfile...\n";

        my %macros;
        open In, "$listfile" or die "Can't open $listfile: $!\n";
        while(<In>){
            s/#.*//g;
            s/\r?\n//;
            s/^\s*//;
            if (/^\s*$/) {
                next;
            }

            if (/\$\(\w/) {
                $_ = expand_macro($_, \%macros);
            }
            if (/^set:\s*(\w+)\s*=\s*(.*)/) {
                $macros{$1} = $2;
                next;
            }

            my $test;
            if (/^!(\S+):(\S+)/) {
                system "cd $1 && make $2";
                next;
            }
            elsif (/^include\s+(\S+)/) {
                push @include_list, $1;
                next;
            }
            elsif (/^(\S+)/ and -d "$dir/$1") {
                my $d = $1;
                if ($config{include_dir} && !($d=~/$config{include_dir}/)) {
                    next;
                }
                if ($config{exclude_dir} && ($d=~/$config{exclude_dir}/)) {
                    next;
                }
                push @include_list, "$dir/$d";
                next;
            }
            elsif ($config{run_xfail_only} or $config{include_pattern} or $config{exclude_pattern}) {
                if ($config{run_xfail_only}) {
                    if (!/xfail=/) {
                        next;
                    }
                    else {
                        s/xfail=\S*//;
                    }
                }
                if ($config{include_pattern}) {
                    if (!(/$config{include_pattern}/)) {
                        next;
                    }
                }
                if ($config{exclude_pattern}) {
                    if (/$config{exclude_pattern}/) {
                        next;
                    }
                }
                $test = parse_testline($_);
            }
            else {
                $test = parse_testline($_);
            }
            if ($test->{dir}) {
                $test->{dir} = "$dir/$test->{dir}";
            }
            else {
                $test->{dir} = $dir;
            }
            $test->{line} = $_;
            push @$alltests, $test;
            $test->{id} = $#$alltests + 1;
        }
        close In;
    }
}

sub build_alltests {
    my ($alltests) = @_;
    my @dirs;
    my %dirs;
    my %dir_test_count;
    foreach my $test (@$alltests) {
        my $d = $test->{dir};
        if (!$dirs{$d}) {
            push @dirs, $d;
            $dirs{$d} = {};
        }
        $dirs{$d}->{$test->{prog}} ++;
        $dir_test_count{$d}++;
    }

    foreach my $d (@dirs) {
        my @prog_list = sort keys %{$dirs{$d}};
        my $n = @prog_list;
        print "  $d $n programs - $dir_test_count{$d} tests\n";
        my $make="make";
        if ($d ne ".") {
            $make.=" -C $d";
        }
        if ($config{j}) {
            $make.=" -j $config{j}";
        }

        my $t = join ' ', @prog_list;
        `$make clean 2>&1`;
        if ($config{verbose}) {
            print "    $make $t...\n";
        }
        `$make $t 2>&1`;
    }
}

sub get_test_cmd {
    my ($test) = @_;
    my $cmd = "$config{mpiexec} $config{np_arg} $test->{np}";
    if ($config{ppn_arg} && $config{ppn_max}>0) {
        my $nn = $config{ppn_max};
        if ($nn > $test->{np}) {
            $nn = $test->{np};
        }
        my $arg = $config{ppn_arg};
        $arg=~s/\%d/$nn/;
        $cmd .= " $arg";
    }
    my $timeout = $config{timeout_default};
    if (defined($test->{timeLimit}) && $test->{timeLimit} =~ /^\d+$/) {
        $timeout = $test->{timeLimit};
    }
    if ($timeout) {
        $timeout *= $config{timeout_multiplier};
        $test->{timeout} = $timeout;
        $test->{env}.=" MPIEXEC_TIMEOUT=$timeout";
    }
    if ($test->{mpiexecarg}) {
        $cmd.=" $test->{mpiexecarg}";
    }
    if ($config{program_wrapper}) {
        $cmd.=" $config{program_wrapper}";
    }
    if (-x "$test->{dir}/$test->{prog}") {
        $cmd.=" ./$test->{prog}";
    }
    else {
        $cmd.=" $test->{prog}";
    }
    if ($test->{arg}) {
        $cmd.=" $test->{arg}";
    }
    return $cmd;
}

sub expand_macro {
    my ($line, $macros) = @_;
    my @paren_stack;
    my $segs=[];
    while(1){
        if ($line=~/\G$/sgc) {
            last;
        }
        elsif ($line=~/\G\$\(/sgc) {
            push @paren_stack, $segs;
            $segs=[];
            push @paren_stack, "\$\(";
        }
        elsif (!@paren_stack) {
            if ($line=~/\G([^\$]|\$(?![\(\.]))+/sgc) {
                push @$segs, $&;
            }
        }
        else {
            if ($line=~/\G\(/sgc) {
                push @paren_stack, $segs;
                $segs=[];
                push @paren_stack, "(";
            }
            elsif ($line=~/\G\)/sgc) {
                my $t=join('', @$segs);
                my $open=pop @paren_stack;
                $segs=pop @paren_stack;
                if ($open eq "(" or $t!~/^\w/) {
                    push @$segs, "$open$t)";
                }
                else {
                    push @$segs, get_macro($t, $macros);
                }
            }
            elsif ($line=~/\G([^\$\(\)]|\$(?![\(\.]))+/sgc) {
                push @$segs, $&;
            }
        }
    }

    while(@paren_stack){
        my $t = join('', @$segs);
        my $open = pop @paren_stack;
        $segs = pop @paren_stack;
        push @$segs, $open;
        push @$segs, $t;
    }
    return join('', @$segs);
}

sub parse_testline {
    my ($line) = @_;
    my %test = (line=> $line);

    my @args = split(/\s+/,$line);
    my $programname = shift @args;
    my $np = shift @args;

    if ($programname=~/^(\S+)\/(\S+)$/) {
        $test{dir}=$1;
        $programname = $2;
    }

    if (!$np) {
        $np = $config{np_default};
    }
    if ($config{np_max}>0 && $np > $config{np_max}) {
        $np = $config{np_max};
    }
    $test{prog} = $programname;
    $test{np} = $np;

    foreach my $a (@args) {
        if ($a =~ /([^=]+)=(.*)/) {
            my ($key, $value) = ($1, $2);
            if ($key eq "env") {
                if ($value=~/([^=]+)=(.*)/) {
                    $test{env} .= " $value";
                }
                else {
                    warn "Environment value not in a=b form: $line";
                }
            }
            elsif ($key=~/^(resultTest|init|timeLimit|arg|env|mpiexecarg|xfail|mpiversion|strict|mpix|mem)$/) {
                if (exists $test{$key}) {
                    $test{$key}.=" $value";
                }
                else {
                    $test{$key}=$value;
                }
            }
            else {
                print STDERR "Unrecognized key $key in test line: $line\n";
            }
        }
        elsif ($a eq "skip_id") {
            $test{skip_id} = 1;
        }
    }
    if (exists $test{xfail} && $test{xfail} eq "") {
        print STDERR "\"xfail=\" requires an argument\n";
    }

    if (filter_mpiversion($test{mpiversion})) {
        $test{skip} = "requires MPI version $test{mpiversion}";
    }
    elsif (filter_strict($test{strict})) {
        $test{skip} = "non-strict test, strict MPI mode requested";
    }
    elsif (filter_xfail($test{xfail})) {
        $test{skip} = "xfail tests disabled: xfail=$test{xfail}";
    }
    elsif (filter_mpix($test{mpix})) {
        $test{skip} = "tests MPIX extensions, MPIX testing disabled";
    }
    return \%test;
}

sub get_macro {
    my ($s, $macros) = @_;
    if ($s=~/^(\w+):(.*)/) {
        my $p=$2;
        my $t=get_macro_word($1, $macros);
        my @plist=split /,\s*/, $p;
        my $i=1;
        foreach my $pp (@plist) {
            $t=~s/\$$i/$pp/g;
            $i++;
        }
        return $t;
    }
    elsif ($s=~/^(\w+)/) {
        return get_macro_word($1, $macros);
    }
}

sub filter_mpiversion {
    my ($version_required) = @_;
    if (!$version_required) {
        return 0;
    }
    if ($config{MPIMajorVersion} eq "unknown" or $config{MPIMinorVersion} eq "unknown") {
        return 0;
    }

    my ($major, $minor) = split /\./, $version_required;
    if ($major > $config{MPIMajorVersion}) {
        return 1;
    }
    if ($major == $config{MPIMajorVersion} && $minor > $config{MPIMinorVersion}) {
        return 1;
    }
    return 0;
}

sub filter_strict {
    my ($strict_ok) = @_;
    if (lc($strict_ok) eq "false" && $config{run_strict}) {
        return 1;
    }
    return 0;
}

sub filter_xfail {
    my ($xfail) = @_;
    if ($config{run_strict}) {
        return 0;
    }
    if ($xfail && !$config{run_xfail}) {
        return 1;
    }
    return 0;
}

sub filter_mpix {
    my ($mpix_required) = @_;
    if (lc($mpix_required) eq "true" && !$config{run_mpix}) {
        return 1;
    }
    return 0;
}

sub get_macro_word {
    my ($name, $macros) = @_;
    return $macros->{$name};
}

