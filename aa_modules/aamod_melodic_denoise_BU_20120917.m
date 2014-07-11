% AA module
% Runs MELODIC on all sessions of each single subject
% This automatically transforms the 3D data into 4D data as well
% [NOTE: This function may become obsolete later on]

function [aap,resp]=aamod_melodic_denoise(aap,task,subj,sess)

resp='';

switch task
        
    case 'report'
        
    case 'doit'
                
        spaced_EPIimg = [];
        
        sessPth = aas_getsesspath(aap,subj,sess);
        cd(sessPth)
        
        %% retrieve TR from DICOM header
        % TR is manually specified (not recommended as source of error)
        if isfield(aap.tasklist.currenttask.settings,'TR') && ...
                ~isempty(aap.tasklist.currenttask.settings.TR)
            TR =aap.tasklist.currenttask.settings.TR;
        else
            % Get TR from DICOM header
            DICOMHEADERS=load(aas_getfiles_bystream(aap,subj,sess,'epi_dicom_header'));
            try
                TR = DICOMHEADERS.DICOMHEADERS{1}.volumeTR;
            catch
                % [AVG] This is for backwards compatibility!
                TR = DICOMHEADERS.DICOMHEADERS{1}.RepetitionTime/1000;
            end
        end
        
        % Let us use the native space...
        EPIimg = aas_getfiles_bystream(aap,subj,sess,'epi');
        
        for e = 1:size(EPIimg,1)
            [pth, nme, ext] = fileparts(EPIimg(e,:));
            spaced_EPIimg = [spaced_EPIimg nme ext ' '];            
        end
        
        mriname = aas_prepare_diagnostic(aap,subj);
        
        %% CONCATENATE THE DATA...
        fprintf('\nConcatenating the data')
        
        data4D = fullfile(sessPth, sprintf('4Ddata_%s.nii', mriname));
        
        [junk, w]=aas_runfslcommand(aap, ...
            sprintf('fslmerge -t %s %s', ...
            data4D, ...
            spaced_EPIimg));
        
        %% RUN MELODIC
        fprintf('\nRunning MELODIC\n')
        
        outDir = fullfile(sessPth, 'MELODIC');
        if ~exist(outDir, 'dir')
            mkdir(outDir)
        end
        
        FSLcommand = sprintf('melodic -i %s %s -o %s --tr=%0.4f', ...
            data4D, ...
            aap.tasklist.currenttask.settings.MELODICoptions, ...
            outDir, ...
            TR);
        disp(FSLcommand)
        [junk, w] = aas_runfslcommand(aap, FSLcommand);
        disp(w);       
        
        %% FILTER COMPONENTS
        fprintf('\nRunning RegFilt\n')
        
        FSLcommand = sprintf('fsl_regfilt -i %s -d %s -o %s -F -v --debug', ...
            data4D, ...
            fullfile(outDir, 'melodic_mix'), ...
            data4D);
        disp(FSLcommand)
        [junk, w] = aas_runfslcommand(aap, FSLcommand);
        disp(w);
        
        %% Find filtered components...
        % Get all probability maps and frequencies
        C = dir(fullfile(sessPth, 'MELODIC', 'stats', 'probmap_*.nii'));
        
        % Read output and get components that are filtered
        compStart = strfind(w, 'Calculating filtered data') + 25;
        compEnd = strfind(w, 'newMix') - 1;
        compClean = str2num(w(compStart:compEnd));
        compAll = 1:length(C);
        compFiltered = compAll(~ismember(compAll, compClean));
        
        % Save the identities of the filtered and clean components...
        save(fullfile(sessPth, 'components.mat'), 'compClean', 'compFiltered')
        
        % Average probability maps and spectra of filtered components
        probmapFiltered = 0;
        spectFiltered = 0;
        for c = compFiltered
            % Pmap
            V = spm_vol(fullfile(sessPth, 'MELODIC', 'stats', sprintf('probmap_%d.nii', c)));
            probmapFiltered = probmapFiltered + spm_read_vols(V);
            % Spectrum
            spectFiltered = spectFiltered + load(fullfile(sessPth, 'MELODIC', 'report', sprintf('f%d.txt', c)));
        end
        probmapFiltered = probmapFiltered/length(compFiltered);
        spectFiltered = spectFiltered/length(compFiltered);
        
        % Save probmap
        V.fname = fullfile(sessPth, 'probmap_Filtered.nii');
        spm_write_vol(V, probmapFiltered);
        % Save and plot spectrum
        save(fullfile(sessPth, 'spect_Filtered.mat'), 'spectFiltered');
        
        % Average probability maps and spectra of filtered components
        probmapClean = 0;
        spectClean = 0;
        for c = compClean
            % Pmap
            V = spm_vol(fullfile(sessPth, 'MELODIC', 'stats', sprintf('probmap_%d.nii', c)));
            probmapClean = probmapClean + spm_read_vols(V);
            % Spectrum
            spectClean = spectClean + load(fullfile(sessPth, 'MELODIC', 'report', sprintf('f%d.txt', c)));
        end
        probmapClean = probmapClean/length(compFiltered);
        spectClean = spectClean/length(compClean);
        
        % Save probmap
        V.fname = fullfile(sessPth, 'probmap_Clean.nii');
        spm_write_vol(V, probmapClean);
        % Save and plot spectrum
        save(fullfile(sessPth, 'spect_Clean.mat'), 'spectClean');
        
        %% DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap, subj);
        
        h = figure;
        hold on
        plot(spectClean, 'ob');
        plot(spectFiltered, 'or');
        axis tight
        legend({sprintf('Clean (%d)', length(compClean)), sprintf('Filtered (%d)', length(compFiltered))})
        maxX = 100/(TR*2);
        ticksX = get(gca, 'xtick') * maxX / length(spectFiltered);
        set(gca, 'xticklabel', ticksX);
        xlabel('Frequency (in Hz/100')
        ylabel('Power')
        title('Mean powerspectrum of timecourses')
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_Spectrum_' aap.acq_details.sessions(sess).name '.jpeg']));
        close(h);
        
        %% DECOMPOSE FILTERED DATA INTO IMAGES
        M = 0;
        
        [junk, w]=aas_runfslcommand(aap, ...
            sprintf('fslsplit %s', ...
            data4D));
        
        dEPIimg = {};
        for e = 1:size(EPIimg,1)
            [pth, nme, ext] = fileparts(EPIimg(e,:));
            dEPIimg = [dEPIimg, fullfile(pth, ['d' nme ext])];
            
            movefile(sprintf('vol%04d.nii', e-1), dEPIimg{e})
            
            V = spm_vol(EPIimg(e,:));
            Y = spm_read_vols(V); % not denoised data...
            
            dY = spm_read_vols(spm_vol(dEPIimg{e}));
            
            M = M + abs(Y - dY);
            
            V.fname = dEPIimg{e};
            spm_write_vol(V, dY);
        end       
        V.fname = fullfile(pth, 'MELODIC_noise.nii');
        spm_write_vol(V, M);
        
        % Delete 4D file once we finish!
        unix(['rm ' data4D])
        
        %% DESCRIBE OUTPUTS!
        %{
        % MAKE A SEPARATE FUNCTION OF THIS SOMETIME?
        melodicFiles = [];
        fldrDir = genpath(outDir);
        % Then recurse inside each directory until you run out of paths
        while ~isempty(strtok(fldrDir, ':'))
            % Get each of the directories made by gendir
            [fldrCurr fldrDir] = strtok(fldrDir, ':');
            % Check it's not a .svn folder
            D = dir(fldrCurr);
            for d = 1:length(D)
                if ~D(d).isdir && isempty(strfind(D(d).name(1), '.'))
                    melodicFiles = strvcat(melodicFiles, fullfile(fldrCurr, D(d).name));
                else
                    % It is one of the . or .. folders
                end
            end
        end
        
        aap=aas_desc_outputs(aap,subj,sess,'melodic', melodicFiles);        
        %}
        % Delete MELODIC folder itself...
        unix(['rm -rf ' outDir])
        
        aap=aas_desc_outputs(aap,subj,sess,'epi', dEPIimg);
        
end