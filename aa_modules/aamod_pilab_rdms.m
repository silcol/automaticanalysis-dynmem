% generate RDMs for each ROI (whether it's a set of searchlights or ROIs).
% Generalised version of aamod_pilab_searchlight_rdms.
%
% [aap,resp]=aamod_pilab_rdms(aap,task,subj)
function [aap,resp]=aamod_pilab_rdms(aap,task,subj)

resp='';

switch task
    case 'doit'
        % get data
        vpath = aas_getfiles_bystream(aap,subj,'pilab_volume');
        vol = loadbetter(vpath);

        % get ROIs / spheres
        roipath = aas_getfiles_bystream(aap,subj,...
            'pilab_rois');
        rois = loadbetter(roipath);

        % check that parfor is available
        if ~matlabpool('size')
            try
                matlabpool local
            catch
                warning('no matlabpool available')
            end
        end

        % prepare output
        assert(~isempty(vol.desc.samples.nunique.labels),...
          'input vol must have defined labels');
        npairs = nchoosek(vol.desc.samples.nunique.labels,2);
        % npairs by nrois by nchunks
        pidir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        outpaths_sessrdms = [];

        % run
        assert(vol.desc.samples.nunique.chunks>0,...
          'vol must have defined chunks in meta.samples');
        sumdata = zeros([npairs rois.nsamples]);
        for sess = 1:vol.desc.samples.nunique.chunks
            % copying here saves memory per worker in parfor
            sessvol = vol(vol.meta.samples.chunks==sess,:);

            fprintf('running rois for session %d of %d...\n',sess,...
              vol.desc.samples.nunique.chunks);
            tic;
            sessdisvol = roidata2rdmvol(rois,sessvol,...
                aap.tasklist.currenttask.settings.distancemetric);
            sumdata = sumdata + sessdisvol.data;
            outpath_sessdata = fullfile(pidir,sprintf(...
                'rdms_session%02d.mat',sess));
            save(outpath_sessdata,'sessdisvol');
            outpaths_sessrdms = [outpaths_sessrdms; outpath_sessdata];
        end

        % make average RDM across sessions and save
        disvol = MriVolume(sumdata/vol.desc.samples.nunique.chunks,...
            sessdisvol,'metafeatures',struct(...
                'names',{rois.meta.samples.names}));
        outpath_mean = fullfile(pidir,'rdms_mean.mat');
        save(outpath_mean,'disvol');

        % describe outputs
        aap=aas_desc_outputs(aap,subj,'pilab_data_rdms_sess',...
            outpaths_sessrdms);
        aap=aas_desc_outputs(aap,subj,'pilab_data_rdms_mean',...
            outpath_mean);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
