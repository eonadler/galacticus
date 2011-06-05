#!/usr/bin/env perl

# Locate Galform2 code files which have dependencies on modules

# Define the source directory
if ( $#ARGV != 0 && $#ARGV != 1 ) {die "Usage: Find_Use_Dependencies.pl sourcedir"};
my $sourcedir = $ARGV[0];
if ( $#ARGV == 1 ) { my $make = $ARGV[1] } else { my $make = "make" }

# Specify work directory.
$workDir = "/work/build/";

# List of modules to ignore (as they're external to the source code).
%ignoreList = (
    "omp_lib" => 1,
    "hdf5" => 1,
    "h5tb" => 1,
    "h5lt" => 1,
    "h5global" => 1,
    "h5fortran_types" => 1,
    "fox_dom" => 1,
    "fox_wxml" => 1,
    "fgsl" => 1
    );

# Open the compiler options file and find preprocessor flags.
foreach $makefile ( "./work/build/Makefile_Compiler_Options", "./work/build/Makefile_New_Rules" ) {
    open(ophndl,$makefile);
    while ( $line = <ophndl> ) {
        if ( $line =~ m/^\s*F90_options\s*\+??=/ ) {
            while ( $line =~ s/\s\-D([0-9A-Z]+)\s// ) {
                $preprocs[++$#preprocs] = $1;
            }
        }
    }
    close(ophndl);
}

# Open an output file
open(outfile,">$sourcedir/work/build/Makefile_Use_Deps");

#
# Build a list of source directories.
$sourcedirs[0] = $sourcedir."/source";
$bases[0] = "";
if ( -e $sourcedirs[0] ) {
    opendir(sdir,$sourcedirs[0]);
    while ( $line = readdir sdir ) {
	$line =~ s/\n//;
	if ( -d $sourcedirs[0]."/".$line ) {
	    unless ( $line =~ m/^\.+$/ ) {
		$sourcedirs[++$#sourcedirs] = $sourcedirs[0]."/".$line;
		$bases[++$#bases] = $line."/";
	    }
	}
    }
    closedir(sdir);
}

#
# Open the source directorys and scan
#
$ibase=-1;
foreach $srcdir ( @sourcedirs ) {
    ++$ibase;
    $base = $bases[$ibase];
    opendir(indir,$srcdir) or die "Can't open the source directory: #!";
    while (my $fname = readdir indir) {

	if ( ( ( ( lc($fname) =~ m/\.f(90)??$/ ) && ! -e $srcdir."/".$fname."t" ) || ( lc($fname) =~ m/\.f90t$/ ) ) && lc($fname) !~ m/^\.\#/ ) {	    
	    my $pname = $fname;
	    my $fullname = "$srcdir/$fname";
	    my $doesio = 0;
	    my $hasuses = 0;
	    my $oname = $fname;
	    $oname =~ s/\.f90$/\.o/;
	    $oname =~ s/\.F90$/\.o/;
	    $oname =~ s/\.f90t$/\.o/;
	    $oname =~ s/\.F90t$/\.o/;
	    $oname =~ s/\.f$/\.o/;
	    $oname =~ s/\.F$/\.o/;
	    @incfiles = ();
	    @modfiles = ();
	    @extra_includes = ();

	    $scanfiles[++$#scanfiles] = $fullname;
	    while ( $#scanfiles >= 0 ) {
		$fullname = $scanfiles[$#scanfiles];
		--$#scanfiles;
		if ( ! -e $fullname ) {
		    if ( $fullname =~ m/\/([\w\.]+?)$/ ) {
			$leaf = $1;
		    } else {
			$leaf=$fullname;
		    }
		    system("$make $leaf");
		}
		@preproc_stack_name = ();
		@preproc_stack_state = ();
		$active = 1;
		open(infile,$fullname) or die "Can't open input file: $fullname";
		while (my $line = <infile>) {
		    if ( $line =~ m/^\#/ ) {
			if ( $line =~ m/^\#ifdef\s+([0-9A-Z_]+)\s*$/ ) {
			    $this_preproc = $1;
			    $preproc_stack_name[++$#preproc_stack_name] = $this_preproc;
			    $preproc_stack_state[++$#preproc_stack_state] = 1;
			}
			if ( $line =~ m/^\#ifndef\s+([0-9A-Z_]+)\s*$/ ) {
			    $this_preproc = $1;
			    $preproc_stack_name[++$#preproc_stack_name] = $this_preproc;
			    $preproc_stack_state[++$#preproc_stack_state] = 0;
			}
			if ( $line =~ m/^\#endif\s*$/ ) {
			    --$#preproc_stack_name;
			    --$#preproc_stack_state;
			}
			if ( $line =~ m/^\#else\s*$/ ) {
			    $preproc_stack_state[$#preproc_stack_state] = 1-$preproc_stack_state[$#preproc_stack_state];
			}
			$active = 1;
			for($i=0;$i<=$#preproc_stack_state;++$i) {
			    if ( $preproc_stack_state[$i] == 1 ) {
				$this_active = 0;
				foreach $preproc ( @preprocs ) {
				    if ( $preproc eq $preproc_stack_name[$i] ) {$this_active = 1};
				}
			    } else {
				$this_active = 1;
				foreach $preproc ( @preprocs ) {
				    if ( $preproc eq $preproc_stack_name[$i] ) {$this_active = 0};
				}
			    }
			    if ( $this_active == 0 ) {$active=0};
			}
		    }
		    if ( $active == 1 ) {
# Locate any lines which use the "use" statement and extract the name of the file they use. (We ignore the "hdf5" module as it is external.)
			if ( $line =~ m/^\s*use\s+([a-zA-Z0-9_]+)/i ) {
			    $incfile = $1;
			    unless ( $incfile =~ m/^hdf5$/i || exists($ignoreList{lc($incfile)}) ) {
				$incfile .= ".mod ";
				$incfile =~ s/\r//g;
				@incfiles = ( @incfiles, $workDir.lc($incfile));
				$hasuses = 1;
			    }
			}
			if ( $line =~ m/^\s*\!:\s*(.*)$/ ) {
			    $includes = $1;
			    @includes = split(/\s+/,$1);
			    push(@extra_includes,@includes);
			    $hasuses = 1;
			}
			if ( $line =~ m/^\s*module / ) {
			    my $startpos = index($line,"module")+7;
			    my $sublen = length($line)-$startpos-1;
			    my $incfile = substr($line,$startpos,$sublen).".mod ";
			    @modfiles = ( @modfiles, lc($incfile));
			}
			if ( $line =~ m/^\s*include\s+\'([\w\.\-]+)\'/i ) {
			    $ifile = $1;
			    if ( -e $sourcedir."/work/build/".$ifile ) {$scanfiles[++$#scanfiles] = $sourcedir."/work/build/".$ifile};
			}
		    }
		}
		close(infile);
	    }

# Process output for files which had use statements
	    if ( $hasuses == 1 ) {
# Sort the list of used files
		@sortedinc = sort @incfiles;
# Remove any duplicate entries
		if ($#sortedinc > 0) {
		    for ($i = 1; $i <= $#sortedinc; $i += 1) {
			if ($sortedinc[$i] eq $sortedinc[$i-1]) {
			    if ( $i < $#sortedinc ) {
				for ($j = $i; $j < $#sortedinc; $j += 1) {
				    $sortedinc[$j] = $sortedinc[$j+1];
				}
			    }
			    $i -= 1;
			    $#sortedinc -= 1;
			}
		    }
		}
		
		for ($i = 0; $i <= $#sortedinc; $i += 1) {
		    foreach $item (@modfiles) {
			if ( $sortedinc[$i] eq $item ) {
			    if ( $i < $#sortedinc ) {
				for ($j = $i; $j < $#sortedinc; $j += 1) {
				    $sortedinc[$j] = $sortedinc[$j+1];
				}
			    }
			    $i -= 1;
			    $#sortedinc -= 1;
			    last;
			}
		    }
		}
		
# Output the dependencies
		if ($#sortedinc >= 0 || $#extra_includes >= 0) {
		    print outfile ".".$workDir.$base.$oname,": ";
		    if ( $#sortedinc >= 0 ) {print outfile ".",join(".",@sortedinc)};
		    print outfile " Makefile";
		    foreach $extra_include ( @extra_includes ) {
			print outfile " $extra_include";
		    }
		    print outfile "\n";
		    for ($i = 0; $i <= $#sortedinc; $i += 1) {
			$sortedinc[$i] =~ s/.mod\s$/.mod.d /;
		    }
		    $dname = $oname;
		    $dname =~ s/.o$/.d/;
		    print outfile ".".$workDir.$base.$dname,": ";
		    if ( $#sortedinc >= 0 ) {print outfile ".",join(".",@sortedinc)};
		    print outfile "\n";
		    print outfile "\t\@echo .$workDir$base$oname > .$workDir$base$dname\n";
		    foreach $extra_include ( @extra_includes ) {
			if ( $extra_include =~ m/\// ) {
			print outfile "\t\@echo $extra_include >> .$workDir$base$dname\n";
			} else {
			print outfile "\t\@echo .$workDir$extra_include >> .$workDir$base$dname\n";
			}
		    }
		    foreach $item (@sortedinc) {
			$item =~ s/\s+$//;
			$dditem = $item."d";
			print outfile "\t\@cat .$item >> .$workDir$base$dname\n";
		    }
		    print outfile "\t\@sort -u .$workDir$base$dname -o .$workDir$base$dname\n\n";
		}
	    }
	}
    }
    closedir(indir);
}
