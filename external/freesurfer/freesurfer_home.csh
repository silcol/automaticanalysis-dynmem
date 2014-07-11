#!/bin/csh -f
#
#     0         
#  freesurfer_home.ss 
#
#


#Initialize FreeSurfer
#tcsh
source $FREESURFER_HOME/SetUpFreeSurfer.csh
recon-all -autorecon1 -s s120525182852

