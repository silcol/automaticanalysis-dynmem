function [aap,resp]=aamod_freesurfer_autorecon_mask(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        % Set subject paths
        subjname = aap.acq_details.subjects(subj).mriname;
        subjpath = aas_getsubjpath(aap,subj);
        
        % Get freesurfer input stream and pick out the structural (4th line)
%         freesurferInputStream = aas_getfiles_bystream(aap,subj,'freesurfer');
%         Simg = deblank(freesurferInputStream(4,:));    

        Simg=aas_getfiles_bystream(aap,subj,'structural');
        
        setenv('SUBJECTS_DIR', fileparts(subjpath))
        setenv('FREESURFER_DIR', aap.directory_conventions.freesurferdir)
        
        %% Try to delete old freesurfer running flags
        if exist(fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh'), 'file')
            unix(['rm ' fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh')]);
        end
        
        FScommand = ['recon-all -subjid ' subjname ' ' aap.tasklist.currenttask.settings.extraoptions];
        
        disp(FScommand)
        
        [s w] = aas_runFScommand(aap,FScommand);
                
        if s==1 %|| ~isempty(strfind(w, 'ERROR'))
            disp(w);
            error('Some freesurfer ERROR');
        end
        
        if aap.tasklist.currenttask.settings.verbose
            disp(w);
        end       
        
        %%  make output stream
        % now specific to freesurfer dirs. 
        subdir = fullfile(aas_getsubjpath(aap, subj)); % freesurfer autorecon1 dir

        freesurfer_brainMask_mgz = fullfile(subdir, 'mri', 'brainmask.mgz');
        freesurfer_brainMask_nii = fullfile(subdir, 'mri', 'brainmask.nii');
        unix(['mri_convert ' freesurfer_brainMask_mgz ' ' freesurfer_brainMask_nii]);

        aap = aas_desc_outputs(aap,subj,'structural',freesurfer_brainMask_nii);
		
        %% DIAGNOSTIC IMAGE
        mriname = aas_prepare_diagnostic(aap,subj);
        
        %% Draw structural image...
        spm_check_registration(Simg)
        
        % Colour the Freesurfer skull-stripped bit pink
        spm_orthviews('addcolouredimage',1,freesurfer_brainMask_nii, [0.9 0.4 0.4])
        
        spm_orthviews('reposition', [0 0 0])
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));

end
