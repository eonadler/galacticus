#!/usr/bin/env perl

# Locate Galform2 code files which have dependencies on include files

# Define the source directory
if ( $#ARGV != 0 ) {die "Usage: Find_Include_Dependencies.pl sourcedir"};
my $sourcedir = $ARGV[0];

#
# Open an output file
open(outfile,">$sourcedir/work/build/Makefile_Include_Deps");
#
# Build a list of source directories.
$sourcedirs[0] = $sourcedir."/source";
$bases[0] = "";
if ( -e $sourcedir."/Source_Codes" ) {
    opendir(sdir,"$sourcedir/Source_Codes");
    while ( $line = readdir sdir ) {
	$line =~ s/\n//;
	if ( -d $sourcedir."/Source_Codes/".$line ) {
	    unless ( $line =~ m/^\.+$/ ) {
		$sourcedirs[++$#sourcedirs] = $sourcedir."/Source_Codes/".$line;
		$bases[++$#bases] = "Source_Codes/".$line."/";
	    }
	}
    }
    closedir(sdir);
}

# Array of all auto-generated include files.
@All_Auto_Includes = ();

#
# Open the source directory
#
$ibase=-1;
foreach $srcdir ( @sourcedirs ) {
    ++$ibase;
    $base = $bases[$ibase];
    opendir(indir,$srcdir) or die "Can't open the source directory: #!";
    while (my $fname = readdir indir) {
	
	if ( lc($fname) =~ m/\.f(90)??t??$/ && lc($fname) !~ m/^\.\#/ ) {
	    my $pname = $fname;
	    my $fullname = "$srcdir/$fname";
	    my $doesio = 0;
	    open(infile,$fullname) or die "Can't open input file: #!";
	    @fileinfo=stat infile;
	    
	    my $hasincludes = 0;
	    my $oname = $fname;
	    $oname =~ s/\.f90$/\.o/;
	    $oname =~ s/\.F90$/\.o/;
	    $oname =~ s/\.f90t$/\.o/;
	    $oname =~ s/\.F90t$/\.o/;
	    $oname =~ s/\.f$/\.o/;
	    $oname =~ s/\.F$/\.o/;
	    @incfiles = ();
	    while (my $line = <infile>) {
# Locate any lines which use the "include" statement and extract the name of the file they include
		if ( $line =~ m/^\s*#??include\s*['"](.+\.inc\d*)['"]/ ) {
		     my $incfile = $1." ";
		     if ( $hasincludes == 0 ) {$hasincludes = 1};
		     @incfiles = ( @incfiles, $incfile);
		 }
	    }
# Process output for files which had include statements
	    if ( $hasincludes == 1 ) {
# Sort the list of included files
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
# Output the dependencies
		print outfile "./work/build/".$base,$oname,":";
		foreach $inc ( @sortedinc ) {
		    $inc =~ s/\s*$//;
		    ($Iinc = $inc) =~ s/\.inc$/\.Inc/;
		    $ext_inc = $srcdir."/".$inc;
		    $ext_Iinc = $srcdir."/".$Iinc;
		    if ( -e $ext_Iinc ) {
			if ( $ibase == 0 ) {
			    print outfile " ./work/build/$inc";
			    if ( $inc =~ m/\.inc$/ ) {$All_Auto_Includes[++$#All_Auto_Includes]=$Iinc};
			} else {
			    print outfile " ./work/build/$srcdir/$inc";
			    if ( $inc =~ m/\.inc$/ ) {$All_Auto_Includes[++$#All_Auto_Includes]=$srcdir."/".$Iinc};			}
		    } elsif ( -e $ext_inc ) {
			if ( $ibase == 0 ) {
			    print outfile " ./work/build/$inc";
			    if ( $inc =~ m/\.inc$/ ) {$All_Auto_Includes[++$#All_Auto_Includes]=$inc};
			} else {
			    print outfile " ./work/build/$srcdir/$inc";
			    if ( $inc =~ m/\.inc$/ ) {$All_Auto_Includes[++$#All_Auto_Includes]=$srcdir."/".$inc};
			}
		    } else {
			print outfile " ./work/build/$inc";
			if ( $inc =~ m/\.inc$/ ) {$All_Auto_Includes[++$#All_Auto_Includes]=$inc};
		    }
		}
		print outfile "\n\n";
	    }
	    close(infile);
	}
    }
    closedir(indir);
}
print outfile "\n./work/build/Makefile_Use_Deps: ./work/build/".join(" ./work/build/",@All_Auto_Includes)."\n";
close(outfile);
