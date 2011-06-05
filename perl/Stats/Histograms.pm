# Contains a Perl module which implements calculations of binned histograms of weighted data.

package Histograms;
use PDL;
use Data::Dumper;

my $status = 1;
$status;

sub Histogram {
    # Distribute input data into specified bins, find the total weight and the error.

    # Get the arguments.
    $binCenters  = shift;
    $xValues     = shift;
    $weights     = shift;
    if ( $#_ >= 1 ) {(%options) = @_};

    # Compute bin size.
    $binWidth = ($binCenters->index(nelem($binCenters)-1)-$binCenters->index(0))/(nelem($binCenters)-1);

    # Compute bin ranges.
    $binMinimum = $binCenters-0.5*$binWidth;
    $binMaximum = $binCenters+0.5*$binWidth;

    # Create a PDL for histogram and errors.
    $histogram = pdl zeroes(nelem($binCenters));
    $errors    = pdl zeroes(nelem($binCenters));

    # Loop through bins.
    for($iBin=0;$iBin<nelem($binCenters);++$iBin) {
	# Select properties in this bin.
	$weightsSelected = where($weights,$xValues >= $binMinimum->index($iBin) & $xValues < $binMaximum->index($iBin) );

        # Only compute results for cases where we have more than one entry.
	if ( nelem($weightsSelected) > 1 ) {	

	    # Sum up the weights in the bin.
	    $histogram->index($iBin) .= sum($weightsSelected);
	    $errors   ->index($iBin) .= sqrt(sum($weightsSelected**2));

	} else {

	    # No values in this bin - return all zeroes.
	    $histogram->index($iBin) .= 0.0;
	    $errors   ->index($iBin) .= 0.0;

	}

    }

    # Process the histogram according to any options specified.
    if ( exists($options{'normalized'}) ) {
	# Find the total weight.
	$total = sum($weights);
	# Normalize the curve to unit area.
	$errors    /= $total;
	$histogram /= $total;
    }
    if ( exists($options{'differential'}) ) {
	# Divide by the bin width to get a differential distribution.
	$errors    /= $binWidth;
	$histogram /= $binWidth;
    }

    # Return the results.
    return ($histogram,$errors);
}
