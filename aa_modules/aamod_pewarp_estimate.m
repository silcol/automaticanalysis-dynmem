% AA module - coregistration of EPI to structural with unwarping
% [aap,resp]=aamod_pewarp_estimate(aap,task,subj)
% Ideally preceded by aamod_coreg_extended, to increase rigid alignment!
%% README
%   1) After running aamod_coregister_unwarp the functional and structural
% images are coregistered, so you can directly feed them into
% normalisation.
%   2) It is assumed that the structural has been brain extracted (with BET,
% BSE, etc.), and ideally bias corrected. The mean EPI is bias corrected
% within the script
%   3) This has only been tested with SPM8.
%   4) mex_pewarpcost_regularised is a compiled function that is built for
% Matlab 7.8. It will probably not work in older versions. If you want to
% recompile you can use the buildC99ompblas script, but it's probably quite
% a hassle as you'll need a recent version of gcc.
%
% If you run into any problems, let us know!
% Tool developer: Eelke (eelke.visser@donders.ru.nl)
% Ported to AA: Alejandro (a.vicente.grab@gmail.com)
%
% If you use this tool, please cite Eelke's work:
% EPI DISTORTION CORRECTION BY CONSTRAINED NONLINEAR COREGISTRATION IMPROVES GROUP FMRI
% E. Visser1,2, S. Qin1,3, and M. P. Zwiers1,2
% 1Donders Institute for Brain, Cognition and Behaviour, Radboud University Nijmegen, Nijmegen, Netherlands, 2Department of Psychiatry, Radboud
% University Nijmegen Medical Centre, Nijmegen, Netherlands, 3Department of Neurology, Radboud University Nijmegen Medical Centre, Nijmegen,
% Netherlands
% Proc. Intl. Soc. Mag. Reson. Med. 18 (2010)
%%
function [aap,resp]=aamod_pewarp_estimate(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        % @@@ FURTHER IMPROVEMENTS?
        % DECIDE ORDER FROM DISCRETE FOURIER OF THE FIELDMAP ITSELF?  
        
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        if size(Simg,1) > 1
            aas_log(aap, false, sprintf('Found more than 1 structural images, using structural %d', ...
                aap.tasklist.currenttask.settings.structural));
            Simg = deblank(Simg(aap.tasklist.currenttask.settings.structural,:));
        end
        
        % Look for mean functional
        mEPIimg = aas_getfiles_bystream(aap,subj,'meanepi');
        if size(mEPIimg,1) > 1
            aas_log(aap, false, 'Found more than 1 mean functional images, using first.');
            mEPIimg = deblank(mEPIimg(1,:));
        end   
        
        if isempty(aap.tasklist.currenttask.settings.order)
            %% A)
            % If we know what size in mm we want the orders to be, then we just
            % calculate them from the size of the mean EPI
            
            V = spm_vol(mEPIimg);            
            
            [junk, mmFOV] = vox2mm(V);
            
            % Eelke Visser suggested dividing field of view by
            % approximately 20 mm to get the order
            aap.tasklist.currenttask.settings.order = round(mmFOV ./ ...
                aap.tasklist.currenttask.settings.orderMM);
        end
        order = aap.tasklist.currenttask.settings.order;
        
        %% Brain mask the mean EPI
        % Select the mask
        BETfn = aas_getfiles_bystream(aap,subj,'epiBETmask');
        for d = 1:size(BETfn,1)
            if strfind(BETfn(d,:), 'brain')
                BETfn = BETfn(d,:);
                break
            end
        end
        
        % Mask and write the mean EPI
        V = spm_vol(mEPIimg);
        Y = spm_read_vols(V);
        M = spm_read_vols(spm_vol(BETfn));
        Y = Y.*M;
        spm_write_vol(V,Y);
        
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
        
        % Reslice mean EPI to structural
        spm_reslice(strvcat(mEPIimg, Simg), resFlags);
        
        %% Let's remove bias from the image...
        if aap.tasklist.currenttask.settings.bias
            fprintf('\nRemoving bias from the mean EPI')
            
            % Defaults for normalisation
            defs =aap.spm.defaults.normalise;
            defs.estimate.weight = '';
            
            % Only write out attenuation corrected image
            writeopts.biascor = 1;
            writeopts.GM  = [0 0 0];
            writeopts.WM  = [0 0 0];
            writeopts.CSF = [0 0 0];
            writeopts.cleanup = 0;
            estopts.regtype='';    % turn off affine:
            
            out = spm_preproc(mEPIimg,estopts);
            sn   = spm_prep2sn(out);
            spm_preproc_write(sn, writeopts);
            
            [pthM, fnM, extM] = fileparts(mEPIimg);
            mEPIimg = fullfile(pthM, ['m' fnM extM]);
        end
        
        [pthM, fnM, extM] = fileparts(mEPIimg);
        
        %% ESTIMATE PEWARP FIELD!
        [pthS, fnS, extS] = fileparts(Simg);
        
        PEparams = pewarp_fminunc_regularised(fullfile(pthS, ['r' fnS extS]), ...
            fullfile(pthM, [fnM extM]), order, 1e6);
        
        % Save the parameters
        save(fullfile(pthM, 'PEparams.mat'), 'PEparams', 'order')
        
        % Save a mean EPI with the modulations
        write_warped_no_jacobian(PEparams, 1e6, order, ...
                    fullfile(pthM, [fnM extM]), ...
                    fullfile(pthM, ['p' fnM extM]))
        
        % Save a difference image as well
        V = spm_vol(fullfile(pthM, [fnM extM]));
        Y = spm_read_vols(V);
        pY = spm_read_vols(spm_vol(fullfile(pthM, ['p' fnM extM])));
        dY = pY - Y;
        
        V.fname = fullfile(pthM, ['d' fnM extM]);
        spm_write_vol(V,dY);
        
        %% Some diagnostic images
        mriname = aas_prepare_diagnostic(aap,subj);
        
        spm_check_registration(strvcat( ...
            fullfile(pthS, ['r' fnS extS]), ... % Get resliced structural
            fullfile(pthM, ['d' fnM extM]), ... % Get mean EPI before
            fullfile(pthM, ['' fnM extM]), ... % Get mean EPI before
            fullfile(pthM, ['p' fnM extM]))); % Get mean EPI, after...
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO
        if aap.tasklist.currenttask.settings.diagnostic
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi({fullfile(pthM, ['p' fnM extM]) fullfile(pthM, ['d' fnM extM])}, ...
                fullfile(Spth, ['r' Sfn Sext]), ...
                fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                d, ... % Axis
                [800 600], ...
                2); % Rotations
            end
            try close(2); catch; end
        end
        
        %% Describe the outputs
        
        aap = aas_desc_outputs(aap,subj,'meanepi',fullfile(pthM, ['p' fnM extM]));
        aap = aas_desc_outputs(aap,subj,'dPEwarp_meanepi',fullfile(pthM, ['d' fnM extM]));
        aap = aas_desc_outputs(aap,subj,'PEwarp_params',fullfile(pthM, 'PEparams.mat'));
        
    case 'checkrequirements'
        aas_log(aap,0,'Need to trim or skull strip structural\n' );
end