% Restrict analysis to voxels where we obtain a sensible searchlight size
% defined in nvox and/or radius.
% [aap,resp]=aamod_pilab_restrictbysearchlightsize(aap,task,subj)
function [aap,resp]=aamod_pilab_restrictbysearchlightsize(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        % get volume
        vpath = aas_getfiles_bystream(aap,subj,'pilab_volume');
        vol = loadbetter(vpath);
        % searchlight diagnostic
        spath = aas_getfiles_bystream(aap,subj,'pilab_searchlight_nvox');
        xyz_n = spm_read_vols(spm_vol(spath));
        rpath = aas_getfiles_bystream(aap,subj,'pilab_searchlight_radius');
        xyz_r = spm_read_vols(spm_vol(rpath));
        % intersect to generate new mask
        ts = aap.tasklist.currenttask.settings;
        mask = vol.mask;
        mask = (mask>0) & (xyz_r >= ts.minradius) & ...
            (xyz_r <= ts.maxradius) & (xyz_n >= ts.minvox) & ...
            (xyz_n <= ts.maxvox);
        ngone = vol.nfeatures-sum(mask(:)>0);
        fprintf('eliminated %d features (%.2f%% of total)\n',...
          ngone,100*(ngone/vol.nfeatures));
        % update the volume
        goodind = vol.linind2featind(find(mask));
        vol = vol(:,goodind);
        save(vpath,'vol')
        aap = aas_desc_outputs(aap,subj,'pilab_volume',vpath);
        % and spheres...
        spath = aas_getfiles_bystream(aap,subj,...
            'pilab_rois');
        spheres = loadbetter(spath);
        spheres = spheres(goodind,goodind);
        save(spath,'spheres');
        aap = aas_desc_outputs(aap,subj,'pilab_rois',spath);
        % aaand diagnostics
        for dia = {'nvox','radius','nspheres'}
            streamname = ['pilab_searchlight_' dia{1}];
            dpath = aas_getfiles_bystream(aap,subj,streamname);
            dV = spm_vol(dpath);
            dxyz = spm_read_vols(dV);
            dxyz(~mask) = 0;
            spm_write_vol(dV,dxyz);
            aas_desc_outputs(aap,subj,streamname,dpath);
        end
end
