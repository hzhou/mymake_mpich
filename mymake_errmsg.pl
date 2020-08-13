#!/usr/bin/perl
use strict;
use Cwd;

our %opts;
our %errnames;
our %generics;
our %specifics;
our %generic_index;

my $pwd=getcwd();
my $mymake_dir = Cwd::abs_path($0);
$mymake_dir=~s/\/[^\/]+$//;
open In, "mymake/opts" or die "Can't open mymake/opts: $!\n";
while(<In>){
    if (/^(\S+): (.*)/) {
        $opts{$1} = $2;
    }
}
close In;
my (@classnames, %generics);
open In, "src/mpi/errhan/baseerrnames.txt" or die "Can't open src/mpi/errhan/baseerrnames.txt: $!\n";
while(<In>){
    if (/^(MPI\S+)\s*(\d+)\s*(.*)/) {
        my ($class, $id, $name) = ($1, $2, $3);
        $name=~s/#.*$//;
        $classnames[$id]=$name;
        $generics{$name}++;
    }
}
close In;
my @files;
open In, "find . -name 'errnames.txt' |" or die "Can't open find . -name 'errnames.txt' |: $!\n";
while(<In>){
    chomp;
    push @files, $_;
}
close In;
foreach my $f (@files) {
    open In, "$f" or die "Can't open $f: $!\n";
    while(<In>){
        if (/^(\*\*[^:]+):(.*)/) {
            my ($name, $repl) = ($1, $2);
            while ($repl=~/\s*\\\s*$/) {
                $repl=$`;
                $_=<In>;
                chomp;
                $repl = $`." ".$_;
            }
            $errnames{$name}=$repl;
        }
    }
    close In;
}
my %KnownErrRoutines = (
    'MPIR_Err_create_code'      => '5:3:1:1:4',
    'MPIO_Err_create_code'      => '5:3:1:0:-1',
    'MPIR_ERR_SET'              => '2:-1:0:1:1',
    'MPIR_ERR_SETSIMPLE'        => '2:-1:0:1:1',
    'MPIR_ERR_SET1'             => '2:-1:1:1:1',
    'MPIR_ERR_SET2'             => '2:-1:2:1:1',
    'MPIR_ERR_SETANDSTMT'       => '3:-1:0:1:1',
    'MPIR_ERR_SETANDSTMT1'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT2'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT3'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDSTMT4'      => '3:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP'       => '2:-1:0:1:1',
    'MPIR_ERR_SETANDJUMP1'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP2'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP3'      => '2:-1:1:1:1',
    'MPIR_ERR_SETANDJUMP4'      => '2:-1:1:1:1',
    'MPIR_ERR_CHKANDSTMT'       => '4:-1:0:1:2',
    'MPIR_ERR_CHKANDSTMT1'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT2'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT3'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDSTMT4'      => '4:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP'       => '3:-1:0:1:2',
    'MPIR_ERR_CHKANDJUMP1'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP2'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP3'      => '3:-1:1:1:2',
    'MPIR_ERR_CHKANDJUMP4'      => '3:-1:1:1:2',
    'MPIR_ERR_SETFATAL'         => '2:-1:0:1:1',
    'MPIR_ERR_SETFATALSIMPLE'   => '2:-1:0:1:1',
    'MPIR_ERR_SETFATAL1'        => '2:-1:1:1:1',
    'MPIR_ERR_SETFATAL2'        => '2:-1:2:1:1',
    'MPIR_ERR_SETFATALANDSTMT'  => '3:-1:0:1:1',
    'MPIR_ERR_SETFATALANDSTMT1' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT2' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT3' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDSTMT4' => '3:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP'  => '2:-1:0:1:1',
    'MPIR_ERR_SETFATALANDJUMP1' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP2' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP3' => '2:-1:1:1:1',
    'MPIR_ERR_SETFATALANDJUMP4' => '2:-1:1:1:1',
    'MPIR_ERR_CHKFATALANDSTMT'  => '4:-1:0:1:2',
    'MPIR_ERR_CHKFATALANDSTMT1' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT2' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT3' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDSTMT4' => '4:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP'  => '3:-1:0:1:2',
    'MPIR_ERR_CHKFATALANDJUMP1' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP2' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP3' => '3:-1:1:1:2',
    'MPIR_ERR_CHKFATALANDJUMP4' => '3:-1:1:1:2',
    'MPIR_ERRTEST_VALID_HANDLE' => '4:-1:0:1:3',
);
my @files;
foreach my $dir (qw(mpi mpi_t nameserv util binding include mpid pmi)) {
    open In, "find src/$dir -name '*.[ch]' |" or die "Can't open find src/$dir -name '*.[ch]' |: $!\n";
    while(<In>){
        chomp;
        push @files, $_;
    }
    close In;
}
foreach my $f (@files) {
    open In, "$f" or die "Can't open $f: $!\n";
    while(<In>){
        if (/\/\*\s+--BEGIN ERROR MACROS--/) {
            while(<In>){
                if (/--END ERROR MACROS--/) {
                    last;
                }
            }
            next;
        }
        if (/int\s+MPI[OUR]_Err_create_code/) {
            next;
        }
        if (/(MPI[OUR]_E\w+)\s*(\(.*)$/) {
            my ($name, $args) = ($1, $2);
            if (!$KnownErrRoutines{$name}) {
                next;
            }
            while(1){
                if ($args=~/^(\((?:[^()]++|(?-1))*+\))/) {
                    $args=substr($1, 1, -1);
                    last;
                }
                $args=~s/\\$//;
                $_=<In>;
                chomp;
                $args.=' '.$_;
            }
            my @arglist=arg_split($args);
            my $pat=$KnownErrRoutines{$name};
            my @idx=split /:/, $pat;
            if ($arglist[$idx[0]]=~/"(\*\*.*)"/) {
                $generics{$1}++;
            }
            if ($arglist[$idx[0]+1]=~/"(\*\*.*)"/) {
                $specifics{$1}++;
            }
        }
    }
    close In;
}
$generics{"**envvarparse"}++;
$specifics{"**envvarparse %s"}++;
$generics{"**cvar_val"}++;
$specifics{"**cvar_val %s %s"}++;
$generics{"**inttoosmall"}++;
$generics{"**notcstatignore"}++;
$generics{"**notfstatignore"}++;

my @sorted_generics=sort keys %generics;
my @sorted_specifics=sort keys %specifics;
open Out, ">src/mpi/errhan/defmsg.h" or die "Can't write src/mpi/errhan/defmsg.h: $!\n";
print "  --> [src/mpi/errhan/defmsg.h]\n";
print Out "#if MPICH_ERROR_MSG_LEVEL > MPICH_ERROR_MSG__CLASS\n";
print Out "typedef struct msgpair {\n";
print Out "    const unsigned int sentinal1;\n";
print Out "    const char *short_name;\n";
print Out "    const char *long_name;\n";
print Out "    const unsigned int sentinal2;\n";
print Out "} msgpair;\n";
print Out "#endif\n\n";
print Out "#if MPICH_ERROR_MSG_LEVEL == MPICH_ERROR_MSG__CLASS\n";
my $n = @classnames;
print Out "#define MPIR_MAX_ERROR_CLASS_INDEX $n\n";
print Out "static const char *classToMsg[] = {\n";
my $i = -1;
foreach my $name (@classnames) {
    $i++;
    print Out "    \"$errnames{$name}\", /* $i $name */\n";
}
print Out "    NULL\n";
print Out "};\n";
print Out "#endif\n\n";
print Out "#if MPICH_ERROR_MSG_LEVEL > MPICH_ERROR_MSG__CLASS\n";
print Out "/* The names are in sorted order, allowing the use of a simple\n";
print Out "   linear search or bisection algorithm to find the message corresponding to\n";
print Out "   a particular message.\n";
print Out "*/\n";

my $n = @sorted_generics;
print Out "static const int generic_msgs_len = $n;\n";
my $_i = -1;
foreach my $name (@sorted_generics) {
    $_i++;
    if (defined $errnames{$name}) {
        print Out "static const char short_gen$_i\[\] = \"$name\";\n";
        print Out "static const char long_gen$_i\[\] = \"$errnames{$name}\";\n";
    }
    else {
        warn "missing: $name\n";
        print Out "static const char short_gen$_i\[\] = \"$name\";\n";
        print Out "static const char long_gen$_i\[\]  = \"$name (missing description)\";\n";
    }
}

print Out "static const msgpair generic_err_msgs[] = {\n";
for (my $i = 0; $i<$n; $i++) {
    my $sep=",";
    if ($i==$n-1) {
        $sep="";
    }
    print Out "  { 0xacebad03, short_gen$i, long_gen$i, 0xcb0bfa11 }$sep\n";
}
print Out "};\n";
print Out "#endif\n\n";
print Out "#if MPICH_ERROR_MSG_LEVEL > MPICH_ERROR_MSG__GENERIC\n";

my $n = @sorted_specifics;
print Out "static const int specific_msgs_len = $n;\n";
my $_i = -1;
foreach my $name (@sorted_specifics) {
    $_i++;
    if (defined $errnames{$name}) {
        print Out "static const char short_spc$_i\[\] = \"$name\";\n";
        print Out "static const char long_spc$_i\[\] = \"$errnames{$name}\";\n";
    }
    else {
        warn "missing: $name\n";
        print Out "static const char short_spc$_i\[\] = \"$name\";\n";
        print Out "static const char long_spc$_i\[\]  = \"$name (missing description)\";\n";
    }
}

print Out "static const msgpair specific_err_msgs[] = {\n";
for (my $i = 0; $i<$n; $i++) {
    my $sep=",";
    if ($i==$n-1) {
        $sep="";
    }
    print Out "  { 0xacebad03, short_spc$i, long_spc$i, 0xcb0bfa11 }$sep\n";
}
print Out "};\n";
print Out "#endif\n\n";

print Out "#if MPICH_ERROR_MSG_LEVEL > MPICH_ERROR_MSG__CLASS\n";
my $i = -1;
foreach my $name (@sorted_generics) {
    $i++;
    $generic_index{$name}=$i;
}
my $n = @classnames;
print Out "#define MPIR_MAX_ERROR_CLASS_INDEX $n\n";
print Out "static int class_to_index[] = {\n";
my $i = -1;
foreach my $name (@classnames) {
    $i++;
    print Out "$generic_index{$name}";
    if ($i<$n-1) {
        print Out ",";
    }
    if ($i % 10 == 9) {
        print Out "\n";
    }
}
print Out "};\n";
print Out "#endif\n\n";
close Out;

# ---- subroutines --------------------------------------------
sub arg_split {
    my ($t) = @_;
    my @strs;
    while ($t=~/(.*)("(?:[^\\]|\\")*")(.*)/) {
        my $i=@strs;
        push @strs, $2;
        $t=$1."str:$i".$3;
    }
    $t=~s/(\((?:[^()]++|(?-1))*+\))/--/g;
    my @t = split /\s*,\s*/, $t;
    foreach my $t (@t) {
        if ($t =~/^str:(\d+)/) {
            $t=$strs[$1];
        }
    }
    return @t;
}

