function [aap,resp]=aamod_freesurfer_autorecon1(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit' 
        
        % Load the Structural
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        if size(Simg,1) > 1
            aas_log(aap, false, sprintf('Found more than 1 structural images, using structural %d', ...
                aap.tasklist.currenttask.settings.structural));
            Simg = Simg(aap.tasklist.currenttask.settings.structural, :);
        end
        Simg = strvcat2cell(Simg);
        
        % Set subject paths
        subjname = aap.acq_details.subjects(subj).mriname;
        subjpath = aas_getsubjpath(aap,subj);
        
        %% initialise fileserver folder structure and nii and mgh files
        aas_freesurfer_init(aap, subjpath, subjname, Simg, 1)
                
        %% Try to delete old freesurfer running flags
        if exist(fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh'), 'file')
            unix(['rm ' fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh')]);
        end
        
        % SASHA METHOD...
        
        FScommand = ['recon-all -subjid ' subjname ' ' aap.tasklist.currenttask.settings.extraoptions];
        
        disp(FScommand)
        
        [s w] = aas_runFScommand(aap,FScommand);
           
        disp(w);
        
        keyboard
        
        %% DEBUG
        FScommand = ['recon-all -subjid ' subjname ' -autorecon2 -noconform'];
        disp(FScommand)
                
        keyboard
        
        [s w] = aas_runFScommand(aap,FScommand);
        
        FScommand = ['recon-all -subjid ' subjname ' -autorecon3 -noconform'];
        disp(FScommand)
        
        [s w] = aas_runFScommand(aap,FScommand);
        
        keyboard
           
        %%  make output stream
        FSAR1Dir = fullfile(aas_getsubjpath(aap, subj)); % freesurfer autorecon1 dir
        outstream = dirrec(FSAR1Dir);
        aap=aas_desc_outputs(aap,subj,'freesurfer',outstream);
        
        %         [s w] = aas_shell(FScommand);
        %         if aap.tasklist.currenttask.settings.verbose
        %             disp(w);
        %         end
        %
        
        
end
end