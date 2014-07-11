% Fit with GLMdenoise from KK.

function [aap,resp]=aamod_firstlevel_glmdenoise(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='run GLMDenoise';
        
    case 'summary'
        
    case 'report'
        
    case 'doit'
        % model (convolved design matrix, so after aamod_firstlevel_design)
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        SPM = loadbetter(spmpath);
        frameperiod = SPM.xY.RT;
        % get mask - memory problems otherwise
        mpath = aas_getfiles_bystream(aap,subj,'epiBETmask');
        % first mask is the brain mask
        V = spm_vol(mpath(1,:));
        mask = spm_read_vols(V) > 0;

        % pass off to new independent function
        ts = aap.tasklist.currenttask.settings;
        % converts and gets rid of NaN / 0 voxels.
        [epi,design,dur,mask,names] = spm2glmdenoise(SPM,mask,...
          ts.ignorelabels,strcmp(ts.hrfmodel,'assumeconvolved'));

        % optional low pass filter
        if ~isempty(ts.K)
            fprintf('low pass filtering data\n')
            for r = 1:length(epi)
                % NB in GLMdenoise format epi time is in columns rather than in
                % rows
                epi{r} = single(sgolayfilt(double(epi{r}),ts.K,ts.F,[],2));
                % BUT design matrix still has time in rows...
                design{r} = single(sgolayfilt(double(design{r}),ts.K,ts.F,[],1));
            end
        end

        % Kendrick's empirical HRFs look very noisy for short stimuli (<3
        % s) and don't work at all for duration 0 (impulse response). In
        % any case they are extremely similar to the spm_hrf (reassuring!).
        % So we are going to use the SPM HRF when durations are 0. The
        % situation is more complicated for longer durations since you'd
        % then need to convolve the spm_hrf to make a predicted HRF for
        % longer durations.
        % (note that the duration input is basically redundant - Kendrick's
        % code only uses the duration for creating the HRF so when this is
        % given (e.g. when 'optimize' and 'hrfknobs' gives an HRF),
        % duration is not used.
        if dur==0 && isempty(ts.hrfknobs) && ~strcmp(ts.hrfmodel,'assumeconvolved')
            fprintf('event duration 0 so using spm HRF\n');
            ts.hrfknobs = normalizemax(spm_hrf(frameperiod));
        end

        if ~isfield(ts.opt,'brainmask') || isempty(ts.opt.brainmask)
            ts.opt.brainmask = mask;
        end

        % fit GLMdenoise model
        subdir = aas_getsubjpath(aap,subj);
        outdir = fullfile(subdir,'glmdenoise');
        mkdirifneeded(outdir);
        figdir = fullfile(outdir,'diagnostic_figures');
        mkdirifneeded(figdir);
        [results,denoisedepi] = GLMdenoisedata(design,epi,dur,frameperiod,...
            ts.hrfmodel,ts.hrfknobs,ts.opt,figdir);
        % add names field
        results.regnames = names;
        % recreate 'bright' logical mask marking voxel exceeding intensity
        % threshold
        results.bright = results.meanvol(:) > prctile(results.meanvol,...
          results.inputs.opt.brainthresh(1) * results.inputs.opt.brainthresh(2));

        % split off very large and fairly irrelevant field in results to
        % prevent ridiculously big MAT files
        models = results.models;
        results.models = [];
        outpath_models = fullfile(outdir,'results_models.mat');
        save(outpath_models,'models','-v7.3');
        aap=aas_desc_outputs(aap,subj,'glmdenoise_results_models',outpath_models);

        % save and describe standard outputs
        outpath_results = fullfile(outdir,'results.mat');
        % need 7.3 flag since this may be >2GB
        save(outpath_results,'results','-v7.3');
        aap=aas_desc_outputs(aap,subj,'glmdenoise_results',outpath_results);
        outpath_epi = fullfile(outdir,'denoisedepi.mat');
        save(outpath_epi,'denoisedepi','-v7.3');
        aap=aas_desc_outputs(aap,subj,'glmdenoise_epi',outpath_epi);

        % update mask
        V.fname = mpath(1,:);
        spm_write_vol(V,mask);
        aap=aas_desc_outputs(aap,subj,'epiBETmask',mpath);

        % also write out a few diagnostic volumes
        r2 = double(mask);
        r2(mask) = results.R2;
        outpath = fullfile(outdir,'R2.nii');
        V.fname = outpath;
        V.dt = [spm_type('float32') spm_platform('bigend')];
        spm_write_vol(V,r2);
        aap=aas_desc_outputs(aap,subj,'glmdenoise_diagnostic_r2',outpath);

        snr = double(mask);
        snr(mask) = results.SNR;
        outpath = fullfile(outdir,'SNR.nii');
        V.fname = outpath;
        spm_write_vol(V,snr);
        aap=aas_desc_outputs(aap,subj,'glmdenoise_diagnostic_snr',outpath);

        noisepool = mask;
        noisepool(mask) = results.noisepool;
        outpath = fullfile(outdir,'noisepool.nii');
        V.fname = outpath;
        spm_write_vol(V,noisepool);
        aap=aas_desc_outputs(aap,subj,'glmdenoise_diagnostic_noisepool',outpath);

        bright = mask;
        noisepool(mask) = results.bright;
        outpath = fullfile(outdir,'bright.nii');
        V.fname = outpath;
        spm_write_vol(V,bright);
        aap=aas_desc_outputs(aap,subj,'glmdenoise_diagnostic_noisepool',outpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
