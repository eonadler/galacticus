#!/usr/bin/env perl
use lib "./perl";
use PDL;
use XML::Simple;
use Graphics::GnuplotIF;
use Galacticus::HDF5;
use Astro::Cosmology;
use Math::SigFigs;

# Get name of input and output files.
if ( $#ARGV != 1 && $#ARGV != 2 ) {die("Plot_Star_Formation_History.pl <galacticusFile> <outputDir/File> [<showFit>]")};
$galacticusFile = $ARGV[0];
$outputTo       = $ARGV[1];
if ( $#ARGV == 2 ) {
    $showFit    = $ARGV[2];
    if ( lc($showFit) eq "showfit"   ) {$showFit = 1};
    if ( lc($showFit) eq "noshowfit" ) {$showFit = 0};
} else {
    $showFit = 0;
}

# Get parameters for the Galacticus model.
$dataSet{'file'} = $galacticusFile;
&HDF5::Get_Parameters(\%dataSet);

# Check if output location is file or directory.
if ( $outputTo =~ m/\.pdf$/ ) {
    $outputFile = $outputTo;
} else {
    system("mkdir -p $outputTo");
    $outputFile = $outputTo."/Star_Formation_History.pdf";
}

# Extract global data
&HDF5::Get_History(\%dataSet,['historyExpansion','historyStarFormationRate']);
$history = \%{$dataSet{'history'}};
$redshift = 1.0/${$history->{'historyExpansion'}}-1.0;
$SFR = ${$history->{'historyStarFormationRate'}}/1.0e9;

# Read the XML data file.
$xml = new XML::Simple;
$data = $xml->XMLin("data/Star_Formation_Rate_Data.xml");
$iDataset = -1;
$chiSquared = 0.0;
$degreesOfFreedom = 0;
foreach $dataSet ( @{$data->{'starFormationRate'}} ) {
    $columns = $dataSet->{'columns'};
    $x = pdl @{$columns->{'redshift'}->{'data'}};
    $xLowerError = pdl @{$columns->{'redshiftErrorDown'}->{'data'}};
    $xUpperError = pdl @{$columns->{'redshiftErrorUp'}->{'data'}};
    $xLowerError = $x-$xLowerError;
    $xUpperError = $x+$xUpperError;
    $y = pdl @{$columns->{'sfr'}->{'data'}};
    $yLowerError = pdl @{$columns->{'sfrErrorDown'}->{'data'}};
    $yUpperError = pdl @{$columns->{'sfrErrorUp'}->{'data'}};
    $yUpperError = (10.0**($y+$yUpperError));
    $yLowerError = (10.0**($y-$yLowerError));
    $y = (10.0**$y);

    # Compute cosmology corrections.
    $cosmologyData = Astro::Cosmology->new(
	omega_matter => $columns->{'sfr'}->{'omega'},
	omega_lambda => $columns->{'sfr'}->{'lambda'},
	H0           => $columns->{'sfr'}->{'hubble'}
	);
    $cosmologyGalacticus = Astro::Cosmology->new(
	omega_matter => $dataSet{'parameters'}->{'Omega_0'},
	omega_lambda => $dataSet{'parameters'}->{'Lambda_0'},
	H0           => $dataSet{'parameters'}->{'H_0'}
	);
    $volumeElementData            = $cosmologyData      ->differential_comoving_volume($x);
    $volumeElementGalacticus      = $cosmologyGalacticus->differential_comoving_volume($x);
    $luminosityDistanceData       = $cosmologyData      ->luminosity_distance         ($x);
    $luminosityDistanceGalacticus = $cosmologyGalacticus->luminosity_distance         ($x);
    $cosmologyCorrection = ($volumeElementData/$volumeElementGalacticus)*($luminosityDistanceGalacticus/$luminosityDistanceData)**2;
    
    # Apply cosmology corrections.
    $y           = $y          *$cosmologyCorrection;
    $yUpperError = $yUpperError*$cosmologyCorrection;
    $yLowerError = $yLowerError*$cosmologyCorrection;

    # Store the dataset.
    ++$iDataset;
    $dataSets[$iDataset]->{'x'}           = $x          ;
    $dataSets[$iDataset]->{'xLowerError'} = $xLowerError;
    $dataSets[$iDataset]->{'xUpperError'} = $xUpperError;
    $dataSets[$iDataset]->{'y'}           = $y          ;
    $dataSets[$iDataset]->{'yLowerError'} = $yLowerError;
    $dataSets[$iDataset]->{'yUpperError'} = $yUpperError;
    $dataSets[$iDataset]->{'label'}       = $dataSet->{'label'};

    # Interpolate model to data points and compute chi^2.
    ($sfrInterpolated,$error) = interpolate($x,$redshift,$SFR);
    $chiSquared += sum((($y-$sfrInterpolated)/(0.5*($yUpperError-$yLowerError)))**2);
    $degreesOfFreedom += nelem($y);
}

# Display chi^2 information if requested.
if ( $showFit == 1 ) {
    $fitData{'name'} = "Volume averaged star formation rate history.";
    $fitData{'chiSquared'} = $chiSquared;
    $fitData{'degreesOfFreedom'} = $degreesOfFreedom;
    $xmlOutput = new XML::Simple (NoAttr=>1, RootName=>"galacticusFit");
    print $xmlOutput->XMLout(\%fitData);
}

# Make the plot.
$plot1  = Graphics::GnuplotIF->new();
$plot1->gnuplot_hardcopy( '| ps2pdf - '.$outputFile, 
			  'postscript enhanced', 
			  'color lw 3 solid' );
$plot1->gnuplot_set_xlabel("z");
$plot1->gnuplot_set_ylabel("~{/Symbol r}{0.5 .} [M_{{/=12 O}&{/*-.66 O}{/=12 \267}}/yr/Mpc^{-3}]");
$plot1->gnuplot_set_title("Star Formation Rate History");
$plot1->gnuplot_cmd("set label \"{/Symbol c}^2=".FormatSigFigs($chiSquared,4)." [".$degreesOfFreedom."]\" at screen 0.6, screen 0.2");
$plot1->gnuplot_cmd("set logscale y");
$plot1->gnuplot_cmd("set xrange [-0.25:9.0]");
$plot1->gnuplot_cmd("set yrange [0.005:1.0]");
$plot1->gnuplot_cmd("set mxtics 2");
$plot1->gnuplot_cmd("set mytics 10");
$plot1->gnuplot_cmd("set format y \"10^{\%L}\"");
$plot1->gnuplot_cmd("set pointsize 1.0");
$gnuplotCommand = "plot";
$join = "";
for($iDataset=0;$iDataset<=$#dataSets;++$iDataset) {
   $gnuplotCommand .= $join." '-' with xyerrorbars pt 6 title \"".$dataSets[$iDataset]->{'label'}."\"";
   $join = ",";
}
$gnuplotCommand .= ", '-' with lines title \"Galacticus\"";
$plot1->gnuplot_cmd($gnuplotCommand);
for($iDataset=0;$iDataset<=$#dataSets;++$iDataset) {
   for ($i=0;$i<nelem($dataSets[$iDataset]->{'x'});++$i) {
      $plot1->gnuplot_cmd($dataSets[$iDataset]->{'x'}->index($i)." ".$dataSets[$iDataset]->{'y'}->index($i)." ".$dataSets[$iDataset]->{'xLowerError'}->index($i)." ".$dataSets[$iDataset]->{'xUpperError'}->index($i)." ".$dataSets[$iDataset]->{'yLowerError'}->index($i)." ".$dataSets[$iDataset]->{'yUpperError'}->index($i));
   }
   $plot1->gnuplot_cmd("e");
}
for ($i=0;$i<nelem($redshift);++$i) {
   $plot1->gnuplot_cmd($redshift->index($i)." ".$SFR->index($i));
}
$plot1->gnuplot_cmd("e");

exit;
