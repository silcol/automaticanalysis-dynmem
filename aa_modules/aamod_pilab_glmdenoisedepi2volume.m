% export cleaned EPIs and design matrix from glmdenoise to pilab instances.

function [aap,resp]=aamod_pilab_glmdenoisedepi2volume(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='construct glmdenoised EPI and design pilab Volumes';
        
    case 'summary'
        
    case 'report'
        
    case 'doit'
        % glmdenoised results (for design matrix, also get TR from here for
        % frameperoid field in epivol)
        respath = aas_getfiles_bystream(aap,subj,'glmdenoise_results');
        results = loadbetter(respath);
        % mask (mainly used so we preserve header in EPI)
        mpath = aas_getfiles_bystream(aap,subj,'epiBETmask');

        % glmdenoised epis
        epipath = aas_getfiles_bystream(aap,subj,'glmdenoise_epi');
        epi = loadbetter(epipath);
        % glmdenoise stores epis with samples in columns and features in
        % rows
        epi = cellfun(@(x)x',epi,'uniformoutput',false);
        nchunks = length(epi);
        % use length to figure out a chunks vector
        chunks = cell2mat(arrayfun(@(x)ones(size(epi{x},1),1)*x,...
            (1:nchunks)','uniformoutput',false));
        epivol = MriVolume(epi,mpath(1,:),'frameperiod',...
            results.inputs.tr,'metasamples',struct('chunks',chunks));
        % save epi
        outdir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        mkdirifneeded(outdir);
        outpath_epi = fullfile(outdir,'epivol.mat');
        % very likely too big for older Matlab formats
        save(outpath_epi,'epivol','-v7.3');
        aap=aas_desc_outputs(aap,subj,'pilab_epi',outpath_epi);
        
        % make designvol
        designvol = BaseVolume(vertcat(results.inputs.design{:}),...
            'metafeatures',struct('labels',{results.regnames}),...
            'metasamples',struct('chunks',chunks));
        outpath_design = fullfile(outdir,'designvol.mat');
        save(outpath_design,'designvol','-v7');
        aap=aas_desc_outputs(aap,subj,'pilab_design',outpath_design);

    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
