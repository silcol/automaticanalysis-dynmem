% AA module
% [aap,resp]=aamod_tSNR_EPI(aap,task,subj,sess)
% Calculate the temporal SNR of a series of images within a particular ROI
% Also plots the timecourses...
% This is more accurate (but slower!) than the SNR calculation that is done
% during epi conversion, since it removes signal drift!

function [aap,resp]=aamod_tSNR_EPI(aap,task,subj,sess)

resp='';

switch task
    case 'doit'
        
        EPIimg = aas_getfiles_bystream(aap,subj,sess,'epi');
        if any(strcmp('rois',aap.tasklist.currenttask.inputstreams.stream))
            ROIimg = aas_getfiles_bystream(aap,subj,'rois');
        else
           ROIimg = ''; 
        end
        
        %% Get started with the processing
        % ROIvol{r}based measures
        mROI = cell(size(ROIimg,1),1);
        sROI = cell(size(ROIimg,1),1);
        SNmROI= cell(size(ROIimg,1),1);
        ROIname = cell(size(ROIimg,1),1);
        ROIvol = cell(size(ROIimg,1),1);
        
        % Voxel based measures
        V = spm_vol(deblank(EPIimg(1,:))); % A typical volume...
        EPIsignal = zeros(V(1).dim(1), V(1).dim(2), V(1).dim(3));
        EPInoise = zeros(V(1).dim(1), V(1).dim(2), V(1).dim(3));
        
        fprintf('\nWorking on session %s', aap.acq_details.sessions(sess).name)
        
        fprintf('\n\tLoading ROIs')
        for r = 1:size(ROIimg,1)
            [junk, ROIname{r}] = fileparts(ROIimg(r,:));
            
            % Now load each of the ROIs we wish to examine (usually using the grey matter)
            rV = spm_vol(ROIimg(r,:));
            ROIvol{r} = spm_read_vols(rV);
            ROIvol{r} = round(ROIvol{r});
            % Mean ROI value is a vector depending on number of scans
            mROI{r} = zeros(size(EPIimg,1),1);
            
            if any(size(ROIvol{r})~=size(EPIsignal))
                aas_log(aap, true, ['The dimensions of the EPI data and the ROI do not match\n' ...
                    'This is likely because you are using normalised EPIs, whereas you should use native ones'])
            end
        end
        
        %% If the dataset is too large, we process it by chunks...
        fprintf('\n\tProcessing data (%d scans)', size(EPIimg,1))
        
        taskComplete = 0;
        chunkDim = aap.tasklist.currenttask.settings.chunks;
        
        while taskComplete == 0
            fprintf('\nTrying with %d chunks', chunkDim)
            
            try
                chunkX = 0;
                chunkY = 0;
                chunkZ = 0;
                for c = 1:chunkDim
                    chunkX = [chunkX floor(V(1).dim(1) * c / chunkDim)];
                    chunkY = [chunkY floor(V(1).dim(2) * c / chunkDim)];
                    chunkZ = [chunkZ floor(V(1).dim(3) * c / chunkDim)];
                end
                
                % Chunking...
                for x = 1:length(chunkX) - 1
                    for y = 1:length(chunkY) - 1
                        for z = 1:length(chunkZ) - 1
                            fprintf('\n\t...chunk %d %d %d', x, y, z)
                            Xind = chunkX(x) + 1 : chunkX(x+1);
                            Yind = chunkY(y) + 1 : chunkY(y+1);
                            Zind = chunkZ(z) + 1 : chunkZ(z+1);
                            
                            EPIdata = zeros(size(EPIimg,1), length(Xind), ...
                                length(Yind), ...
                                length(Zind));
                            
                            % Load each image into 4-D matrix
                            V = spm_vol(EPIimg);
                            for e = 1:length(V)                        
                                Y = spm_read_vols(V(e));
                                EPIdata(e,:,:,:) = Y(Xind,Yind,Zind);
                                
                                %% We can do ROIvol{r} processing here...
                                if x == 1 && y == 1 && z == 1
                                    for r = 1:size(ROIimg,1)
                                        tmp = Y(ROIvol{r}>0);
                                        tmp = tmp(tmp>0); % We don't want to include zero values...
                                        mROI{r}(e,1) = mean(tmp(:)); % Mean per time point
                                        sROI{r}(e,1) = std(tmp(:))./sqrt(length(tmp(:))); % Standard error per time point
                                    end
                                end
                            end
                            
                            % Calcultate signal as mean of the data across volumes
                            EPIsignal(Xind,Yind,Zind) = squeeze(mean(EPIdata, 1));
                            % Calculate noise as standard deviation across volumes
                            EPInoise(Xind,Yind,Zind) = squeeze(std(EPIdata, [], 1));
                        end
                    end
                end
                % If we get here, then we completed the task...
                taskComplete = 1;
            catch aa_error
                %disp(tSNR_error)
                
                if chunkDim > 4
                    error('Error is probably not due to MEMORY')
                end
                
                chunkDim = chunkDim + 1;
            end
        end
        clear EPIdata
        
        fprintf('\n\tCalculating & saving the tSNR image')
        % Calculate SNR as ratio of the two...
        EPIsnr = zeros(size(EPIsignal));
        EPIsnr(EPIsignal ~= 0) = EPIsignal(EPIsignal ~= 0) ./ EPInoise(EPIsignal ~= 0);
        EPIsnr(isnan(EPIsnr)|isinf(EPIsnr)) = 0;
        
        % Save the SNR image!
        sV = V(1);
        sV.fname = fullfile(aas_getsesspath(aap,subj,sess), ...
            ['tSNR_' aap.acq_details.sessions(sess).name '.nii']);
        spm_write_vol(sV, EPIsnr);
        
        if ~isempty(ROIimg)
            fprintf('\n\tFinalising ROI data')

            for r = 1:size(ROIimg,1)
                % Get a whole ROI signal and noise estimate
                SNmROI{r} = mean(mROI{r}) ./ std(mROI{r});
            end
            
            %% DIAGNOSTIC IMAGE
            mriname = aas_prepare_diagnostic(aap,subj);
            
            %% tSNR results figure!
            fprintf('\nDisplaying the results of the tSNR analysis')
            
            legendExtra = cell(1,length(ROIname));
            for r = 1:length(ROIname)
                legendExtra{r} = sprintf(' ROI=%.2f', SNmROI{r});
            end
            
            roi2hist(sV.fname, ROIimg, [], legendExtra)
                                    
            title(sprintf('\nSNR for session %s, using %.0f scans', ...
                regexprep(aap.acq_details.sessions(sess).name, '[^a-zA-Z0-9]', ''), ...
                size(EPIimg,1)))
            
            saveas(2, fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_tSNR.fig']), 'fig');
            
            %% Time-course results figure!            
            fprintf('\nDisplaying the results of the timecourse analysis')
            colorsB = aas_colours;
            
            try close(2); catch; end
            figure(2)
            set(2, 'Position', [0 0 1200 700])
            
            legStr = 'legend(';
            
            for r = 1:size(ROIimg,1)
                %subplot(size(ROIimg,1),1,r)
                hold on
                
                % We need to make a string for eval, that will print the legend...
                legStr = [legStr 'sprintf(''%s (%.0fv)'', ' ...
                    'ROIname{' num2str(r) '}, ' ...
                    'sum(ROIvol{' num2str(r) '}(:))),'];
                
                % Plot main results (errorbars displayed differently now...)
                plot(mROI{r}, '.', 'Color',  colorsB{r})
            end
            legStr = [legStr(1:end-1) ');'];
            eval(legStr);
            
            for r = 1:size(ROIimg,1)
                plot(mROI{r} - sROI{r}, '--k')
                plot(mROI{r} + sROI{r}, '--k')
            end
            
            xlim([0 length(V)])
            %ylim([mean(mROI{r} - 2*mean(sROI{r})) mean(mROI{r} + 2*mean(sROI{r}))])
            xlabel('Scan')
            ylabel('Mean signal')
            set(gca,'XTick', 0:ceil(size(EPIimg,1)./25):size(EPIimg,1))
            title(sprintf('\nTimecourse for session %s, using %.0f scans', ...
                regexprep(aap.acq_details.sessions(sess).name, '[^a-zA-Z0-9]', ''), ...
                size(EPIimg,1)))
            
            saveas(2,fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_timecourse.fig']), 'fig');
            
            %% Diagnostic VIDEO
            if aap.tasklist.currenttask.settings.diagnostic && sess == aap.acq_details.selected_sessions(1)
                
                aas_image_avi(sV.fname, ...
                    ROIimg, ...
                    fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '.avi']), ...
                    2, ... % Axis
                    [800 600], ...
                    1); % Rotations
                try close(2); catch; end
            end
        end
        
        %% DESCRIBE OUTPUTS
        
        aap=aas_desc_outputs(aap,subj,sess,'tSNR',sV.fname);
end
