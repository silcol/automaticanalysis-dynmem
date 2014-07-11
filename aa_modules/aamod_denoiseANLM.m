% AA module
% Denoise a series of structurals...
% NOTE: This is based upon and requires the MRI Denoising Package by Pierrick Coupe
% (This is not provided with AA at this moment)
% Please cite his work, as described within the MRIDenoisingAONLM function!

function [aap,resp]=aamod_denoiseANLM(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';  % this module needs to be run once per subject
        
    case 'description'
        resp='denoise ANLM';
        
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        Sfn = aas_getfiles_bystream(aap,subj,'structural');
        
        DHimg = aas_findstream(aap,'structural_dicom_header', subj);
        
        if ~isempty(DHimg)
            % dcmhdr{n}.SeriesDescription
            dcmhdr = [];
            load(DHimg);
        end
        
        %% Denoise the images
        
        outstruct = '';
        outresid = '';
        
        for d = aap.tasklist.currenttask.settings.structural
            fprintf('Denoise structural image %s!\n', Sfn(d,:))
            if ~isempty(DHimg)
                fprintf('\t structural type %s!\n', dcmhdr{d}.SeriesDescription)
            else
                fprintf('\t structural type UNKNOWN!\n')
            end
            
            V = spm_vol(Sfn(d,:));
            Y = spm_read_vols(V);
            
            % Denoised Y
            dY = MRIDenoisingAONLM(Y, ...
                aap.tasklist.currenttask.settings.patchsize, ...
                aap.tasklist.currenttask.settings.searcharea, ...
                aap.tasklist.currenttask.settings.beta, ...
                aap.tasklist.currenttask.settings.rician, ...
                aap.tasklist.currenttask.settings.verbose);
            
            % Residuals...
            rY = dY - Y;
            
            % Save filtered image & residual image
            dV = V;
            [pth, fn, ext] = fileparts(dV.fname);
            dV.fname = fullfile(pth, ['d' fn ext]);
            outstruct = strvcat(outstruct, dV.fname);
            spm_write_vol(dV, dY);
            
            rV = V;
            [pth, fn, ext] = fileparts(rV.fname);
            rV.fname = fullfile(pth, ['res_d' fn ext]);
            outresid = strvcat(outresid, rV.fname);
            spm_write_vol(rV, rY);
            
            try close(2); catch; end
            
            mriname = aas_prepare_diagnostic(aap,subj);
            
            %% Draw noisy and denoised structural...
            spm_check_registration(strvcat(V.fname, dV.fname, rV.fname))
            
            spm_orthviews('reposition', [0 0 0])
            
            print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_' num2str(d) '.jpeg']));
            
            %% Diagnostic VIDEO
            if aap.tasklist.currenttask.settings.diagnostic
                [junk, ROIname{r}] = fileparts(ROIimg(r,:));
                
                aas_image_avi({V.fname dV.fname}, ...
                    [], ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' num2str(d) '.avi']), ...
                    3, ... % Axis
                    [800 600], ...
                    2); % Rotations
                try close(2); catch; end
            end
        end
        
        %% DESCRIBE OUTPUTS!
        
        if ~isempty(DHimg)
            dcmhdr = {dcmhdr{aap.tasklist.currenttask.settings.structural}};
            save(DHimg, 'dcmhdr')
            
            aap=aas_desc_outputs(aap,subj,'structural_dicom_header', DHimg);
        end
        
        % Structural image after denoising
        aap=aas_desc_outputs(aap,subj,'structural', outstruct);
        
        % Residual image after denoising
        aap=aas_desc_outputs(aap,subj,'denoiseResidual', outresid);
        
end
