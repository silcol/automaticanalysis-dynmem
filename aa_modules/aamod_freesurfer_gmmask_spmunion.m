% Generate a volumetric GM mask in freesurfer, convert to nifti and
% resample in SPM to EPI resolution.
% [aap,resp]=aamod_freesurfer_gmmask_spmunion(aap,task,subj)
function [aap,resp]=aamod_freesurfer_gmmask_spmunion(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'

        % mask
        mpath = aas_getfiles_bystream(aap,subj,'freesurfer_gmmask');
        % second is EPI
        V = spm_vol(mpath(2,:));
        mask = spm_read_vols(V);
        % spm analysis mask
        spmaskpath = aas_getfiles_bystream(aap,subj,'firstlevel_mask');
        % first is hdr
        spmask = spm_read_vols(spm_vol(spmaskpath(1,:)));
        % intersect
        mask = (mask > 0) & (spmask > 0);
        spm_write_vol(V,mask);
        % and describe
        aap = aas_desc_outputs(aap,subj,'freesurfer_gmmask',mpath);
end
