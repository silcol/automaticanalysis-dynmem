% Fit T maps for each chunk in the epi / design instances
% [aap,resp]=aamod_pilab_tmap(aap,task,subj)
function [aap,resp]=aamod_pilab_tmap(aap,task,subj)

resp='';

switch task
    case 'doit'
        % get the model / epi instances
        designpath = aas_getfiles_bystream(aap,subj,'pilab_design');
        designvol = loadbetter(designpath);
        epipath = aas_getfiles_bystream(aap,subj,'pilab_epi');
        epivol = loadbetter(epipath);
        ts = aap.tasklist.currenttask.settings;
        if ~isempty(ts.sgolayK)
            assert(isempty(ts.covariatedeg),['probably should not ' ...
                'detrend and include trend covariates at the same time']);
            fprintf('detrending (K=%d,F=%d)\n',...
                ts.sgolayK,...
                ts.sgolayF);
            epivol.sgdetrend(ts.sgolayK,...
                ts.sgolayF);
            designvol.sgdetrend(ts.sgolayK,...
                ts.sgolayF);
        end
        % find correct labels
        labinds = findStrInArray(designvol.desc.features.unique.labels,...
            ts.targetname)';
        assert(~isempty(labinds),'found no labels matching %s',...
            ts.targetname);
        % iterate over chunks
        datcell = cell(epivol.desc.samples.nunique.chunks,1);
        for chind = 1:epivol.desc.samples.nunique.chunks
            c = epivol.desc.samples.unique.chunks(chind);
            datcell{chind} = tmapvol(designvol.selectbymeta('chunks',c),...
                epivol.selectbymeta('chunks',c),labinds,ts.covariatedeg);
            % set meta data to avoid problems when concatenating
            datcell{chind}.meta.samples.order(1:datcell{chind}.nsamples,1) = c;
            datcell{chind}.meta.samples.chunks(1:datcell{chind}.nsamples,1) = c;
        end
        % finally, make a big vol
        vol = vertcat(datcell{:});
        % save and describe
        outdir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        outpath = fullfile(outdir,'tvol.mat');
        % very likely too big for older Matlab formats
        save(outpath,'vol','-v7');
        aap=aas_desc_outputs(aap,subj,'pilab_volume',outpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
