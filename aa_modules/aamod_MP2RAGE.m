% AA module
% Runs BET (FSL Brain Extration Toolbox) on structural (usually)
% [For best functionality, it is recommended you run this after
% realignment and before writing the normalised EPI image
% If you do it before estimating the normalisation, make sure you normalise
% to a scull-stripped template, if at all possible!]

function [aap,resp]=aamod_MP2RAGE(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        mriname = aas_prepare_diagnostic(aap,subj);
        
        % Get the headers & images...
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        
        %% Select the images, according to the .xml specifications
        % Each of our 2 images contains important information...
        % - IC2 is good for masking the FI regions containing noise...
        % - FI contains strong contrast between GM and CSF
        % (might also be good for masking regions where IC2 contains CSF)
        IC2img = deblank(Simg(aap.tasklist.currenttask.settings.structural(1), :));
        FIimg = deblank(Simg(aap.tasklist.currenttask.settings.structural(2),:));
        
        % Load the images
        vIC2 = spm_vol(IC2img);
        yIC2 = spm_read_vols(vIC2);
        vFI = spm_vol(FIimg);
        yFI = spm_read_vols(vFI);
        
        
        IC2thresh = aap.tasklist.currenttask.settings.threshold;
        if isempty(IC2thresh)
            % Create a histogram of IC2
            limsIC2 = [min(yIC2(:)) max(yIC2(:))];
            binsIC2 = limsIC2(1):1:limsIC2(2);
            histIC2 = hist(yIC2(yIC2>0), binsIC2);
            
            % Find the noise peak and the signal peak
            [pks locs] = findpeaks(histIC2,'npeaks',2, 'minpeakdistance', ...
                round((max(yIC2(:)) - min(yIC2(:)))./25));
            
            % Get rounded values of IC2 and FI at each voxel...
            yIC2 = round(yIC2);
            yFI = round(yFI);
            
            % For each voxel where FI is a value "b", what is:
            % 1) the mean value of FI?
            % 2) the standard deviation of FI?
            meanFI = nan(1,locs(2));
            stdFI = nan(1,locs(2));
            for b = locs(1):locs(2)
                meanFI(b) = mean(yFI(yIC2==b));
                stdFI(b) = std(yFI(yIC2==b));
            end
            
            % The "location" in IC2 with highest FI value is threshold...
            IC2thresh = find(meanFI==max(meanFI));
            
            % DIAGNOSTIC IMAGE
            try close(3); catch; end
            figure(3)
            hold on
            plot(meanFI, 'r')
            plot(stdFI, 'g')
            line([IC2thresh IC2thresh], [0 max(meanFI)], 'Color', 'k')
            legend({'Mean FI signal', 'STD FI signal', sprintf('Threshold at %d', IC2thresh)})
            xlabel('Voxels containing N signal in IC2')
            ylabel('Corresponding signal in FI voxels')
            
            set(gcf,'PaperPositionMode','auto')
            saveas(3,fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_thresh.fig']), 'fig');
        end
        
        fprintf('Cutoff of IC2 is at %0.2f\n', IC2thresh)
        
        if strcmp(aap.tasklist.currenttask.settings.mode, 'sharp')
            % Then we can mask the IC2 and FI image...
            yIC2(yIC2<(IC2thresh)) = 0;
            yFI(yIC2<(IC2thresh)) = 0;
            
            spm_write_vol(vIC2, yIC2);
        elseif strcmp(aap.tasklist.currenttask.settings.mode, 'soft')
            yIC2 = yIC2 ./ max(yIC2(:)); % Reset values in IC2 between 0 and 1
            
            % Scale values in yFI where yFI is not brain
            yFI(yIC2<(IC2thresh)) = yFI(yIC2<(IC2thresh)) .* yIC2(yIC2<(IC2thresh));            
        end
        spm_write_vol(vFI, yFI);
        
        %% DESCRIBE OUTPUTS!
        aap=aas_desc_outputs(aap,subj,'structural',Simg);
        
        %% DIAGNOSTIC IMAGE (structural)
        spm_check_registration(FIimg)
        
        spm_orthviews('reposition', [0 0 0])
        
        try figure(spm_figure('FindWin', 'Graphics')); catch; figure(1); end;
        set(gcf,'PaperPositionMode','auto')
        saveas(1, fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.fig']), 'fig');
        
        %% Diagnostic VIDEO of masks
        if aap.tasklist.currenttask.settings.diagnostic
            
            Ydims = {'X', 'Y', 'Z'};
            for d = 1:length(Ydims)
                aas_image_avi( FIimg, ...
                    [], ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_' Ydims{d} '.avi']), ...
                    d, ... % Axis
                    [800 600], ...
                    2); % Rotations
            end
            try close(2); catch; end
        end
end