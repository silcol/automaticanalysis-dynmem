% AA module - structural overlay
% This module can be done after aamod_norm_noss
% It provides an overlap image of the structural and the segmentations in
% the template space, as well as some diagnostic statistics of the overlap
% of each compartment....
function [aap,resp] = aamod_structural_overlay(aap,task)

resp = '';

switch task
    case 'doit'
        
        %% CREATE SOME DIAGNOSTIC IMAGES OF NORMALISATION + STATS...
        
        % Load all the segmented and normalised images
        for subj = 1:length(aap.acq_details.subjects)
            Simg = aas_getfiles_bystream(aap,subj,'structural');        
            SEGimg = aas_getfiles_bystream(aap,subj,'segmentation');
            
            % Cheap and cheerful way of ensuring only one file is considered!
            if size(Simg,1) > 1
                for a = 1:size(Simg,1)
                    [junk, fn] = fileparts(Simg(a,:));
                    % Warped!
                    if strcmp(fn(1), 'w')
                        Simg = deblank(Simg(a,:));
                        break
                    end
                end
                fprintf('\tSeveral structurals found, considering: %s\n', Simg)
            end
            
            % Cheap and cheerful way of ensuring only warped segmentations are considered!
            for a = size(SEGimg,1):-1:1
                [junk, fn] = fileparts(SEGimg(a,:));
                % Ifnored unwarped!
                if ~strcmp(fn(1), 'w')
                    SEGimg(a,:) = [];
                end
            end           
            
            % Prepare structural overlays
            if subj == 1
                structOverlay = cell(1, size(SEGimg,1)+1);
                histOverlay = cell(2, size(SEGimg,1)+1);
                histOverlayA = cell(2, 1);
                segmentNames = cell(1, size(SEGimg,1));
                
                for sess = 1:length(structOverlay)
                    structOverlay{sess} = 0;
                end
            end
            
            % First get structural...
            sV = spm_vol(Simg);
            structOverlay{1} = structOverlay{1} + spm_read_vols(sV);
            
            % Then get segmentations...
            for sess = 1:size(SEGimg,1)
                % Get common name bits...
                [junk, fn] = fileparts(SEGimg(sess,:));
                if subj == 1
                    segmentNames{sess} = fn;
                else
                    % Loop through the common bit of the name and select
                    booName = 0;
                    while booName == 0
                        if strcmp(segmentNames{sess}, fn(1:length(segmentNames{sess})))
                            booName = 1;
                        else
                            segmentNames{sess} = segmentNames{sess}(1:end-1);
                        end
                    end
                end
                
                
                V = spm_vol(SEGimg(sess,:));
                structOverlay{sess+1} = structOverlay{sess+1} + spm_read_vols(V);
            end
        end
        
        sV.fname = fullfile(aap.acq_details.root, 'T1_structOverlay.nii');
        spm_write_vol(sV, structOverlay{1}./length(aap.acq_details.subjects));
        
        outstream = sV.fname;
        
        for sess = 1:size(SEGimg,1)
            V.fname = fullfile(aap.acq_details.root, [segmentNames{sess} '_structOverlay.nii']);
            spm_write_vol(V, structOverlay{sess+1}./length(aap.acq_details.subjects));
            
            outstream = strvcat(outstream, V.fname);
            
            %% Do some stats (maintly histograms of overlap...)
            histOverlay{1,sess} = hist(structOverlay{1,sess}(structOverlay{1,sess}>0), ...
                1:length(aap.acq_details.subjects));
            % Normalise the histograms
            histOverlay{1,sess} = histOverlay{1,sess}./sum(histOverlay{1,sess});    
            
            histOverlayA{1} = [histOverlayA{1} histOverlay{1,sess}'];
                
            %% Also do an alternative measure...
            histOverlay{2,sess} = histOverlay{1,sess}.*(1:length(aap.acq_details.subjects));
            % Normalise the histograms
            histOverlay{2,sess} = histOverlay{2,sess}./sum(histOverlay{2,sess});
            
            histOverlayA{2} = [histOverlayA{2} histOverlay{2,sess}'];
            
        end
        
        % Plot them
        try close(2), catch, end
        figure(2)
        set(2, 'Position', [0 0 1200 600])
        
        subplot(1,2,1)
        bar(histOverlayA{1})
        xlabel('Participants overlapping')
        ylabel('Proportion of voxels')
        legend(segmentNames)
        title('Proportion of voxels in image showing overlap between subjects'' segmented maps')
        set(gca,'XTick',0:length(aap.acq_details.subjects))
        
        subplot(1,2,2)
        bar(histOverlayA{2})
        xlabel('Participants overlapping')
        ylabel('Proportion of voxels')
        legend(segmentNames)
        title('Proportion of voxels in ROI showing overlap betweeen subjects'' segmented maps')
        set(gca,'XTick',0:length(aap.acq_details.subjects))
        
        %% DIAGNOSTIC IMAGE
        mriname = aas_prepare_diagnostic(aap,subj);
                
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '.jpeg']));
        
        %% Diagnostic VIDEO
        if aap.tasklist.currenttask.settings.diagnostic
            segImg = {};
            for seg = 1:size(SEGimg,1)
                segImg = [segImg deblank(outstream(1+seg, :))];
            end
            
            aas_image_avi(segImg, ...
                [], ...
                fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '.avi']), ...
                2, ... % Axis
                [1000 350], ...
                2); % Rotations
            try close(2); catch; end
        end
        
        %% DESCRIBE OUTPUTS
        aap=aas_desc_outputs(aap,'overlap_structural',outstream);
        
end