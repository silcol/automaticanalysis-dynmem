% AA module - extended coregistration of EPI to structural
% Coregistration of structural to mean EPI output by realignment in 3 steps
% 1) Coregister Structural to T1 template
% 2) Coregister mean EPI to EPI template
% 3) Coregister mean EPI to Structural
% 4) Apply transformation matrix of mean EPI to all EPIs

function [aap,resp]=aamod_ANTS_coreg_extended(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        %% 0) Check that the tamplates and images we need exist!
        
        % Get the structural
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        if isempty(Simg)
            aas_log(aap, true, 'Problem finding structural image.');
        elseif size(Simg,1) > 1
            aas_log(aap, false, 'Found more than 1 structural images, using structural %d', ...
                aap.tasklist.currenttask.settings.structural);
        end
        Spth = fileparts(Simg);
        
        % Get the mean functional
        mEPIimg = aas_getfiles_bystream(aap,subj,'meanepi');
                
        if isempty(mEPIimg)
            aas_log(aap, true, 'Problem finding mean functional image.');
        elseif size(mEPIimg,1) > 1
            aas_log(aap, false, 'Found more than 1 mean functional images, using first.');
        end
        mEPIimg = deblank(mEPIimg(1,:));
        mEPIpth = fileparts(mEPIimg);
        
        % Get the template
        sTimg = fullfile(spm('dir'), 'templates', 'T1.nii');
        if ~exist(sTimg, 'file')
            aas_log(aap, true, sprintf('Couldn''t find template T1 image %s.', Timg));
        end
        [sTpth sTfn sText] = fileparts(sTimg);
        copyfile(sTimg, Spth)
        sTimg = fullfile(Spth, [sTfn sText]);
        
        % Get the template
        eTimg = fullfile(spm('dir'), 'templates', 'EPI.nii');
        if ~exist(eTimg, 'file')
            aas_log(aap, true, sprintf('Couldn''t find template EPI image %s.', eTimg));
        end
        [eTpth eTfn eText] = fileparts(eTimg);
        copyfile(eTimg, mEPIpth)
        eTimg = fullfile(mEPIpth, [eTfn eText]);
        
        %% Get realignment defaults
        defs = aap.spm.defaults.realign;
        
        % Flags to pass to routine to create resliced images
        % (spm_reslice)
        resFlags = struct(...
            'interp', defs.write.interp,...       % interpolation type
            'wrap', defs.write.wrap,...           % wrapping info (ignore...)
            'mask', defs.write.mask,...           % masking (see spm_reslice)
            'which', 1,...     % what images to reslice
            'mean', 0);           % write mean image
        
        % Reslice T1 template to T1 structural
        % to keep the structural image in its own space
        spm_reslice(strvcat(Simg, sTimg), resFlags);
        sTimg = fullfile(Spth, ['r' sTfn sText]);
        
        % Reslice EPI template to mean EPI
        % to keep the structural image in its own space
        spm_reslice(strvcat(mEPIimg, eTimg), resFlags);
        eTimg = fullfile(mEPIpth, ['e' eTfn eText]);
        
        %% Set up ANTS
        % Set the ANTS path
        setenv('ANTSPATH', aap.directory_conventions.ANTSdir)
        ANTSpath = [fullfile(getenv('ANTSPATH'), 'bin', 'antsRegistration') ' '];
        warpANTSpath = [fullfile(getenv('ANTSPATH'), 'bin', 'WarpImageMultiTransform') ' '];
        
        % What we get out...
        outfiles = ' -o [ANTS,ANTS.nii.gz] ';
        
        % Dimension number (always 3 for structural)
        Ndim = ['-d ' num2str(3) ' '];
        
        % Any extra options?...
        if ~isempty(aap.tasklist.currenttask.settings.extraoptions)
            extraoptions = aap.tasklist.currenttask.settings.extraoptions;
        else
            extraoptions = '';
        end
        
        transform = ['-t Rigid[' num2str(aap.tasklist.currenttask.settings.gradient) '] '];
        
        %% 1) Structural to T1 template
        metrics = '';
        for m = 1:9
            if isfield(aap.tasklist.currenttask.settings, ['metric' num2str(m)])
                tmpM = aap.tasklist.currenttask.settings.(['metric' num2str(m)]);
                tmpW = num2str(aap.tasklist.currenttask.settings.(['weight' num2str(m)]));
                tmpP = aap.tasklist.currenttask.settings.(['parameters' num2str(m)]);
                if isnumeric(tmpP)
                    tmpP = num2str(tmpP);
                end
                
                metrics = [ metrics ...
                    '-m ' tmpM '[' sTimg ',' Simg ',' tmpW ',' tmpP ' '];
            else
                break
            end
        end
        
        
        ANTS_command = [ ANTSpath Ndim metrics transform extraoptions outfiles];
        
        cd(Spth)
        
        % Run ANTS
        fprintf('Running ANTS using command:\n')
        fprintf([ANTS_command '\n'])
        [s w] = aas_shell(ANTS_command);
        
        keyboard
        
        %%
        %%%%%%%%%%%%%%%%%%
        
        warpANTS_command = [ warpANTSpath Ndim ... % dimension number
            Simg ' ' fullfile(Spth, ['w' Sfn Sext]) ... % moving image & output
            ' -R ' sTimg ' '... % reference image
            fullfile(Spth,'antsAffine.txt')]; % Only do affine...
        
        [s w] = aas_shell(warpANTS_command);
        
        %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Coregister T1 to template
        x = spm_coreg(spm_vol(sTimg), ...
            spm_vol(deblank(Simg(aap.tasklist.currenttask.settings.structural,:))), ...
            flags.estimate);
        Ms = inv(spm_matrix(x));
        
        % Set the new space for the structural
        for d = 1:size(Simg,1)
            MM = spm_get_space(deblank(Simg(d,:)));
            spm_get_space(deblank(Simg(d,:)), Ms*MM);
        end
        
        fprintf(['\tstructural to template realignment parameters:\n' ...
            '\tx: %0.4f   y: %0.4f   z: %0.4f   p: %0.4f   r: %0.4f   j: %0.4f'], ...
            x(1), x(2), x(3), x(4), x(5), x(6))
        
        %% 2) Mean Functional to EPI template
        
        
        
        % Coregister mean functional to template
        x = spm_coreg(spm_vol(eTimg), spm_vol(mEPIimg), flags.estimate);
        Me = inv(spm_matrix(x));
        
        % Set the new space for the mean functional
        MM = spm_get_space(mEPIimg(1,:));
        spm_get_space(mEPIimg, Me*MM);
        
        fprintf(['\tmean EPI to template realignment parameters:\n' ...
            '\tx: %0.4f   y: %0.4f   z: %0.4f   p: %0.4f   r: %0.4f   j: %0.4f'], ...
            x(1), x(2), x(3), x(4), x(5), x(6))
        
        %% 3) Mean Functional to Structural
            
        % Coregister mean EPI to structural
        x = spm_coreg(spm_vol(deblank(Simg(aap.tasklist.currenttask.settings.structural,:))), ...
            spm_vol(mEPIimg(1,:)), ...
            flags.estimate);
        Mf = inv(spm_matrix(x));
        
        % Set the new space for the mean EPI
        MM = spm_get_space(mEPIimg);
        spm_get_space(mEPIimg, Mf*MM);
        
        fprintf(['\tmean EPI to structural realignment parameters:\n' ...
            '\tx: %0.4f   y: %0.4f   z: %0.4f   p: %0.4f   r: %0.4f   j: %0.4f'], ...
            x(1), x(2), x(3), x(4), x(5), x(6))
        
        %% 4) Now apply this transformation to all the EPI images
        % The mean EPI will already be in the space required for the
        % individual EPIs. Hence, we can...
        
        % Again, get space of mean functional
        MM = spm_get_space(mEPIimg(1,:));
        
        EPIimg = cell(size(aap.acq_details.sessions));
        % Locate all the EPIs we want to coregister
        for sess = aap.acq_details.selected_sessions
            EPIimg{sess} = aas_getfiles_bystream(aap,subj,sess,'epi');
            
            % For each image, apply the space of the mean EPI image
            fprintf('\nCoregistering images for session: %s\n', aas_getsessname(aap,subj,sess))
            for e = 1:size(EPIimg{sess},1)
                % Apply the space of the coregistered mean EPI to the
                % remaining EPIs (safest solution!)
                spm_get_space(deblank(EPIimg{sess}(e,:)), MM);
            end
        end
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap,subj);
        
        spm_check_registration(strvcat( ...
            sTimg, ... % Get template T1
            deblank(Simg(aap.tasklist.currenttask.settings.structural,:)),... % Get structural
            mEPIimg, ... % Get mean EPI across sessions
            EPIimg{sess}(1,:))) % Get first image of last session EPI
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO of coregistration
        
        %% Diagnostic VIDEO
        if aap.tasklist.currenttask.settings.diagnostic
            % Realignment params
            defs = aap.spm.defaults.realign;
            
            % ...flags to pass to routine to create resliced images
            % (spm_reslice)
            resFlags = struct(...
                'interp', defs.write.interp,...       % interpolation type
                'wrap', defs.write.wrap,...           % wrapping info (ignore...)
                'mask', defs.write.mask,...           % masking (see spm_reslice)
                'which', 1,...     % what images to reslice
                'mean', 0);           % write mean image
            
            % Get resliced structural
            [Spth, Sfn, Sext] = fileparts(deblank(Simg(aap.tasklist.currenttask.settings.structural,:)));
            spm_reslice(strvcat(mEPIimg, fullfile(Spth, [Sfn Sext])), resFlags);
            
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi(mEPIimg, ...
                fullfile(Spth, ['r' Sfn Sext]), ...
                fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                d, ... % Axis
                [800 600], ...
                2); % Rotations
            end
            try close(2); catch; end
        end   
        
        %% Describe the outputs
        
        aap = aas_desc_outputs(aap,subj,'structural',Simg);
        aap = aas_desc_outputs(aap,subj,'meanepi',mEPIimg);
        
        for sess = aap.acq_details.selected_sessions
            aap = aas_desc_outputs(aap,subj,sess,'epi',EPIimg{sess});
        end
        
    case 'checkrequirements'
        aas_log(aap,0,'No need to trim or skull strip structural\n' );
end