#!/usr/bin/perl
use strict;
our %opts;
our @config_args;
our @test_config_args;
our $srcdir;
our $moddir;
our $prefix;
our (%cvars, @cvars, %cats, @cats);
my $pwd=`pwd`;
chomp $pwd;
$opts{V}=0;
my $need_save_args;
if(!@ARGV && -f "mymake/args"){
    my $t;
    {
        open In, "mymake/args" or die "Can't open mymake/args.\n";
        local $/;
        $t=<In>;
        close In;
    }
    @ARGV = split /\s+/, $t;
}
elsif(@ARGV){
    $need_save_args = 1;
}
foreach my $a (@ARGV){
    if($a=~/^--(prefix)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^(\w+)=(.*)/){
        $opts{$1}=$2;
    }
    elsif($a=~/^--/){
        if($a=~/^--with-device=(.*)/){
            $opts{device}=$1;
            push @config_args, $a;
        }
        elsif($a=~/--(dis|en)able-.*tests/){
            push @test_config_args, $a;
        }
        elsif($a=~/--diable-(romio|fortran)/){
            push @config_args, $a;
            push @test_config_args, $a;
        }
        else{
            push @config_args, $a;
        }
    }
    elsif($a=~/^(clean|errmsg|cvars|logs|hydra|testing)$/){
        $opts{do}=$1;
    }
}
if($opts{CC}){
    $ENV{CC}=$opts{CC};
}
if($opts{CXX}){
    $ENV{CXX}=$opts{CXX};
}
if($opts{F77}){
    $ENV{F77}=$opts{F77};
}
if($opts{FC}){
    $ENV{FC}=$opts{FC};
}
if($opts{srcdir}){
    $srcdir = $opts{srcdir};
}
if($opts{moddir}){
    $moddir = $opts{moddir};
}
if($opts{prefix}){
    $prefix = $opts{prefix};
}
if($ENV{MODDIR}){
    $moddir = $ENV{MODDIR};
}
elsif(-d "modules"){
    $moddir = "$pwd/modules";
}
elsif(-e "modules.tar.gz"){
    $moddir = "$pwd/modules";
    my $cmd = "mkdir $moddir";
    print "$cmd\n";
    system $cmd;
    my $cmd = "tar -C $moddir -xf modules.tar.gz";
    print "$cmd\n";
    system $cmd;
    my $cmd = "find $moddir/ucx -name '*.la' | xargs sed -i \"s,MODDIR,$moddir,g\"";
    print "$cmd\n";
    system $cmd;
}
else{
    die "moddir not set\n";
}
if(-f "./maint/version.m4"){
    $srcdir = ".";
}
elsif(-f "../maint/version.m4"){
    $srcdir = "..";
}
elsif(-f "../../maint/version.m4"){
    $srcdir = "../..";
}
elsif(-f "../../../maint/version.m4"){
    $srcdir = "../../..";
}
if(!$srcdir){
    die "srcdir not set\n";
}
if(!$prefix){
    $prefix="$pwd/_inst";
    system "mkdir -p $prefix";
}
my %type_hash=(
    int=>"int",
    double=>"double",
    string=>"const char *",
    boolean=>"int",
    enum=>"int",
    range=>"MPIR_T_cvar_range_value_t",
);
my %mpi_hash=(
    int=>"MPI_INT:1:d",
    double=>"MPI_DOUBLE:1:d",
    string=>"MPI_CHAR:MPIR_CVAR_MAX_STRLEN:str",
    boolean=>"MPI_INT:1:d",
    range=>"MPI_INT:2:range",
    enum=>"MPI_INT:1:d",
);
my %env_hash=(
    int=>"int",
    double=>"double",
    string=>"str",
    boolean=>"bool",
    range=>"range",
    enum=>"str",
);
my %value_hash=(
    true=>"1",
    false=>"0",
);
my @files;
foreach my $dir (qw(mpi mpi_t nameserv util binding include mpid pmi)){
    open In, "find src/$dir -name '*.[ch]' |" or die "Can't open find src/$dir -name '*.[ch]' |.\n";
    while(<In>){
        chomp;
        push @files, $_;
    }
    close In;
}
foreach my $f (@files){
    my ($in_block, $which, $cvar, $cat);
    open In, "$f" or die "Can't open $f.\n";
    while(<In>){
        if(/^===\s*BEGIN_MPI_T_CVAR_INFO_BLOCK\s*===/){
            $in_block=1;
            undef $cvar;
            undef $cat;
            next;
        }
        elsif(/^===\s*END_MPI_T_CVAR_INFO_BLOCK\s*===/){
            $in_block=0;
            next;
        }
        if(!$in_block){
            next;
        }
        if(/^(categories|cvars)\s*:/){
            $which = $1;
            undef $cvar;
            undef $cat;
        }
        elsif(/^\s*-\s*name\s*:\s*(MPIR_CVAR_\w+)/){
            my ($name) = ($1);
            push @cvars, $name;
            $cvar={file=>$f};
            $cvars{$name} = $cvar;
        }
        elsif(/^\s*-\s*name\s*:\s*(\w+)/){
            my ($name) = ($1);
            push @cats, $name;
            $cat = {file=>$f};
            $cats{$name} = $cat;
        }
        elsif($cvar and /^\s*(category|type|default|class|verbosity|scope|alt-env)\s*:\s*(.+?)\s*$/){
            $cvar->{$1}=$2;
        }
        elsif(/^\s*(description)\s*:\s*(.+?)\s*$/){
            my ($a, $t) = ($1, $2);
            if($t=~/^([>|])-\s*(.*)/){
                my $style=$1;
                $t = $2;
                my $sp;
                while(1){
                    $_=<In>;
                    if(!$sp and /^(\s*)/){
                        $sp = length($1);
                    }
                    if(/^\s*$/){
                        last;
                    }
                    else{
                        chomp;
                        if($t){
                            if($style eq ">"){
                                $t.=" ";
                            }
                            else{
                                $t.="\n";
                            }
                        }
                        $t.=substr($_,$sp);
                    }
                }
            }
            elsif($t=~/^[>\|]/){
                print "Unsupported YAML style: [$_]\n";
            }
            if($cat){
                $cat->{$a}=$t;
            }
            elsif($cvar){
                $cvar->{$a}=$t;
                if($cvar->{type} eq "enum"){
                    my @enum;
                    while($t=~/^\s*(\w+)\s+-\s/mg){
                        push @enum, $1;
                    }
                    $cvar->{enum}=\@enum;
                }
            }
        }
    }
    close In;
}
open Out, ">src/include/mpir_cvars.h" or die "Can't write src/include/mpir_cvars.h.\n";
print "  --> [src/include/mpir_cvars.h]\n";
print Out "#ifndef MPIR_CVARS_H_INCLUDED\n";
print Out "#define MPIR_CVARS_H_INCLUDED\n";
print Out "\n";
print Out "#include \"mpitimpl.h\" /* for MPIR_T_cvar_range_value_t */\n";
print Out "int MPIR_T_cvar_init(void);\n";
print Out "int MPIR_T_cvar_finalize(void);\n";
print Out "\n";
foreach my $v (@cvars){
    my $h=$cvars{$v};
    my $type=$type_hash{$h->{type}};
    my $value=$h->{default};
    if(defined $value_hash{$value}){
        $value=$value_hash{$value};
    }
    elsif($type =~/char\s*\*/){
        if($value eq "NULL"){
        }
        elsif($value!~/^"/){
            $value="\"$value\"";
        }
    }
    elsif($h->{type} eq "range"){
        if($value=~/(\d+):(\d+)/){
            $value="{$1,$2}";
        }
    }
    elsif($h->{type} eq "enum"){
        $value = "$v\_$value";
    }
    print Out "/* $h->{file} */\n";
    print Out "extern $type $v;\n";
    if($h->{enum}){
        print Out "enum $v\_choice {\n";
        my $n = @{$h->{enum}};
        my $i = -1;
        foreach my $a (@{$h->{enum}}){
            $i++;
            if($i<$n-1){
                print Out "    $v\_$a,\n";
            }
            else{
                print Out "    $v\_$a\n";
            }
        }
        print Out "};\n";
    }
}
print Out "\n";
print Out "/* TODO: this should be defined elsewhere */\n";
print Out "#define MPIR_CVAR_assert MPIR_Assert\n";
print Out "\n";
print Out "/* Arbitrary, simplifies interaction with external interfaces like MPI_T_ */\n";
print Out "#define MPIR_CVAR_MAX_STRLEN (384)\n";
print Out "\n";
print Out "#endif /* MPIR_CVARS_H_INCLUDED */\n";
close Out;
open Out, ">src/util/cvar/mpir_cvars.c" or die "Can't write src/util/cvar/mpir_cvars.c.\n";
print "  --> [src/util/cvar/mpir_cvars.c]\n";
print Out "#include \"mpiimpl.h\"\n";
print Out "\n";
my $n = @cvars;
print Out "/* $n cvars */\n";
foreach my $v (@cvars){
    my $h=$cvars{$v};
    my $type=$type_hash{$h->{type}};
    my $value=$h->{default};
    if(defined $value_hash{$value}){
        $value=$value_hash{$value};
    }
    elsif($type =~/char\s*\*/){
        if($value eq "NULL"){
        }
        elsif($value!~/^"/){
            $value="\"$value\"";
        }
    }
    elsif($h->{type} eq "range"){
        if($value=~/(\d+):(\d+)/){
            $value="{$1,$2}";
        }
    }
    elsif($h->{type} eq "enum"){
        $value = "$v\_$value";
    }
    if($h->{class} eq "device"){
        if($v=~/MPIR_CVAR_(\w+)/){
            print Out "#if defined MPID_$1\n";
            print Out "$type $v = MPID_$1;\n";
            print Out "#else\n";
            print Out "$type $v = $value;\n";
            print Out "#endif\n";
        }
    }
    else{
        print Out "$type $v = $value;\n";
    }
    print Out "\n";
}
print Out "#define FCNAME __func__\n";
print Out "int MPIR_T_cvar_init(void)\n";
print Out "{\n";
print Out "    int mpi_errno = MPI_SUCCESS;\n";
print Out "    int rc;\n";
print Out "    const char *tmp_str;\n";
print Out "    static int initialized = FALSE;\n";
print Out "    MPIR_T_cvar_value_t defaultval;\n";
print Out "\n";
print Out "    /* FIXME any MT issues here? */\n";
print Out "    if (initialized)\n";
print Out "        return MPI_SUCCESS;\n";
print Out "    initialized = TRUE;\n";
print Out "\n";
foreach my $c (@cats){
    my $h=$cats{$c};
    my $desc = $h->{description};
    $desc=~s/"/\\"/g;
    print Out "    /* $h->{file} */\n";
    print Out "    MPIR_T_cat_add_desc(\"$c\",\n";
    print Out "        \"$desc\");\n";
    print Out "\n";
}
foreach my $v (@cvars){
    my $h=$cvars{$v};
    my $type=$type_hash{$h->{type}};
    my $value=$h->{default};
    if(defined $value_hash{$value}){
        $value=$value_hash{$value};
    }
    elsif($type =~/char\s*\*/){
        if($value eq "NULL"){
        }
        elsif($value!~/^"/){
            $value="\"$value\"";
        }
    }
    elsif($h->{type} eq "range"){
        if($value=~/(\d+):(\d+)/){
            $value="(MPIR_T_cvar_range_value_t){$1,$2}";
        }
    }
    elsif($h->{type} eq "enum"){
        $value = "$v\_$value";
    }
    my ($mpi_type,$mpi_count,$mpi_field)=split /:/, $mpi_hash{$h->{type}};
    my $mplenv = "MPL_env2$env_hash{$h->{type}}";
    print Out "    defaultval.$mpi_field = $value;\n";
    my $desc = $h->{description};
    $desc=~s/"/\\"/g;
    $desc=~s/\n/\\\n/g;
    print Out "    MPIR_T_CVAR_REGISTER_STATIC(\n";
    print Out "        $mpi_type,\n";
    print Out "        $v, /* name */\n";
    print Out "        &$v, /* address */\n";
    print Out "        $mpi_count, /* count */\n";
    print Out "        $h->{verbosity},\n";
    print Out "        $h->{scope},\n";
    print Out "        defaultval,\n";
    print Out "        \"$h->{category}\", /* category */\n";
    print Out "        \"$desc\");\n";
    if($h->{type} eq "string"){
        print Out "    MPIR_CVAR_GET_DEFAULT_STRING($v, &tmp_str);\n";
    }
    elsif($h->{type} eq "enum"){
        print Out "    tmp_str = NULL;\n";
    }
    my @t;
    if($h->{"alt-env"}){
        foreach my $t (split /[:,;\s]+/, $h->{"alt-env"}){
            $t=~s/\s+$//;
            push @t, $t;
        }
    }
    push @t, $v;
    foreach my $env (@t){
        $env=~s/^MPIR_CVAR_//;
        if($h->{type} eq "string" or $h->{type} eq "enum"){
            print Out "    rc = $mplenv(\"MPICH_$env\", &tmp_str);\n";
        }
        elsif($h->{type} eq "range"){
            print Out "    rc = $mplenv(\"MPICH_$env\", &$v.low, &$v.high);\n";
        }
        else{
            print Out "    rc = $mplenv(\"MPICH_$env\", &$v);\n";
        }
        print Out "    MPIR_ERR_CHKANDJUMP1((-1 == rc),mpi_errno,MPI_ERR_OTHER,\"**envvarparse\",\"**envvarparse %s\",\"MPICH_$env\");\n";
        if($h->{type} eq "string" or $h->{type} eq "enum"){
            print Out "    rc = $mplenv(\"MPIR_PARAM_$env\", &tmp_str);\n";
        }
        elsif($h->{type} eq "range"){
            print Out "    rc = $mplenv(\"MPIR_PARAM_$env\", &$v.low, &$v.high);\n";
        }
        else{
            print Out "    rc = $mplenv(\"MPIR_PARAM_$env\", &$v);\n";
        }
        print Out "    MPIR_ERR_CHKANDJUMP1((-1 == rc),mpi_errno,MPI_ERR_OTHER,\"**envvarparse\",\"**envvarparse %s\",\"MPIR_PARAM_$env\");\n";
        if($h->{type} eq "string" or $h->{type} eq "enum"){
            print Out "    rc = $mplenv(\"MPIR_CVAR_$env\", &tmp_str);\n";
        }
        elsif($h->{type} eq "range"){
            print Out "    rc = $mplenv(\"MPIR_CVAR_$env\", &$v.low, &$v.high);\n";
        }
        else{
            print Out "    rc = $mplenv(\"MPIR_CVAR_$env\", &$v);\n";
        }
        print Out "    MPIR_ERR_CHKANDJUMP1((-1 == rc),mpi_errno,MPI_ERR_OTHER,\"**envvarparse\",\"**envvarparse %s\",\"MPIR_CVAR_$env\");\n";
    }
    if($h->{type} eq "string"){
        print Out "    if (tmp_str != NULL) {\n";
        print Out "        $v = MPL_strdup(tmp_str);\n";
        print Out "        MPIR_CVAR_assert($v);\n";
        print Out "        if ($v == NULL) {\n";
        print Out "            MPIR_CHKMEM_SETERR(mpi_errno, strlen(tmp_str), \"dup of string for $v\");\n";
        print Out "            goto fn_fail;\n";
        print Out "        }\n";
        print Out "    }\n";
        print Out "    else {\n";
        print Out "        $v = NULL;\n";
        print Out "    }\n";
    }
    elsif($h->{type} eq "enum"){
        print Out "    if (tmp_str != NULL) {\n";
        my $c = "if";
        foreach my $t (@{$h->{enum}}){
            print Out "        $c (0 == strcmp(tmp_str, \"$t\"))\n";
            print Out "            $v = $v\_$t;\n";
            $c = "else if";
        }
        print Out "    }\n";
    }
    print Out "\n";
}
print Out "fn_exit:\n";
print Out "    return mpi_errno;\n";
print Out "fn_fail:\n";
print Out "    goto fn_exit;\n";
print Out "}\n";
print Out "\n";
print Out "int MPIR_T_cvar_finalize(void)\n";
print Out "{\n";
print Out "    int mpi_errno = MPI_SUCCESS;\n";
print Out "\n";
foreach my $v (@cvars){
    my $h=$cvars{$v};
    my $type=$type_hash{$h->{type}};
    my $value=$h->{default};
    if(defined $value_hash{$value}){
        $value=$value_hash{$value};
    }
    elsif($type =~/char\s*\*/){
        if($value eq "NULL"){
        }
        elsif($value!~/^"/){
            $value="\"$value\"";
        }
    }
    elsif($h->{type} eq "range"){
        if($value=~/(\d+):(\d+)/){
            $value="{$1,$2}";
        }
    }
    elsif($h->{type} eq "enum"){
        $value = "$v\_$value";
    }
    if($h->{type} eq "string"){
        print Out "    if ($v != NULL) {\n";
        print Out "        MPL_free((void *)$v);\n";
        print Out "        $v = NULL;\n";
        print Out "    }\n";
        print Out "\n";
    }
}
print Out "    return mpi_errno;\n";
print Out "}\n";
close Out;
