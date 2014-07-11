% AA module

function [aap,resp]=aamod_contrast2WTA(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';   % this module needs to be run once per subject
        
    case 'description'
        resp='Detect grid orientation from betas coding the sine and cosine';
        
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Grid orientation %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        % Get the SPM structure
        SPMfn = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        anadir = fileparts(SPMfn);
        SPM=load(SPMfn);
        SPM=SPM.SPM;
        
        % Error degrees of freedom
        df = SPM.xX.erdf;
        
        % Winner Takes All matrix
        WTA = 0;
        % Max T-val
        tvalWTA = 0;
        
        tvalY = cell( size(aap.tasklist.currenttask.settings.contrasts));
        
        % Go through each of the contrasts of interest
        for c = aap.tasklist.currenttask.settings.contrasts
            % And the T values corresponding to the contrast
            tvalV = spm_vol(fullfile(anadir, SPM.xCon(c).Vspm.fname));
            tvalY{c==aap.tasklist.currenttask.settings.contrasts} = spm_read_vols(tvalV);
            
            % Get the maximal t value...
            tvalWTA = max(tvalWTA, squeeze(tvalY{c==aap.tasklist.currenttask.settings.contrasts}));
            
            if strcmp('FDR', aap.tasklist.currenttask.settings.threshType)
                [P_thresh, P_thresh_strict] = FDR(1-tcdf(tvalY{c==aap.tasklist.currenttask.settings.contrasts}(:),df), aap.tasklist.currenttask.settings.threshVal);
                T_thresh = abs(tinv(P_thresh,df));
                if isempty(T_thresh)
                    T_thresh = Inf;
                end
            elseif strcmp('uncorr', aap.tasklist.currenttask.settings.threshType)
                T_thresh = abs(tinv(aap.tasklist.currenttask.settings.threshVal,df));
            end
            
            CtvalY = (tvalY{c==aap.tasklist.currenttask.settings.contrasts} >= T_thresh & tvalY{c==aap.tasklist.currenttask.settings.contrasts} >= tvalWTA);
            fprintf('Contrast %s contains %d active voxels\n', SPM.xCon(c).name, sum(CtvalY(:)))
            
            WTA = WTA + CtvalY .* find(aap.tasklist.currenttask.settings.contrasts==c);
        end
        
        V = tvalV;
        
        V.fname = fullfile(anadir, 'WTA.nii');
        spm_write_vol(V,WTA);
        
        WTAimg = V.fname;
        
        %% Now get the ROI and do the average direction & histogram...
        
        ROIimg = aas_findstream(aap,'rois', subj);
        
        if ~isempty(ROIimg)
            
            % Load the ROIs from which to extract the data
            ROIimg = aas_getfiles_bystream(aap,subj,'rois');
            ROI = cell(size(ROIimg,1));
            Rfn = cell(size(ROIimg,1));
            
            for r = 1:size(ROIimg,1)
                [Rpth Rfn{r} Rext] = fileparts(deblank(ROIimg(r,:)));
                
                % Need to extract betas from normalised brains for each: subject, ROI,
                % voxel, epoch, quadrant, subblock
                ROI{r} = int8(spm_read_vols(spm_vol(fullfile(Rpth, [Rfn{r} Rext]))));
                % Trick for non-binary ROIs...
                if length(unique(ROI{r}))>2
                    ROI{r} = ROI{r} > 0;
                end
                ROI{r} = logical(ROI{r});
                voxels = sum(ROI{r}(:));
                
                fprintf('\t ROI = %s; vox. = %d\n',Rfn{r}, voxels)
                
                rWTA = WTA;
                rWTA(~ROI{r}) = 0;
                
                V.fname = fullfile(anadir, ['WTA_' Rfn{r} '.nii']);
                spm_write_vol(V,rWTA);
                
                WTAimg = strvcat(WTAimg, V.fname);
                
                % And some line plots...
                tvalMat = nan(length(aap.tasklist.currenttask.settings.contrasts), ...
                    voxels);
                
                for c = 1:length(aap.tasklist.currenttask.settings.contrasts)
                    tvalMat(c,:) = tvalY{c}(ROI{r});
                end
            end
        end
        
        %% DIAGNOSTIC IMAGE
        
        mriname = aas_prepare_diagnostic(aap,subj);
        
        if ~isempty(ROIimg)
            % Display the pattern of voxel-wise T-values across the contrasts
            figure(2)
            set(2, 'Position', [0 0 1000 800])
            
            for r = 1:size(ROIimg,1)
                h = subplot(size(ROIimg,1), 1, r);
                plot(tvalMat, '-')
                
                set(gca, ...
                    'xtick', 1:length(aap.tasklist.currenttask.settings.contrasts), ...
                    'xticklabel', {SPM.xCon(aap.tasklist.currenttask.settings.contrasts).name})
                
                xlabel('Contrasts')
                ylabel('T-values')
                
            end
            
            figure(2)
            set(gcf,'PaperPositionMode','auto')
            print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '__' mriname '_timecourse.jpeg']));
        end
        
        %% DESCRIBE OUTPUTS!
        aas_desc_outputs(aap,subj,'WTA', WTAimg);
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
