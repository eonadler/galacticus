# Contains a Perl module which implements disk inclination calculations for Galacticus.

package Inclinations;
use PDL;
use Galacticus::HDF5;

%HDF5::galacticusFunctions = ( %HDF5::galacticusFunctions,
    "inclination" => "Inclinations::Get_Inclination"
    );

my $status = 1;
$status;

sub Get_Inclination {
    $dataSet = shift;
    $dataSetName = $_[0];
    &HDF5::Get_Dataset($dataSet,["nodeIndex"]);
    $dataSets = \%{${$dataSet}{'dataSets'}};
    ${$dataSets->{"inclination"}} = 180.0*acos(random(nelem(${$dataSets->{"nodeIndex"}})))/3.1415927;
}
