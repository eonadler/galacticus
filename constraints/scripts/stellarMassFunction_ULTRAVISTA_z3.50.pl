#!/usr/bin/env perl
use strict;
use warnings;
my $galacticusPath;
if ( exists($ENV{"GALACTICUS_ROOT_V093"}) ) {
 $galacticusPath  = $ENV{"GALACTICUS_ROOT_V093"};
 $galacticusPath .= "/" unless ( $galacticusPath =~ m/\/$/ );
} else {
 $galacticusPath  = "./";
}
unshift(@INC,$galacticusPath."perl"); 
use PDL;
use PDL::IO::HDF5;
require Galacticus::Options;
require Galacticus::Constraints::MassFunctions;

# Compute likelihood (and make a plot) for a Galacticus model given the stellar mass function data from Muzzin et al. (2013;
# http://adsabs.harvard.edu/abs/2013ApJ...777...18M).

# Data structure to hold the specification for our mass function.
my $massFunctionConfig;

# Get name of input and output files.
die("stellarMassFunction_ULTRAVISTA_z3.50.pl <galacticusFile> [options]") unless ( scalar(@ARGV) >= 1 );
$massFunctionConfig->{'self'          } = $0;
$massFunctionConfig->{'galacticusFile'} = $ARGV[0];
# Create a hash of named arguments.
my $iArg = -1;
my %arguments =
    (
     quiet => 0
    );
&Options::Parse_Options(\@ARGV,\%arguments);

# Specify the properties of this mass function.
my $entry                                    = 0;
$massFunctionConfig->{'redshift'           } = pdl 3.50;
$massFunctionConfig->{'analysisLabel'      } = "ultravistaStellarMassFunctionZ3.50";
$massFunctionConfig->{'discrepancyFileName'} = "discrepancy".ucfirst($massFunctionConfig->{'analysisLabel'}).".hdf5";
$massFunctionConfig->{'massType'           } = "stellarMass";
$massFunctionConfig->{'massErrorRandomDex' } = 0.2;
$massFunctionConfig->{'xRange'             } = "5.0e10:2.0e12";
$massFunctionConfig->{'yRange'             } = "3.0e-8:3.0e-3";
$massFunctionConfig->{'xLabel'             } = "\$M_\\star\$ [\$M_\\odot\$]";
$massFunctionConfig->{'yLabel'             } = "\${\\rm d}n/{\\rm d}\\log M_\\star\$ [Mpc\$^{-3}\$]";
$massFunctionConfig->{'title'              } = "Stellar mass function at \$z\\approx 3.50\$";
$massFunctionConfig->{'systematicParameter'} = "ultravistaStellarMassFunctionZ3.50MassSystematic";
$massFunctionConfig->{'systematicOrder'    } = 1;
$massFunctionConfig->{'systematicZeroPoint'} = 11.3;

# Read the observed data.
my $observations                                      = new PDL::IO::HDF5($galacticusPath."data/observations/massFunctionsStellar/Stellar_Mass_Function_ULTRAVISTA_2013_z3.00_4.00.hdf5");
$massFunctionConfig ->{'x'                           }  = $observations->dataset('mass'                )->get    (                  );
$massFunctionConfig ->{'y'                           }  = $observations->dataset('massFunctionObserved')->get    (                  );
$massFunctionConfig ->{'yIsPer'                      }  = "ln";
$massFunctionConfig ->{'xScaling'                    }  = "linear";
$massFunctionConfig ->{'yScaling'                    }  = "linear";
$massFunctionConfig ->{'covariance'                  }  = $observations->dataset('covariance'          )->get    (                  );
($massFunctionConfig->{'observationLabel'            }) = $observations                                 ->attrGet('label'           );
($massFunctionConfig->{'hubbleConstantObserved'      }) = $observations->group  ('Parameters'          )->attrGet('H_0'             );
($massFunctionConfig->{'omegaMatterObserved'         }) = $observations->group  ('Parameters'          )->attrGet('Omega_Matter'    );
($massFunctionConfig->{'omegaDarkEnergyObserved'     }) = $observations->group  ('Parameters'          )->attrGet('Omega_DE'        );
($massFunctionConfig->{'cosmologyScalingMass'        }) = $observations->dataset('mass'                )->attrGet('cosmologyScaling');
($massFunctionConfig->{'cosmologyScalingMassFunction'}) = $observations->dataset('massFunction'        )->attrGet('cosmologyScaling');

# Construct the mass function.
&MassFunctions::Construct(\%arguments,$massFunctionConfig);

exit;
