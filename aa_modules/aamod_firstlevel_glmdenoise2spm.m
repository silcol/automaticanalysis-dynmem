% Return GLM denoised EPIs to SPM pathway for further processing (the
% data should come out ready for spm_firstlevel_estimate). 

function [aap,resp]=aamod_firstlevel_glmdenoise2epi(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='make EPIs of glmdenoise and update SPM.mat';
    case 'doit'
        % model (convolved design matrix, so after aamod_firstlevel_design)
        cwd=pwd;
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        SPM = loadbetter(spmpath);

        % glmdenoised epis
        denoisepath = aas_getfiles_bystream(aap,subj,'glmdenoise_epi');
        % put epis in this directory
        denoisedir = fileparts(denoisepath);
        denepi = loadbetter(denoisepath);
        % also results for r2 masking
        glpath = aas_getfiles_bystream(aap,subj,'glmdenoise_results');
        results = loadbetter(glpath);
        % restrict to voxels with reasonable r2 and EPI intensity (by same
        % brightness threshold as in GLMdenoise)
        badinds = results.R2 < aap.tasklist.currenttask.settings.minr2;
        % optionally mask by bright voxels too
        if aap.tasklist.currenttask.settings.masknonbrightvoxels
            badinds = badinds | ~results.bright; 
        end

        % BET mask for returning data to 3D and to serve as explicit mask
        % for SPM
        mpath = aas_getfiles_bystream(aap,subj,'epiBETmask');
        % first mask is the brain mask
        Vmask = spm_vol(mpath(1,:));
        mask = spm_read_vols(Vmask) > 0;
        % indices for mapping glmdenoise results to vol
        maskinds = find(mask);
        % update mask with badinds
        masknbefore = length(maskinds);
        mask(maskinds(badinds)) = false;
        maskinds = find(mask);
        masknafter = length(maskinds);
        nremoved = masknbefore - masknafter;
        if nremoved>0
            fprintf('removed %d dark or poor R2 voxels (%.2f%% of total)\n',...
              nremoved,100 * nremoved / masknbefore);
        end
        % save new mask so SPM can get it during spm_firstlevel_estimate
        Vmask.fname = deblank(mpath(1,:));
        spm_write_vol(Vmask,mask);
        aap=aas_desc_outputs(aap,subj,'epiBETmask',mpath);

        % strip bad voxels from epis
        nruns = length(denepi);
        for r = 1:nruns
            denepi{r} = denepi{r}(~badinds,:);
        end

        % optionally use the models from glmdenoise in the SPM design
        % matrix
        if aap.tasklist.currenttask.settings.domodel
            models = results.inputs.design;
        else
            models = [];
        end

        % run the beast
        SPM = glmdenoise2spm(SPM,denepi,models,mask,denoisedir);

        % set SPM explicit mask
        SPM.xM.VM = Vmask;
        % ... and we're done
        save(spmpath,'SPM');
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',spmpath);

    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
