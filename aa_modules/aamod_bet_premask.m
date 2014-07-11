% AA module
% Runs a premasking of the structural (good to do before using aamod_bet)
% 1) Coregisters the T1 template to the structural
% 2) Reslices this T1 template to the structural
% 3) Masks the structural by the T1 template matrix, cutting out neck

function [aap,resp]=aamod_bet_premask(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';  % this module needs to be run once per subject
        
    case 'description'
        resp='SPM5 align';
        
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        
        % Which file is considered, as determined by the structural parameter!
        if size(Simg,1) > 1
            Simg = deblank(Simg(aap.tasklist.currenttask.settings.structural, :));
            fprintf('WARNING: Several structurals found, considering: \n')
            for t = 1:length(aap.tasklist.currenttask.settings.structural)
                fprintf('\t%s\n', Simg(t,:))
            end
        end
        
        % Image that we will be using for coregistration...
        cSimg = deblank(Simg(1,:));
        Sdir = fileparts(cSimg);
        
        %% 0) Check that the templates we need exist!
        % Get the template
        sTimg = aap.directory_conventions.T1template;
        if ~exist(sTimg, 'file')
            aas_log(aap, true, sprintf('Couldn''t find template T1 image %s.', sTimg));
        end
        
        %% 1) Structural to T1 template
        fprintf('Coregistering the T1 template to structural\n')
        
        global defaults %#ok<TLEV>
        flags = defaults.coreg;
        
        % Copy template to structural location
        copyfile(sTimg, fullfile(Sdir, 'T1.nii'));
        sTimg = fullfile(Sdir, 'T1.nii');
        
        % Coregister template to first Structural included
        x = spm_coreg(spm_vol(cSimg), spm_vol(sTimg), flags.estimate);
        
        % Set entire template matrix to 1
        V = spm_vol(sTimg);
        Y = spm_read_vols(V);
        Y(:) = 1;
        spm_write_vol(V,Y);

        % Set the new space for the template
        MM = spm_get_space(sTimg);
        spm_get_space(sTimg, spm_matrix(x)\MM);
        
        %% 2) Then reslice the Template
        
        fprintf('Reslicing T1 template to structural\n')
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
        spm_reslice(strvcat(cSimg, sTimg), resFlags);
        
        %% 3) Mask the Structural(s) image using the T1 template
        
        fprintf('Mask structural with resliced T1 template\n')
        
        M = spm_read_vols(spm_vol(fullfile(Sdir, 'rT1.nii')));
        M = M>0;
        
        for t = 1:length(aap.tasklist.currenttask.settings.structural)
            % Mask structural
            V = spm_vol(deblank(Simg(t,:)));
            Y = spm_read_vols(V);
            Y = Y.*M;
            spm_write_vol(V,Y);
        end
        
        delete(fullfile(Sdir, 'T1.nii'));
        delete(fullfile(Sdir, 'rT1.nii'));
        
        %% DIAGNOSTIC IMAGE
        mriname = aas_prepare_diagnostic(aap,subj);
        
        %% Draw structural image(s)...
        spm_check_registration(Simg)
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO of structural(s)
        if aap.tasklist.currenttask.settings.diagnostic
            Ydims = {'X', 'Y', 'Z'};
            
            for d = 1:length(Ydims)
                aas_image_avi( Simg, ...
                    [], ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                    d, ... % Axis
                    [800 600], ...
                    2); % Rotations
            end
            try close(2); catch; end
        end
        
        %% DESCRIBE OUTPUTS!
        % Structural image after BETting
        aap=aas_desc_outputs(aap,subj,'structural', Simg);
end
