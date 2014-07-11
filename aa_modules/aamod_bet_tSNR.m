% AA module
% Creates a brain mask, looking at regions of low tSNR
% [EXPERIMENTAL MODULE, PROCEED WITH CAUTION]

function [aap,resp]=aamod_bet_tSNR(aap,task,subj)

resp='';

switch task
        
    case 'doit'
        
        % Get images...        
        betEPIimg = aas_getfiles_bystream(aap,subj,'epiBETmask');
        [betEPIpth, betEPIfn, betEPIext] = fileparts(betEPIimg);
        
        % Select the SNR images...
        sessions = aap.tasklist.currenttask.settings.sessions;
        if isempty(sessions);
            sessions = aap.acq_details.selected_sessions;
        end
        tSNR = 0;
        % ...add session tSNRs...
        for sess = sessions
            V = spm_vol(aas_getfiles_bystream(aap,subj,sess,'tSNR'));
            tSNR = tSNR + spm_read_vols(V);
        end
        % ... and average.
        tSNR = tSNR ./ length(sessions);
        
        % Mask the tSNR image...
        fprintf('Masking the tSNR EPI with %s \n', aap.tasklist.currenttask.settings.maskBrain)
        % Get mask...
        M =[];
        for m = 1:size(betEPIimg,1)
            if ~isempty(strfind(betEPIimg(m,:), aap.tasklist.currenttask.settings.maskBrain))
                M = spm_read_vols(spm_vol(deblank(betEPIimg(m,:))));
                M = M > 0;
                break
            end
        end
        if isempty(M)
            aas_log(aap,true,'We do not have a mask!')
        end
        tSNR = tSNR .* M;
        SNRimg = fullfile(betEPIpth, ['tSNR_' betEPIfn betEPIext]);
        V.fname = SNRimg;
        
        if strcmp(aap.tasklist.currenttask.settings.transform, 'none')
            spm_write_vols(V,tSNR);
        elseif strcmp(aap.tasklist.currenttask.settings.transform, 'ANTS')
            % For ANTS we want to do an inverse transform then scale it
            % from 0 to 1
            
            % Smooth 
            tSNR = smooth3(tSNR, 'gaussian', 21);
            tSNR = tSNR .* M;
            % First invert!
            tSNR = -tSNR;
            % Then find out maximum and minimum
            tSNRvals = tSNR(tSNR<0);
            tSNRmax = max(tSNRvals);
            tSNRmin = min(tSNRvals);
            tSNR(tSNR<0) = (tSNRvals - tSNRmin) ./ (tSNRmax - tSNRmin);
            
            % We want to weight things away from small values...
            tSNR = tSNR .^ 3;
            
            % Write the image...
            V.dt(1) = 64;
            spm_write_vol(V,tSNR);
            
            % Make it into a mask...
            img2mask(V.fname);
        else
            aas_log(aap, true, ['No such transform exists in' mfilename ' module'])
        end
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap,subj);
        
        % Show image of tSNR
        spm_check_registration(SNRimg)
        
        spm_orthviews('reposition', [0 0 0])
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO of masks
        if aap.tasklist.currenttask.settings.diagnostic
            
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi( SNRimg, ...
                    deblank(betEPIimg(m,:)), ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                    d, ... % Axis
                    [800 600], ...
                    1); % Rotations
            end
            try close(2); catch; end
        end
        
        %% DESCRIBE OUTPUTS!
        aap=aas_desc_outputs(aap,subj,'tSNR',SNRimg);
end
