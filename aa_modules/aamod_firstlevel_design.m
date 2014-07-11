% AA module - create convolved design matrix for firstlevel_spm model
% [aap,resp]=aamod_firstlevel_design(aap,task,subj)
function [aap,resp]=aamod_firstlevel_design(aap,task,subj)

resp='';

switch task
    case 'report'
    case 'doit'
        %get subject directory
        cwd=pwd;
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        load(spmpath);
        anadir = fileparts(spmpath);
        cd(anadir)
        SPMdes = spm_fmri_spm_ui(SPM);
        cd(cwd);
        % Describe outputs
        %  firstlevel_spm
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',fullfile(anadir,'SPM.mat'));
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
