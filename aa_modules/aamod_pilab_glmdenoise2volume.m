% Fit with GLMdenoise from KK.

function [aap,resp]=aamod_pilab_glmdenoise2volume(aap,task,subj)

resp='';

switch task
    case 'doit'
        ts = aap.tasklist.currenttask.settings;

        % glmdenoise result (assume vector form rather than 3D vols)
        glpath = aas_getfiles_bystream(aap,subj,'glmdenoise_results');
        results = loadbetter(glpath);

        if ts.tmap
            estimates = (results.modelmd{2} ./ results.modelse{2})';
        else
            estimates = results.modelmd{2}';
        end

        % restrict to conditions of interest
        if ~isempty(ts.ignorelabels)
            assert(issorted(results.regnames),...
                'names must be sorted to ignore labels');
            [validnames,coninds] = setdiff(results.regnames,ts.ignorelabels);
            estimates = estimates(coninds,:);
        else
            validnames = results.regnames;
        end

        % restrict to voxels with reasonable r2 and EPI intensity (by same
        % brightness threshold as in GLMdenoise)
        r2ok = results.R2 > ts.minr2;
        badinds = ~(r2ok & results.bright);
        % remove from model estimates
        estimates(:,badinds) = [];

        % load mask
        mpath = aas_getfiles_bystream(aap,subj,'epiBETmask');
        V = spm_vol(mpath(1,:));
        mask = spm_read_vols(V) > 0;
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

        % make volume instance and save
        vol = MriVolume(estimates,mask,'header',V,'metasamples',struct(...
            'labels',{validnames},'chunks',ones(length(validnames),1)));
        outdir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        mkdirifneeded(outdir);
        outpath = fullfile(outdir,'glmdenoisevol.mat');
        save(outpath,'vol','-v7');
        aap=aas_desc_outputs(aap,subj,'pilab_volume',outpath);

        % save updated mask
        V.fname = mpath(1,:);
        spm_write_vol(V,mask);
        aap=aas_desc_outputs(aap,subj,'epiBETmask',mpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
