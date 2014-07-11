% Generate a volumetric GM mask in freesurfer, convert to nifti and
% resample in SPM to EPI resolution.
% [aap,resp]=aamod_freesurfer_gmmask(aap,task,subj)
function [aap,resp]=aamod_freesurfer_gmmask(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        
        % Set subject paths
        subjname = aap.acq_details.subjects(subj).mriname;
        subjpath = aas_getsubjpath(aap,subj);
        
        setenv('SUBJECTS_DIR', fileparts(subjpath))
        setenv('FREESURFER_DIR', aap.directory_conventions.freesurferdir)
        
        %% Try to delete old freesurfer running flags
        if exist(fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh'), 'file')
            unix(['rm ' fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh')]);
        end

        epipath = aas_getfiles_bystream(aap,subj,'meanepi');

        outpath = fullfile(subjpath,'freesurfer_gmmask.nii');
        
        % first use freesurfer to make GM mask
        gmintermediate = fullfile(subjpath,'mri','gmmask.mgz');
        FScommand = sprintf(['mri_binarize --i %s --match 3 --match 42 ' ...
            '--o %s'],fullfile(subjpath,'mri','ribbon.mgz'),...
            gmintermediate);
        disp(FScommand)
        [s w] = aas_runFScommand(aap,FScommand);
        if aap.tasklist.currenttask.settings.verbose
            disp(w);
        end
        if s==1 %|| ~isempty(strfind(w, 'ERROR'))
            error('Some freesurfer ERROR');
        end

        % convert GM mask to nii
        FScommand = sprintf('mri_convert %s %s',gmintermediate,outpath);
        disp(FScommand)
        [s w] = aas_runFScommand(aap,FScommand);
        if aap.tasklist.currenttask.settings.verbose
            disp(w);
        end
        if s==1 %|| ~isempty(strfind(w, 'ERROR'))
            error('Some freesurfer ERROR');
        end

        % make the GM mask float instead of binary so that spm_reslice
        % below interpolates a bit (mask usually ends up too tight and
        % discontinuous otherwise)
        V = spm_vol(outpath);
        Y = spm_read_vols(V);
        V.dt = [spm_type('float64') spm_platform('bigend')];
        spm_write_vol(V,Y);
        clear V
        clear Y

        % then reslice
        % Get realignment defaults
        defs = aap.spm.defaults.realign;
        % Flags to pass to routine to create resliced images
        % (spm_reslice)
        resFlags = struct(...
            'prefix','epi_',...
            'interp', defs.write.interp,...       % interpolation type
            'wrap', defs.write.wrap,...           % wrapping info (ignore...)
            'mask', defs.write.mask,...           % masking (see spm_reslice)
            'which', 1,...     % what images to reslice
            'mean', 0);           % write mean image
        spm_reslice(strvcat(epipath, outpath), resFlags);

        outpath_epi = addprefix(outpath,'epi_');
        V = spm_vol(outpath_epi);
        Y = spm_read_vols(V);
        % optionally smooth 
        if aap.tasklist.currenttask.settings.smoothsigma > 0
            Y = smooth3(Y,'gaussian',9,...
                aap.tasklist.currenttask.settings.smoothsigma);
        end
        % threshold the EPI-transformed image
        Y = Y > aap.tasklist.currenttask.settings.maskthreshold;
        % optionally threshold further by meanepi
        if aap.tasklist.currenttask.settings.epithreshold > 0
            xyz_epi = spm_read_vols(spm_vol(epipath));
            Y(xyz_epi <= ...
                aap.tasklist.currenttask.settings.epithreshold) = 0;
        end
        % write out as binary mask
        V.dt = [spm_type('int32') spm_platform('bigend')];
        spm_write_vol(V,Y);
        
        %%  make output stream (T1 and EPI masks)
        aap = aas_desc_outputs(aap,subj,'freesurfer_gmmask',...
            {outpath,outpath_epi});
end
