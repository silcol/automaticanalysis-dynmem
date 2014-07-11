% AA module - MVPaa 1st level (ROI based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011
% AA module - MVPaa 1st level (Searchlight based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_MVPaa_roi_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        %% PLAN
        % A) Much better way of specifying masks! Maskstreams, manually selected...
        
        %%TEMP
        addpath(genpath('~/memspa-code'))
        
        %% PREPARATIONS...
        aap.subj = subj;
        mriname = aas_prepare_diagnostic(aap);
        mvpaa_diagnosticParameters(aap)
        
        fprintf('Working with MVPaa_data from participant %s. \n', mriname)
        
        %% Load the ROIs from which to extract the data
        ROIimg = aas_getfiles_bystream(aap,subj,'rois');
        ROInum = size(ROIimg,1);
        
        %% GET CONTRASTS
        aap = mvpaa_loadContrasts(aap);
        
        %% GET SETTINGS
        MVPaa_settings = [];
        load(aas_getfiles_bystream(aap, subj, 'MVPaa_settings'));
        % Settings are vectors indexing each fMRI image on:
        % condition, block, session (and the number of observations...)
        aap.tasklist.currenttask.settings.conditionNum = MVPaa_settings.conditionNum;
        aap.tasklist.currenttask.settings.blockNum = MVPaa_settings.blockNum;
        aap.tasklist.currenttask.settings.sessionNum = MVPaa_settings.sessionNum;
        
        %% DATA STRUCTURING...
        % Spike nulling of volumes that contain spikes (if working with raw data!)!
        aap.tasklist.currenttask.settings.spikeNulling = mvpaa_spikeNulling_prepare(aap);
        
        % Label the similarity matrix according to condition, block, session comparisons
        % This "structures" similarity data to allow us to test hypotheses on observation similiarity values
        aap = mvpaa_structureSimilarity(aap);
        % Structure the contrast matrices based on the above
        aap = mvpaa_structureContrasts(aap);
        
        %% DENOISING
        % Motion denoising for similarity data cleanup!
        aap.tasklist.currenttask.settings.motionDenoising = mvpaa_motionDenoising_prepare(aap);
        % Temporal denoising for similarity data cleanup!
        aap.tasklist.currenttask.settings.temporalDenoising = mvpaa_temporalDenoising_prepare(aap);
                
        %% GET MASK
        segMask = mvpaa_getMask(aap);
        
        %% GET fMRI DATA & CHUNK IT
        MVPaa_obj = matfile(aas_getfiles_bystream(aap, subj, 'MVPaa_data'));
        
        chunkDim = aap.tasklist.currenttask.settings.chunking;
        brainSize = size(MVPaa_obj,'MVPaa_data'); regNum = brainSize(1); brainSize(1) = [];
        ROIradius = aap.tasklist.currenttask.settings.ROIradius;
        
        aap.tasklist.currenttask.settings.brainSize = brainSize;
        
        % Create output arrays...
        switch aap.tasklist.currenttask.settings.statsType
            case {'GLM', 'fullGLM', 'ranksum'}
                Statistics = NaN(ROInum, ...
                    length(aap.tasklist.currenttask.settings.contrasts), ...
                    length(aap.tasklist.currenttask.settings.tests));
            case {'lsqcurvefit'}
                Statistics = NaN(ROInum, ...
                    length(aap.tasklist.currenttask.settings.lsqcurvefitUB), ...
                    length(aap.tasklist.currenttask.settings.tests));
            otherwise
                aas_log(aap, 1, 'Unknown type of statistics!')
        end
        
        sumSimilarity = 0;
        
        % Only use locations where there is data...
        if isempty(segMask)
            segMask = squeeze(MVPaa_obj.MVPaa_data(1, :,:,:));
            segMask = ~isfinite(segMask) || segMask == 0;
        end
        
        brainLimit = matrixLimits(~segMask, 0);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Decide how much of the data to load...
        brainSize = aap.tasklist.currenttask.settings.brainSize;
        ROIradius = aap.tasklist.currenttask.settings.ROIradius;
        
        %% GET fMRI DATA & MASK IT
        MVPaa_data = MVPaa_obj.MVPaa_data(:, ...
            brainLimit{1}(1):brainLimit{1}(2), ...
            brainLimit{2}(1):brainLimit{2}(2), ...
            brainLimit{3}(1):brainLimit{3}(2));
        
        % MASK DATA (using segmentation masks, for instance...)
        [MVPaa_data, dataMask] = mvpaa_maskData(MVPaa_data, segMask(brainLimit{1}(1):brainLimit{1}(2), ...
            brainLimit{2}(1):brainLimit{2}(2), ...
            brainLimit{3}(1):brainLimit{3}(2)));
                
        % Create output arrays...
        switch aap.tasklist.currenttask.settings.statsType
            case {'GLM', 'fullGLM', 'ranksum'}
                Statistics = NaN(ROInum, ...
                    length(aap.tasklist.currenttask.settings.contrasts), ...
                    length(aap.tasklist.currenttask.settings.tests));
            case {'lsqcurvefit'}
                Statistics = NaN(ROInum, ...
                    length(aap.tasklist.currenttask.settings.lsqcurvefitUB), ...
                    length(aap.tasklist.currenttask.settings.tests));
            otherwise
                aas_log(aap, 1, 'Unknown type of statistics!')
        end
        
        ROIname = {};
        for r = 1:ROInum
            [Rpth Rfn Rext] = fileparts(deblank(ROIimg(r,:)));
            ROIname = [ROIname Rfn];
            
            % Extract betas from each: ROI, voxel, condition, subblock, session
            ROI = uint8(spm_read_vols(spm_vol(fullfile(Rpth, [Rfn Rext]))));
            
            % Check that the ROI size is equal to the data size
            if any(size(ROI) ~= size(segMask));
                aas_log(aap, true, 'Your ROI size is different from your data size!');
            end
            
            ROI = ROI(brainLimit{1}(1):brainLimit{1}(2), ...
            brainLimit{2}(1):brainLimit{2}(2), ...
            brainLimit{3}(1):brainLimit{3}(2));
            
            % Trick for non-binary ROIs...
            if length(unique(ROI))>2
                ROI = ROI > 0;
            end
            voxels = sum(ROI(:));
            
            % ROI to linear index...
            indROI = find(ROI);
            
            indROI(dataMask(indROI)==1) = [];
            voxels = length(indROI);
            
            % Check that it's worth to extract data
            if voxels > aap.tasklist.currenttask.settings.minVoxels
                % Get all betas quickly
                Pattern = MVPaa_data(:,indROI);
            else
                continue
            end
            
            % Compute similarities of the the MVPaa_data
            Similarity = mvpaa_similarity(aap, Pattern);
            
            % DENOISING
            % Remove effects related to subject motion (if info available)
            Similarity = mvpaa_Denoising(Similarity, ...
                aap.tasklist.currenttask.settings.motionDenoising);
            
            % Remove effects related to temporal proximity... (if temp. info available)
            Similarity = mvpaa_Denoising(Similarity, ...
                aap.tasklist.currenttask.settings.temporalDenoising);
            
            % Get statistics for similarity values
            Statistics(r,:,:) = mvpaa_statistics(aap, Similarity);
        end
        
        %% DESCRIBE OUTPUTS
        MVPaa_settings = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'), '-v7.3', ...
            'Statistics', 'MVPaa_settings')
        aap=aas_desc_outputs(aap,subj,'MVPaa_1st', fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'));
end