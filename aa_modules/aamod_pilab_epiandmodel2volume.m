% Make 2 pilab volume instances: one for the GLM specification, and another
% for its corresponding EPI volumes

function [aap,resp]=aamod_pilab_epiandmodel2volume(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='construct EPI and design pilab Volumes';
        
    case 'summary'
        
    case 'report'
        
    case 'doit'
        % gm mask
        mpath = aas_getfiles_bystream(aap,subj,'freesurfer_gmmask');
        % (epi is second mask)
        mask = mpath(2,:);

        % model
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        load(spmpath);
        % convolved design matrix
        dm = SPM.xX.X;
        [nvol,nreg] = size(dm);

        % volumes
        volpaths = SPM.xY.P;
        assert(nvol == size(volpaths,1),...
            'design matrix size does not match SPM.xY.P');

        % figure out chunk data for each volume via sub2ind
        constinds = findStrInArray(SPM.xX.name,') constant');
        nruns = size(constinds,2);
        assert(nruns == length(SPM.Sess),...
            'design matrix does not match SPM.Sess length')
        [order,chunks] = ind2sub([nvol,nruns],find(dm(:,constinds)));

        % construct epi container - this can be quite slow
        fprintf('building epi volume instance...\n')
        tic;
        epivol = MriVolume(volpaths,mask,'metasamples',struct(...
            'chunks',chunks,'order',order),'frameperiod',SPM.xY.RT);
        fprintf('finished in %s.\n',seconds2str(toc));
        % remove any voxels that == 0 at any point (likely voxels that went
        % outside the mask after realign). NaNs are unlikely but why not
        % check...
        iszero = any(epivol.data==0,1) | any(isnan(epivol.data),1);
        if any(iszero)
            % make 3D so we can revise the GM mask
            zeromask = epivol.data2mat(iszero);
            mV = spm_vol(mask);
            mxyz = spm_read_vols(mV);
            mx = (mxyz>0) & ~zeromask;
            spm_write_vol(mV,mx);
            fprintf(...
                'removed %d zero/nan features from epivol and mask\n',...
                sum(iszero));
            aap=aas_desc_outputs(aap,subj,'freesurfer_gmmask',mpath);
            % and update the volume instance
            epivol = epivol(:,~iszero);
        else
            fprintf('no zero/nan features to remove.\n') 
        end

        % construct design matrix
        % regexp to find regressor label / chunk
        labelexp = 'Sn\((?<chunk>\d+)\) (?<label>\w+)';
        % construct cell array of structs
        labarr = regexp(SPM.xX.name,labelexp,'names');
        assert(~any(cellfun(@isempty,labarr)),...
            'failed to parse regressor names')
        % pull out labels and chunks (nb, different from epi since over
        % nreg, not nvol)
        reglabels = cellfun(@(x)x.label,labarr,'uniformoutput',false);
        regchunks = cellfun(@(x)str2double(x.chunk),labarr);
        % now no longer transpose DM - so volumes in sample dim,
        % regressors in feature dim
        designvol = BaseVolume(dm,'metasamples',struct('names',...
            {{SPM.xY.VY.fname}'},'chunks',chunks),'metafeatures',struct(...
            'labels',{reglabels},'chunks',regchunks,'names',...
            {SPM.xX.name}));
        % strip constant (gets reintroduced in GLM)
        designvol = designvol.removebymeta('labels','constant');

        if aap.tasklist.currenttask.settings.collapseruns
            % you probably don't want to do this if your design matrix
            % includes any sort of session covariates or constants!
            fprintf('collapsing to one set of regressors across runs\n');
            chunks = designvol.desc.features.unique.chunks;
            tempvol = designvol.selectbymeta('chunks',chunks(1));
            labels = tempvol.meta.features.labels(...
                tempvol.meta.features.chunks==chunks(1));
            % remove all features except label since these won't be
            % reliable and can lead to unpredictable behaviour (e.g., if
            % you keep the chunk field selectbymeta(chunks=2) can give you
            % no columns matching...
            tempvol.meta.features = struct('labels',{labels});
            for c = chunks(2:end)
                cvol = designvol.selectbymeta('chunks',c);
                cvol.meta.features = struct('labels',...
                    {cvol.meta.features.labels});
                tempvol = [tempvol; cvol];
            end
            designvol = tempvol;
        end

        % save and describe
        outdir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        mkdirifneeded(outdir);
        % epi
        outpath_epi = fullfile(outdir,'epivol.mat');
        % very likely too big for older Matlab formats
        save(outpath_epi,'epivol','-v7');
        aap=aas_desc_outputs(aap,subj,'pilab_epi',outpath_epi);
        % model
        outpath_design = fullfile(outdir,'designvol.mat');
        save(outpath_design,'designvol','-v7');
        aap=aas_desc_outputs(aap,subj,'pilab_design',outpath_design);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
