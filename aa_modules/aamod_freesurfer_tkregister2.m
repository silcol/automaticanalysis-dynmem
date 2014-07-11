% Store a registration from EPI space to Freesurfer. Used for displaying
% functional overlays in e.g. tksurfer.
% [aap,resp]=aamod_freesurfer_tkregister2(aap,task,subj)
function [aap,resp]=aamod_freesurfer_tkregister2(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        
        % Set subject paths
        subjname = aap.acq_details.subjects(subj).mriname;
        subjpath = aas_getsubjpath(aap,subj);
        
        setenv('SUBJECTS_DIR', fileparts(subjpath))
        setenv('FREESURFER_DIR', aap.directory_conventions.freesurferdir)
        
        %% Try to delete old freesurfer running flags
        if exist(fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh'), 'file')
            unix(['rm ' fullfile(subjpath, 'ANAT', subjname, 'scripts', 'IsRunning.lh+rh')]);
        end

        epipath = aas_getfiles_bystream(aap,subj,'meanepi');

        outpath = fullfile(subjpath,'spmregister.dat');
        
        FScommand = sprintf(['tkregister2 --s %s ' ...
            '--mov %s --regheader ' ...
            '--reg %s --surf orig --noedit'],subjname,epipath,outpath);
        disp(FScommand)
        [s w] = aas_runFScommand(aap,FScommand);
        
        if aap.tasklist.currenttask.settings.verbose
            disp(w);
        end
        
        if s==1 %|| ~isempty(strfind(w, 'ERROR'))
            error('Some freesurfer ERROR');
        end
        
        %%  make output stream
        aap = aas_desc_outputs(aap,subj,'freesurfer_registration',outpath);
end
