% AA module - estimate firstlevel_spm model
% [aap,resp]=aamod_firstlevel_estimate(aap,task,subj)
function [aap,resp]=aamod_firstlevel_estimate(aap,task,subj)

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
        % (maybe disable auto mask, set explicit mask?) Apparently must be
        % done after spm_fmri_spm_ui
        spm_unlink(fullfile('.', 'mask.img')); % avoid overwrite dialog
        spm_spm(SPM);
        cd(cwd);
        % Describe outputs
        %  firstlevel_spm
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',fullfile(anadir,'SPM.mat'));
        
        %  firstlevel_betas (includes related statistical files)
        allbetas=dir(fullfile(anadir,'beta_*'));
        betafns=[];
        for betaind=1:length(allbetas);
            betafns=strvcat(betafns,fullfile(anadir,allbetas(betaind).name));
        end
        aap=aas_desc_outputs(aap,subj,'firstlevel_betas',betafns);
        % separate stream makes more sense here
        others = [];
        otherfiles={'ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        for otherind=1:length(otherfiles)
            others=strvcat(others,fullfile(anadir,otherfiles{otherind}));
        end
        aap=aas_desc_outputs(aap,subj,'firstlevel_residuals',others);
        % and here
        aap = aas_desc_outputs(aap,subj,'firstlevel_mask',...
            {fullfile(anadir,'mask.hdr'),fullfile(anadir,'mask.img')});
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
