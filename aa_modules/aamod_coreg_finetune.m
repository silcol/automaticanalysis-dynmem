% AA module - finetune coregistration of structural to mean EPI
% Should be done some time after normal (or extended) coregistration
% Coregistration of structural to mean EPI output by realignment in 3 steps
% 1) Copy the files to working copies...
% 2) Bias correct the mean EPI and structural
% 3) Rescale all the values remaining in the volumes from 0 to 255
% END) Do weighted coregistration, using the mean EPI mask
%


function [aap,resp]=aamod_coreg_finetune(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        %% VARIOUS DEFAULTS
        
        % Coregistration
        global defaults
        flags = defaults.coreg;
        
        % Normalisation
        defs = aap.spm.defaults.normalise;
        defs.estimate.weight = '';
        
        % ...only write out attenuation corrected image
        estopts.regtype='';    % turn off affine:
        writeopts.biascor = 1;
        writeopts.GM  = [0 0 0];
        writeopts.WM  = [0 0 0];
        writeopts.CSF = [0 0 0];
        writeopts.cleanup = [0];
        
        % Realignment
        defs = aap.spm.defaults.realign;
        
        % ...flags to pass to routine to create resliced images
        % (spm_reslice)
        resFlags = struct(...
            'interp', defs.write.interp,...       % interpolation type
            'wrap', defs.write.wrap,...           % wrapping info (ignore...)
            'mask', defs.write.mask,...           % masking (see spm_reslice)
            'which', 1,...     % what images to reslice
            'mean', 0);           % write mean image
        
        %% 1) Get structural, mean EPI and masks...
        % Check local structural directory exists
        
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        for b = 1:size(Simg, 1)
            % We want BETed image, ideally
            if strfind(Simg(b,:), 'bet_')
                Simg = deblank(Simg(b,:));
                break
            end
        end
        
        % Look for mean functional
        mEPIimg = aas_getfiles_bystream(aap,subj,'meanepi');
        if size(mEPIimg,1) > 1
            aas_log(aap, false, 'Found more than 1 mean functional images, using first.');
        end
        mEPIimg = deblank(mEPIimg(1,:));
        
        % Look for BET brain mask
        bSimg = aas_getfiles_bystream(aap,subj,'BETmask');
        for b = 1:size(bSimg, 1)
            if strfind(bSimg(b,:), 'brain_mask')
                bSimg = deblank(bSimg(b,:));
                break
            end
        end
        
        % Look for functional BET brain mask
        bmEPIimg = aas_getfiles_bystream(aap,subj,'epiBETmask');
        for b = 1:size(bmEPIimg, 1)
            if strfind(bmEPIimg(b,:), 'brain_mask')
                bmEPIimg = deblank(bmEPIimg(b,:));
                break
            end
        end
        
        if aap.tasklist.currenttask.settings.bias
            %% 2a) Bias correct images
            
            fprintf('Bias correct structural and mean EPI\n')
            
            [Spth, Sfn, Sext] = fileparts(Simg);
            [mEPIpth, mEPIfn, mEPIext] = fileparts(mEPIimg);
            
            out = spm_preproc(Simg, estopts);
            [sn,isn]   = spm_prep2sn(out);
            spm_preproc_write(sn, writeopts);
            
            out = spm_preproc(mEPIimg, estopts);
            [sn,isn]   = spm_prep2sn(out);
            spm_preproc_write(sn, writeopts);
            
            c_Simg = fullfile(Spth, ['m' Sfn Sext]);
            c_mEPIimg = fullfile(mEPIpth, ['m' mEPIfn mEPIext]);
        else
            %% 2b) Copy files to do preprocessing and coregistration on...
            
            fprintf('Copy images before processing them\n')
            
            [Spth, Sfn, Sext] = fileparts(Simg);
            [mEPIpth, mEPIfn, mEPIext] = fileparts(mEPIimg);
            
            c_Simg = fullfile(Spth, ['c_' Sfn Sext]);
            c_mEPIimg = fullfile(mEPIpth, ['c_' mEPIfn mEPIext]);
            
            unix(['cp ' Simg ' ' c_Simg])
            unix(['cp ' mEPIimg ' ' c_mEPIimg])
        end
        
        %% 3) RESCALE IMAGES...
        
        fprintf('Rescale the images to be coregistered\n')
        
        rescale4coreg(c_Simg)
        rescale4coreg(c_mEPIimg)
        
        %% 4)  Mean Functional to Structural (weighting with mEPI mask)
        
        % Add weighting...
        flags.estimate.wgt = spm_vol(bmEPIimg);
        
        % Estimate parameters
        x = spm_coreg_weighted(spm_vol(c_mEPIimg), ...
            spm_vol(c_Simg), ...
            flags.estimate);
        Mf = inv(spm_matrix(x));
        
        % Set the new space for the structural
        MM = spm_get_space(Simg);
        spm_get_space(Simg, Mf*MM);
        
        fprintf(['\tThe realignment parameters are the following\n' ...
            'x: %0.3f   y: %0.3f   z: %0.3f   p: %0.3f   r: %0.3f   j: %0.3f'], ...
            x(1), x(2), x(3), x(4), x(5), x(6))
        
        %% Some diagnostic images
        mriname = aas_prepare_diagnostic(aap,subj);
        
        spm_check_registration(strvcat( ...
            Simg, ... % Get structural
            mEPIimg)); % Get mean EPI across sessions
        spm_orthviews('reposition', [0 0 0])
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
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
            
            % Get resliced mean EPI
            [mEPIpth, mEPIfn, mEPIext] = fileparts(deblank(mEPIimg(aap.tasklist.currenttask.settings.structural,:)));
            spm_reslice(strvcat(Simg, mEPIimg), resFlags);
            
            if isempty(which('edge'))
                aas_log(aap,false,'Can''t find "edge" function - perhaps because you don''t have the image processing toolbox. Skipping diagnostic video');
            else
                Ydims = {'X', 'Y', 'Z'};
                for d = 1:length(Ydims)
                    aas_image_avi( fullfile(mEPIpth, ['r' mEPIfn mEPIext]), ...
                        Simg, ...
                        fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                        d, ... % Axis
                        [800 600], ...
                        2); % Rotations
                end
            end
            
            try close(2); catch; end
            delete(fullfile(mEPIpth, ['r' mEPIfn mEPIext]))
        end
        
        %% Describe the outputs
        
        aap = aas_desc_outputs(aap,subj,'structural',Simg);
        
    case 'checkrequirements'
        aas_log(aap,0,'No need to trim or skull strip structural\n' );
end
