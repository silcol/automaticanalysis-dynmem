% AA module
% Convert the fieldmap images (2 mag and 1 phase) into a Voxel Displacement
% Map (VDM) using the FieldMap toolbox of SPM

function [aap,resp]=aamod_fieldmap2VDM(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        if isempty(aap.tasklist.currenttask.settings.tert)
           aas_log(aap, true, 'You must specify a Total EPI Readout Time [in ms]') 
        end
        
        if isempty(aap.tasklist.currenttask.settings.kdir)
            aas_log(aap, true, 'You must specify a Blip Direction [1 or -1] (dependent on PE direction)') 
        end
        
        HDRfn = aas_getfiles_bystream(aap,subj,'fieldmap_dicom_header');
        if isempty(aap.tasklist.currenttask.settings.te1) || ...
                isempty(aap.tasklist.currenttask.settings.te2)
            aas_log(aap, false, 'TE not specified, so let us get it from the fieldmap headers');
            
            TE = [];
            HDR = load(HDRfn);
            for h = 1:length(HDR.dcmhdr)
                TE = [TE HDR.dcmhdr{h}.EchoTime];
            end
            TE = unique(TE);
            if length(TE) > 2
                aas_log(aap, true, 'Too many TEs!');
            end
            
            aap.tasklist.currenttask.settings.te1 = TE(1);
            aap.tasklist.currenttask.settings.te2 = TE(2);
        end
        
        % Defaults specified in this path
        % You can set your own settings in your own copy of the XML or recipe!
        pm_defs = ...
            [aap.tasklist.currenttask.settings.te1, ... % te1
            aap.tasklist.currenttask.settings.te2, ... % te2
            aap.tasklist.currenttask.settings.epifm, ... % epifm
            aap.tasklist.currenttask.settings.tert, ... % tert
            aap.tasklist.currenttask.settings.kdir, ... % kdir
            aap.tasklist.currenttask.settings.mask, ... % (mask)
            aap.tasklist.currenttask.settings.match, ... % (match)
            aap.tasklist.currenttask.settings.writeunwarpedEPI]; % (writeunwarpedEPI)
        
        aas_log(aap, false, sprintf(['Parameters used:' ...
            '\nTE1: %0.3f\tTE2: %0.3f\tTotEPIread: %0.3f\tBlipDir: %d'], ...
            pm_defs(1), pm_defs(2), pm_defs(4), pm_defs(5)));

        ts = aap.tasklist.currenttask.settings;
        FMfn = aas_getfiles_bystream(aap,subj,'fieldmap');

        % Fieldmap path
        FMdir = fullfile(aas_getsubjpath(aap, subj), aap.directory_conventions.fieldmapsdirname);
        
        % The folder fieldmaps must exist...
        if ~exist(FMdir, 'dir')
            mkdir(FMdir)
        end

        if isempty(ts.fieldmap2session)
            % assume we are using a single fieldmap for all sessions
            ts.fieldmap2session = ones(1,length(...
                aap.acq_details.selected_sessions));
        else
            % sanity check
            assert(length(ts.fieldmap2session) == ...
                length(aap.acq_details.selected_sessions),...
                ['fieldmap2session must be a vector of the same ' ...
                'length as the number of selected sessions.']);
        end

        % number of different fieldmap undistortions to use
        fields = unique(ts.fieldmap2session);
        nfields = length(unique(ts.fieldmap2session));

        outstream = {};

        % process each fieldmap undistortion separately
        for fi = 1:nfields
            % indices to EPI sessions for this fieldmap
            sessinds = find(ts.fieldmap2session == fields(fi));
            % subdirs for each session
            fielddir = fullfile(FMdir,sprintf('fieldmap_%d',fields(fi)));
            if ~exist(fielddir,'dir')
                mkdir(fielddir);
            end
            % directory for relevant EPIs
            epidir = arrayfun(@(sess)aas_getsesspath(aap,subj,sess),...
                sessinds,'uniformoutput',false);
            % prepare directory for fieldmap
            existingfields = dir(fullfile(fielddir,'*.nii'));
            if ~isempty(existingfields)
                delete(fullfile(fielddir,'*.nii'));
            end
            % copy relevant fieldmaps to directory (the fieldmapping
            % toolbox is not very flexible here)
            indend = fields(fi) + ts.nimages - 1;
            fieldmaps = FMfn(fields(fi):indend,:);
            fprintf('running undistortion %d of %d:\n',...
                fi,nfields);
            display(fieldmaps);
            fprintf('epi series:\n');
            display(char(epidir'));

            for f = 1:ts.nimages
                [success,msg,msgid] = copyfile(deblank(fieldmaps(f,:)),fielddir);
                assert(success,'copy failed: from %s to %s',...
                    fieldmaps(f,:),fielddir);
            end
            % run the beast
            FieldMap_preprocess(fielddir,epidir,pm_defs,'session');

            % rename outputs to mitigate inconsistent output behaviour
            if length(epidir) == 1
                VDMs = dir(fullfile(fielddir, 'vdm*.nii'));
                [junk, fn, ext] = fileparts(VDMs.name);
                unix(['mv ' fullfile(fielddir, VDMs.name) ' ' ...
                    fullfile(fielddir, [fn '_session1' ext])]);
            end
            % copy VDMs to root fieldmap directory and rename to match
            % session names
            VDMs = dir(fullfile(fielddir, '*session*.nii'));
            for v = 1:length(VDMs)
                indx = strfind(VDMs(v).name, 'session');
                %s = VDMs(v).name(indx+7:end-4); % Get number after 'session'
                %s = str2double(s);
                % finding the session index now involves a lot less reverse
                % engineering
                s = sessinds(v);
                % This gets the selected sessions!
                newfn = [VDMs(v).name(1:indx-1), ...
                    aap.acq_details.sessions(...
                    aap.acq_details.selected_sessions(s)).name,'.nii'];
                newpath = fullfile(FMdir,newfn);
                success = copyfile(fullfile(fielddir,VDMs(v).name),...
                    newpath);
                assert(success,'copy failed: from %s to %s',...
                    fullfile(fielddir,VDMs(v).name),newpath);
                outstream = [outstream newpath];
            end
        end

        if isempty(outstream)
            aas_log(aap, true,...
                'Could not find a fieldmap VDM after processing!');
        end

        aap=aas_desc_outputs(aap,subj,'fieldmap',outstream);
end
