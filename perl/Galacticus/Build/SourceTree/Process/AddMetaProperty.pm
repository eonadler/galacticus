# Contains a Perl module which implements adding of meta properties.

package Galacticus::Build::SourceTree::Process::AddMetaProperty;
use strict;
use warnings;
use utf8;
use Cwd;
use lib $ENV{'GALACTICUS_EXEC_PATH'}."/perl";
use Data::Dumper;
use XML::Simple;
use LaTeX::Encode;
use List::ExtraUtils;
use Fortran::Utils;
use Galacticus::Build::Directives;

# Insert hooks for our functions.
$Galacticus::Build::SourceTree::Hooks::processHooks{'addMetaProperty'} = \&Process_AddMetaProperty;

sub Process_AddMetaProperty {
    # Get the tree.
    my $tree = shift();
    # Get an XML parser.
    my $xml = new XML::Simple();
    # Get the file name.
    my $fileName;
    $fileName = $tree->{'name'}
        if ( $tree->{'type'} eq "file" );
    # Walk the tree, looking for input parameter validation directives.
    my $node  = $tree;
    my $depth = 0;
    while ( $node ) {
	# Look for addMetaProperty directives and process them.
	if ( $node->{'type'} eq "addMetaProperty" && ! $node->{'directive'}->{'processed'} ) {	    
	    # Record that this directive has been processed.
	    $node->{'directive'}->{'processed'} =  1;
	    # Set defaults.
	    $node->{'directive'}->{'type'       } = "real"
		unless ( exists($node->{'directive'}->{'type'       }) );
	    $node->{'directive'}->{'isEvolvable'} = "no"
		unless ( exists($node->{'directive'}->{'isEvolvable'}) );
	    $node->{'directive'}->{'isCreator'  } = "no"
		unless ( exists($node->{'directive'}->{'isCreator'  }) );
	    # Validate.
	    die("non-real meta-properties can not be evolvable")
		if ( $node->{'directive'}->{'isEvolvable'} eq "yes" && $node->{'directive'}->{'type'} ne "real" );
	    # Construct default component.
	    my $component  = "default".ucfirst($node->{'directive'}->{'component'})."Component";
	    # Construct type prefix.
	    my $typePrefix = $node->{'directive'}->{'type'} eq "real" ? "" : ucfirst($node->{'directive'}->{'type'});
	    # Initialize new code.
	    my %boolean = ( no => ".false.", yes => ".true." );
	    my $code = $node->{'directive'}->{'id'}."=".$component."%add".$typePrefix."MetaProperty(var_str('".$node->{'directive'}->{'name'}."'),'".$node->{'directive'}->{'component'}.":".$node->{'directive'}->{'name'}."',isCreator=".$boolean{$node->{'directive'}->{'isCreator'}}.($node->{'directive'}->{'type'} eq "real" ? ",isEvolvable=".$boolean{$node->{'directive'}->{'isEvolvable'}} : "").")\n";
	    # Add module usage.
	    &Galacticus::Build::SourceTree::Parse::ModuleUses::AddUses(
		$node->{'parent'},
		{
		    moduleUse =>
		    {
			ISO_Varying_String => {only => {var_str    => 1}},
			Galacticus_Nodes   => {only => {$component => 1}}
		    }
		}
		);
	    # Insert new code.
	    my $codeNode =
	    {
		type       => "code"           ,
		content    => $code            ,
		sibling    => undef()          ,
		parent     => $node->{'parent'},
		firstChild => undef()
	    };
	    &Galacticus::Build::SourceTree::InsertAfterNode($node,[$codeNode]);
	}
	$node = &Galacticus::Build::SourceTree::Walk_Tree($node,\$depth);
    }
}

1;
