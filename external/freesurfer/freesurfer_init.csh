#!/bin/csh -f
#
#         0         	 1	           
#  freesurfer_init.csh <subj1_id> 
#

# set DIR of outputs
setenv SUBJECTS_DIR /home/memspa/benste/fMRI_AttDyn_HippForm/Processing/aamod_freesurfer_autorecon1_00001/$argv[1]/ANAT

# set propper freesurfer home directory
source $FREESURFER_HOME/SetUpFreeSurfer.csh
