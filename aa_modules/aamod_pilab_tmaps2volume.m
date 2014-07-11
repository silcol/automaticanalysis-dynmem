% export a set of t maps from a GLM to a Volume instance for pilab
% processing.

function [aap,resp]=aamod_pilab_tmaps2volume(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='T map to pilab MriVolume';
        
    case 'summary'
        
    case 'report'
        
    case 'doit'
        % gm mask
        mask = aas_getfiles_bystream(aap,subj,'freesurfer_gmmask');
        % (epi is second mask)
        mask = mask(2,:);

        % find T maps
        tpaths = aas_getfiles_bystream(aap,subj,'firstlevel_spmts');
        % reduce to only headers
        tpaths = tpaths(1:2:end,:);
        nt = size(tpaths,1);
        mdata = struct('name',cell(1,nt),'label',[],'chunk',[],'order',[]);
        % figure out regexp
        ts = aap.tasklist.currenttask.settings;
        labelexp = [regexptranslate('wildcard',ts.labelprefix) ...
            '(?<label>\w+)'];
        chunkexp = [regexptranslate('wildcard',ts.chunkprefix) ...
            '(?<chunk>\d+)'];
        if ts.chunkfirst
            fullexp = [chunkexp '.*' labelexp];
        else
            fullexp = [labelexp '.*' chunkexp];
        end
        % iterate over all T maps
        tVall = spm_vol(tpaths);
        for t = 1:nt
            tV = tVall(t);
            % kill white space because XML tags don't support it
            meta = strrep(tV.descrip,' ','_');
            % kill off leading spmbit
            hits = strfind(meta,':_');
            meta(1:(hits(1)+1)) = [];
            % now regexp
            hits = regexp(meta,fullexp,'names');
            % if we found nothing, probably not an appropriate T map
            if isempty(hits) || isempty(hits.label) || isempty(hits.chunk)
                continue
            end
            % skip t maps belonging to ignored labels
            if any(strcmp(hits.label,ts.ignorelabels))
                continue
            end
            mdata(t) = struct('name',tV.fname,'label',hits.label,...
                'chunk',str2double(hits.chunk),'order',t);
        end
        empties = cellfun(@isempty,{mdata.chunk});
        mdata(empties) = [];
        assert(~isempty(mdata),'no matching T maps found!');

        % make instance and save
        vol = MriVolume({mdata.name},mask,'metasamples',struct(...
            'labels',{{mdata.label}},'name',{{mdata.name}},'chunks',...
            [mdata.chunk],'order',[mdata.order]));
        outdir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        if ~exist(outdir,'dir')
            mkdir(outdir);
        end
        outpath = fullfile(outdir,'vol.mat');
        save(outpath,'vol');
        % describe outputs
        aap=aas_desc_outputs(aap,subj,'pilab_volume',outpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;



