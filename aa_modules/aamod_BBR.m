% AA module
% Runs BBR based on Fischl 2009



function [aap,resp]=aamod_BBR(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        
        warning off
        
        % Get the mean epi image and structural (latter only for diagnostics)
        mepi = aas_getfiles_bystream(aap,subj,'meanepi');
        % Get the surfaces
        subjpath=aas_getsubjpath(aap,subj);
        % Get configuration parameters
        bbrConfiguration = aap.tasklist.currenttask.settings.bbrConfiguration;
        disp(bbrConfiguration);
        
        w_file{1} = [subjpath '/surf/rh.white'];
        p_file{1} = [subjpath '/surf/rh.pial'];
        w_file{2} = [subjpath '/surf/lh.white'];
        p_file{2} = [subjpath '/surf/lh.pial'];
        
        % Convert to .asc files: !mris_convert lh.pial lh.pial.asc
        for hemisphere = 1:2 % both hemispheres
            if ~exist([w_file{hemisphere} '.asc'], 'file') || ~exist([p_file{hemisphere} '.asc'], 'file')
                s = unix(['mris_convert ', w_file{hemisphere},' ', [w_file{hemisphere} '.asc']]);
                s = unix(['mris_convert ', p_file{hemisphere},' ', [p_file{hemisphere} '.asc']]);
            end
        end
        
        % Create object readable by slicer
        %{
        s = unix(['mv ',[p_file{1} '.asc'],' ', [p_file{1} '.sfr']]);    % rename
        s = unix(['srf2obj ', [p_file{1} '.sfr'],'>', [p_file{1} '.obj']]);    % convert ot object  :  srf2obj lh.pial.srf > lh.pial.obj
        %}
        
        %% Convert FreeSurfer file to NifTI
        freeSurferVolume = [subjpath '/mri/brain.mgz']; %or T1.mgz or orig.mgz
        unix(['mri_convert ' freeSurferVolume ' -ot nii ' [subjpath '/mri/brain.nii;']]);
        
        %% Load the volume data
        EPI             = spm_vol(mepi);
        MPRAGE          = spm_vol([subjpath '/mri/brain.nii']);
        EPI.volume      = spm_read_vols(EPI);
        
        %% Coregister
        print('Coregistering structural and functional data')
        coregstrationTransformation = spm_coreg(EPI, MPRAGE);
        coregistrationMatrix = spm_matrix(coregstrationTransformation);
        
        %% Load the boundaries that are found by Freesurfer and converted to ASCII
        fileNames = [];
        fileNames.SurfaceWhite  = [subjpath '/surf/?h.white.asc'];
        fileNames.SurfacePial   = [subjpath '/surf/?h.pial.asc'];
        [EPI.W, EPI.P] = loadFreeSurferAsciiFile(fileNames);
        
        %% Makes coordinates homogeneous (i.e. add a column of 1s)
        for hemisphere = 1:2
            EPI.W{hemisphere} = [EPI.W{hemisphere}, ones(size(EPI.W{hemisphere}, 1), 1)];
            EPI.P{hemisphere} = [EPI.P{hemisphere}, ones(size(EPI.P{hemisphere}, 1), 1)];
        end
        %%
        
        %% Convert FreeSurfer space to MATLAB space
        freeSurferMatrix =     [-1,    0,  0,  128;
            0,     0,  1,  -128;
            0,     -1, 0,  128;
            0,     0,  0,  1];
        
        %% Align FreeSurfer vertices to functional space
        %FreeSurfer conversion matrix to go to voxel space
        %Convert to anatomical world space
        %Coregister with the functional scan
        %And bring to functional voxel space
        t = inv(freeSurferMatrix)' * MPRAGE.mat' * inv(coregistrationMatrix)' * inv(EPI.mat)';
        
        for hemisphere = 1:2
            EPI.W{hemisphere} = EPI.W{hemisphere} * t;
            EPI.P{hemisphere} = EPI.P{hemisphere} * t;
        end
        
        %% DIAGNOSTIC 1: Show and save a slice with the original boundaries
        mriname = aas_prepare_diagnostic(aap,subj);
        
        slicePercentage = aap.tasklist.currenttask.settings.slicePercentage;
        try close(2); catch; end
        showSlice(EPI.volume, ...
            round(slicePercentage / 100 * size(EPI.volume, 3)), ...
            EPI.W, ...
            EPI.P);
        if aap.tasklist.currenttask.settings.saveOutput
            print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_Orig.jpeg']));
        end
        
        %% Boundary registration
        for hemisphere = 1:2 
            tic;
            %The original MPRAGE boundary is transformed into the new EPI boundary
            %by registering to the the EPI volume
            [EPI.W{hemisphere}, EPI.P{hemisphere}] = boundaryRegistration(EPI.W{hemisphere}, EPI.P{hemisphere}, EPI.volume, bbrConfiguration);
            fprintf('The computation time for the boundary registration was %f seconds.\n',  toc);
        end
        aas_makedir(aap,[subjpath '/Boundaries/']);
        W = EPI.W{hemisphere}; %#ok
        P = EPI.P{hemisphere}; %#ok
        save([subjpath '/Boundaries/RegisteredBoundaries.mat'], 'W', 'P')

        %% DIAGNOSTIC 2: Show and save a slice with the new boundaries
        try close(3); catch; end
        showSlice(EPI.volume, ...
            round(slicePercentage / 100 * size(EPI.volume, 3)), ...
            EPI.W, ...
            EPI.P);
        if aap.tasklist.currenttask.settings.saveOutput
            print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_BBR.jpeg']));
        end
        
        %% DESCRIBE OUTPUTS!
        aap=aas_desc_outputs(aap,subj,'bbrsurf',[subjpath '/Boundaries/RegisteredBoundaries.mat']);
end
