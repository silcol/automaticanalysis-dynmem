% AA module
% Runs EPI slicing after BET
% aamod_realign should be run before running this module

function [aap,resp]=aamod_bet_epi_reslicing(aap,task,subj)

resp='';

switch task
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        % RESLICE THE MASKS & MESHES
        mEPIimg = aas_getfiles_bystream(aap,subj,'meanepi');
        
        % With the mean EPI, we just use the first one (there really should be only one)
        if size(mEPIimg,1) > 1
            mEPIimg = deblank(mEPIimg(1,:));
            fprintf('\tWARNING: Several mean EPIs found, considering: %s\n', mEPIimg)
        end
        
        fprintf('Reslicing brain masks to mean EPI\n')
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
        
        % Get files to reslice
        outMask = aas_getfiles_bystream(aap,subj,'BETmask');
        
        spm_reslice(strvcat(mEPIimg, outMask), resFlags);
        
        % Get the images we resliced
        outMaskEPI = '';
        for d = 1:size(outMask,1)
            [mpth mnme mext]=fileparts(outMask(d,:));
            outMaskEPI = strvcat(outMaskEPI, fullfile(mpth,['r' mnme mext]));
            % Additionally, convert into a binary image...
            img2mask(fullfile(mpth,['r' mnme mext]))
        end
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap,subj);
        
        if ~isempty(aap.tasklist.currenttask.settings.maskBrain)
            
            fprintf('Masking the brain with %s \n', aap.tasklist.currenttask.settings.maskBrain)
            % Get mask...
            for m = 1:size(outMaskEPI,1)
                if ~isempty(strfind(outMaskEPI(m,:), aap.tasklist.currenttask.settings.maskBrain))
                    M = spm_read_vols(spm_vol(deblank(outMaskEPI(m,:))));
                    M = M > 0;
                    break
                end
            end
            
            %% Diagnostic VIDEO of masks
            if aap.tasklist.currenttask.settings.diagnostic
                
                Ydims = {'X', 'Y', 'Z'};
                for d = 1:length(Ydims)
                    aas_image_avi( mEPIimg, ...
                        deblank(outMaskEPI(m,:)), ...
                        fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                        d, ... % Axis
                        [800 600], ...
                        1); % Rotations
                end
                try close(2); catch; end
            end
            
            % Get brain
            V = spm_vol(mEPIimg);
            Y = spm_read_vols(V);
            % Mask brain
            Y = Y.*M;
            % Write brain
            spm_write_vol(V, Y);
        else
            %% Diagnostic VIDEO of masks
            if aap.tasklist.currenttask.settings.diagnostic
                
                Ydims = {'X', 'Y', 'Z'};
                for d = 1:length(Ydims)
                    aas_image_avi( mEPIimg, ...
                        outMaskEPI, ...
                        fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                        d, ... % Axis
                        [800 600], ...
                        1); % Rotations
                end
                try close(2); catch; end
            end
        end
        
        %% DESCRIBE OUTPUTS!
        aap=aas_desc_outputs(aap,subj,'meanepi',mEPIimg);
        aap=aas_desc_outputs(aap,subj,'epiBETmask',outMaskEPI);
end
