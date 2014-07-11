% make a 2D nfeat by nfeat logical matrix that provides indices for each
% searchlight sphere.
% [aap,resp]=aamod_pilab_searchlight_init(aap,task,subj)
function [aap,resp]=aamod_pilab_searchlight_init(aap,task,subj)

resp='';

switch task
    case 'doit'
        % get data
        vpath = aas_getfiles_bystream(aap,subj,'pilab_volume');
        vol = load(vpath);
        vol = vol.vol;

        % configure searchlight
        ts = aap.tasklist.currenttask.settings;
        sl = Searchlight(vol,ts.searchlighttype,ts.searchlightparameter);

        % check that parfor is available
        if ~matlabpool('size')
            try
                matlabpool local
            catch
                warning('no matlabpool available')
            end
        end

        % output matrix - each row provides logical indices into a
        % searchlight
        % (this is matlab's perverse way of initialising an empty logical
        % array)
        % NB! This matrix will be symmetrical for radius-based mapping.
        % This is because if a voxel x1 is outside a searchlight centered
        % on x2, then a a searchlight on x1 necessarily doesn't include x1,
        % and conversely. So the distribution of nvoxels == the
        % distribution of nsamples or intuitively, a searchlight that
        % includes many voxels will also be included as a voxel in many
        % other searchlights. But this does not hold for nvox-based mapping
        % (?).

        % new sparse formulation - store radius information directly in
        % roivol instance.
        spheres = sparse(vol.nfeatures,vol.nfeatures);
        diagnostic_r = NaN([1 vol.nfeatures]);
        pidir = fullfile(aas_getsubjpath(aap,subj),'pilab');

        % run
        fprintf('mapping %d searchlights...\n',vol.nfeatures);
        tic;
        parfor n = 1:vol.nfeatures
            % get sphere index
            % (some extra dribbling is necessary here to avoid confusing
            % parfor)
            sp = sparse(1,vol.nfeatures);
            inds = sl.mapinds(n);
            sp(inds) = sl.distances(inds);
            spheres(n,:) = sp;
            diagnostic_r(n) = sl.radius;
        end
        fprintf('finished in %s.\n',seconds2str(toc));
        % number of voxels in each sphere
        diagnostic_nsphere = full(sum(spheres,2)');
        % number of spheres that sampled each voxel
        diagnostic_nsampled = full(sum(spheres,1));

        % save spheres
        % now as volume 
        maskvol = MriVolume(spheres,vol);
        outpath_spheres = fullfile(pidir,'searchlight_spheres.mat');
        save(outpath_spheres,'maskvol');

        % save niftis of diagnostics
        outpath_n = fullfile(pidir,...
            'diagnostic_searchlight_nvoxpersphere.nii');
        vol.data2file(diagnostic_nsphere,outpath_n);
        outpath_s = fullfile(pidir,...
            'diagnostic_searchlight_nspherepervox.nii');
        vol.data2file(diagnostic_nsampled,outpath_s);
        outpath_r = fullfile(pidir,'diagnostic_searchlight_radius.nii');
        vol.data2file(diagnostic_r,outpath_r);

        % describe outputs
        % (now treat searchlights like any ROI)
        aap=aas_desc_outputs(aap,subj,'pilab_rois',...
            outpath_spheres);
        aap=aas_desc_outputs(aap,subj,'pilab_searchlight_radius',...
            outpath_r);
        aap=aas_desc_outputs(aap,subj,'pilab_searchlight_nvox',...
            outpath_n);
        aap=aas_desc_outputs(aap,subj,'pilab_searchlight_nspheres',...
            outpath_s);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;



