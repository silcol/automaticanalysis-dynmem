#!/bin/csh -f
#
#         0         	 1	     2      	3
#  run_recon_all.ss  <options>  <subj1_id> <module_path/
#

# set DIR of outputs
setenv SUBJECTS_DIR $argv[3]/$argv[2]/ANAT

# set propper freesurfer home directory
source $FREESURFER_HOME/SetUpFreeSurfer.csh

# run recon-all
if ("$argv[1]" == "hippsegment") then
	recon-all -s $argv[2] -hippo-subfields -cm
else
	recon-all $argv[1]  -s $argv[2] -cm
endif
