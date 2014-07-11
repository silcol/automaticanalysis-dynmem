% AA module
% Use the Anatomical Transformation Toolbox to normalise the structural to
% a template image

function [aap,resp]=aamod_ANTS_struc2epi_PSE(aap,task,subj)

resp='';

switch task
    case 'doit'
        %% Get structural
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        Simg = deblank(Simg(aap.tasklist.currenttask.settings.structural,:));
        
        if size(Simg,1) > 1
            aas_log(aap, false, 'Found more than 1 structural images, using structural %d', ...
                aap.tasklist.currenttask.settings.structural);
        end
        % Get structural directory for this subject
        [Spth, Sfn, Sext] = fileparts(Simg);
        % Warped structural...
        wSimg = fullfile(Spth,['w' Sfn Sext]);
        
        %% structural BET
        betSimg = aas_getfiles_bystream(aap,subj,'BETmask');
        % Get mask...
        for m = 1:size(betSimg,1)
            if ~isempty(strfind(betSimg(m,:), aap.tasklist.currenttask.settings.maskBrain))
                betSimg = deblank(betSimg(m,:));
                break
            end
        end
        mask2outline(betSimg);
        
        %% mean EPI image
        mEPIimg = aas_getfiles_bystream(aap,subj,'meanepi');
        
        if size(mEPIimg,1) > 1
            aas_log(aap, false, 'Found more than 1 mean functional images, using first');
        end
        mEPIimg = deblank(mEPIimg(1,:));
        [mEPIpth, mEPIfn, mEPIext] = fileparts(mEPIimg);
        
        %% mean EPI BET
        betEPIimg = aas_getfiles_bystream(aap,subj,'epiBETmask');
        % Get mask...
        for m = 1:size(betEPIimg,1)
            if ~isempty(strfind(betEPIimg(m,:), aap.tasklist.currenttask.settings.maskBrain))
                betEPIimg = deblank(betEPIimg(m,:));
                break
            end
        end
        [betEPIpth, betEPIfn, betEPIext] = fileparts(betEPIimg);
        mask2outline(betEPIimg);
        
        %% Make mask for where we want to do the normalisation...
        % If we don't have a brain mask, then what we can do is to use
        % the space of the EPI image, and make a mask from this...
        MASKimg = fullfile(mEPIpth, ['mask_' mEPIfn mEPIext]);
        V = spm_vol(mEPIimg);
        Y = ones(V.dim);
        V.fname = MASKimg;
        spm_write_vol(V,Y);
        [MASKpth, MASKfn, MASKext] = fileparts(MASKimg);
        
        %% Reslice mEPI and mask to structural space
        % to keep the structural image in its own space, and avoid slicing
        % off non-EPI acquired data)
        
        % Get realignment defaults
        defs = aap.spm.defaults.realign;
        
        % Flags to pass to routine to create resliced images
        % (spm_reslice)
        resFlags = struct(...
            'interp', defs.write.interp,...       % interpolation type
            'wrap', defs.write.wrap,...           % wrapping info (ignore...)
            'mask', defs.write.mask,...           % masking (see spm_reslice)
            'which', 1,...     % what images to reslice
            'mean', 0);           % write mean image
        
        % Reslice
        spm_reslice(strvcat(Simg, mEPIimg, betEPIimg, MASKimg), resFlags);
        
        mEPIimg = fullfile(mEPIpth, ['r' mEPIfn mEPIext]);
        betEPIimg = fullfile(betEPIpth, ['r' betEPIfn betEPIext]);
        MASKimg = fullfile(MASKpth, ['r' MASKfn MASKext]);
        
        % Ensure the resliced masks are indeed binary...
        img2mask(MASKimg);
        img2mask(betEPIimg);
        img2mask(betSimg)
        
        % DEBUG... @@@
        M = spm_read_vols(spm_vol(MASKimg));
        V = spm_vol(betSimg);
        Y = spm_read_vols(V);
        Y = Y.*M;
        spm_write_vol(V,Y);
        
        
        %% Use ANTS to normalise them!
        
        % Set the ANTS path
        setenv('ANTSPATH', aap.directory_conventions.ANTSdir)
        ANTSpath = [fullfile(getenv('ANTSPATH'), 'bin', 'ANTS') ' '];
        warpANTSpath = [fullfile(getenv('ANTSPATH'), 'bin', 'WarpImageMultiTransform') ' '];
        
        % What we get out...
        outfiles = '-o ants.nii ';
        
        % Set up maxiterations
        maxiterations = '';
        for m = 1:length(aap.tasklist.currenttask.settings.maxiterations)
            maxiterations = [maxiterations num2str(aap.tasklist.currenttask.settings.maxiterations(m)) 'x'];
        end
        maxiterations = ['-i ' maxiterations(1:end-1) ' '];
        
        % Dimension number (always 3 for structural)
        Ndim = [num2str(3) ' '];
        
        % Regularisation...
        if ~isempty(aap.tasklist.currenttask.settings.regularisation)
            regularisation = aap.tasklist.currenttask.settings.regularisation;
        else
            regularisation = '';
        end
        
        % SyN transformation...
        if ~isempty(aap.tasklist.currenttask.settings.transformation)
            transformation = ['-t ' aap.tasklist.currenttask.settings.transformation ' '];
        else
            transformation = '';
        end
        
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
                    '-m ' tmpM '[' mEPIimg ',' Simg ',' tmpW ',' tmpP ' '];
            else
                break
            end
        end
        
        % Add a PSE metric...
        tmpM = num2str(aap.tasklist.currenttask.settings.metricPSE);
        tmpW = num2str(aap.tasklist.currenttask.settings.weightPSE);
        tmpP = num2str(aap.tasklist.currenttask.settings.parametersPSE);
        
        %{
        metrics = [ metrics ...
            '-m ' tmpM '[' mEPIimg ',' Simg ',' betEPIimg ',' betSimg ',' ...
            tmpW ',' tmpP ' '];
        %}
        
        % Any extra options?...
        if ~isempty(aap.tasklist.currenttask.settings.transformation)
            extraoptions = aap.tasklist.currenttask.settings.extraoptions;
        else
            extraoptions = '';
        end
        
        EPImask = [' -x ' MASKimg];
        
        ANTS_command = [ ANTSpath Ndim outfiles maxiterations transformation metrics extraoptions EPImask];
        
        cd(Spth)
        
        % Run ANTS
        fprintf('Running ANTS using command:\n')
        fprintf([ANTS_command '\n'])
        [s w] = aas_shell(ANTS_command);
        disp(w)
        
        warpANTS_command = [ warpANTSpath Ndim ... % dimension number
            Simg ' ' fullfile(Spth, ['w' Sfn Sext]) ... % moving image & output
            ' -R ' mEPIimg ' '... % reference image
            fullfile(Spth, 'antsWarp.nii')]; % transform
        if exist(fullfile(Spth,'antsAffine.txt'), 'file')
            warpANTS_command = [warpANTS_command ' ' fullfile(Spth,'antsAffine.txt')]; % and affine, if this exists...
        end
        
        [s w] = aas_shell(warpANTS_command);
        
        %% Describe outputs
        %{
        aap=aas_desc_outputs(aap,subj,'structural', wSimg);
        %}
        warning('NOT DESCRIBING OUTPUTS...')
        
        outANTS = strvcat( ...
            fullfile(Spth,'antsWarp.nii'), ...
            fullfile(Spth, 'antsInverseWarp.nii'));
        if exist(fullfile(Spth,'antsAffine.txt'), 'file')
            outANTS = strvcat(outANTS, fullfile(Spth,'antsAffine.txt'));
        end
        aap=aas_desc_outputs(aap,subj,'ANTs', outANTS);
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap,subj);
        
        %% Draw coregistration of structural to functional & delta structurals
        V = spm_vol(Simg);
        Y = spm_read_vols(V) - spm_read_vols(spm_vol(fullfile(Spth, ['w' Sfn Sext])));
        V.fname = fullfile(Spth, ['d' Sfn Sext]);
        spm_write_vol(V,Y);
        
        spm_check_registration(strvcat( ...
            wSimg, ...
            fullfile(Spth,['d' Sfn Sext]), ...
            mEPIimg))
        
        spm_orthviews('reposition', [0 0 0])
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO
        if aap.tasklist.currenttask.settings.diagnostic
            
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi( mEPIimg, ...
                    {Simg wSimg}, ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                    d, ... % Axis
                    [800 600], ...
                    2); % Rotations
            end
            try close(2); catch; end
            delete(fullfile(mEPIpth, ['r' mEPIfn mEPIext]))
        end
end
