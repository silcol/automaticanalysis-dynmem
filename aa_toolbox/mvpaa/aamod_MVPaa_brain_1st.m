% AA module - MVPaa 1st level (Searchlight based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_MVPaa_brain_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        %% PLAN
        % A) Much better way of specifying masks! Maskstreams, manually selected...
        
        %% PREPARATIONS...
        aap.subj = subj;
        mriname = aas_prepare_diagnostic(aap);
        mvpaa_diagnosticParameters(aap)
        
        fprintf('Working with MVPaa_data from participant %s. \n', mriname)
        
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
                Statistics = NaN(brainSize(1), brainSize(2), brainSize(3), ...
                    length(aap.tasklist.currenttask.settings.contrasts), ...
                    length(aap.tasklist.currenttask.settings.tests));
            case {'lsqcurvefit'}
                Statistics = NaN(brainSize(1), brainSize(2), brainSize(3), ...
                    length(aap.tasklist.currenttask.settings.lsqcurvefitUB), ...
                    length(aap.tasklist.currenttask.settings.tests));
            otherwise
                aas_log(aap, 1, 'Unknown type of statistics!')
        end
       
        sumSimilarity = 0;
        
        % Only use locations where there is data...
        if isempty(segMask)
            segMask = squeeze(MVPaa_obj.MVPaa_data(1, :,:,:));      
            segMask = ~isfinite(segMask) | segMask == 0;
        end
        
        brainLimit = matrixLimits(~segMask, ...
                aap.tasklist.currenttask.settings.ROIradius);
       
        chunkSplit = zeros(chunkDim + 1, 3);
        for c = 0:chunkDim
            for d = 1:3
                chunkSplit(c + 1, d) = ...
                floor((brainLimit{d}(2) - brainLimit{d}(1) + 1) * c / chunkDim) + brainLimit{d}(1) - 1;
            end
        end
        
        chunks = {};
        chunks2run = [];
        chunkName = {};
        
        indx = 0;
        % Chunking...
        for x = 1:size(chunkSplit,1) - 1
            for y = 1:size(chunkSplit,1) - 1
                for z = 1:size(chunkSplit,1) - 1
                    tmpC = {...
                        chunkSplit(x,1) + 1 : chunkSplit(x+1,1), ...
                        chunkSplit(y,2) + 1 : chunkSplit(y+1,2), ...
                        chunkSplit(z,3) + 1 : chunkSplit(z+1,3)};
                    tmpM = segMask(tmpC{1}, tmpC{2}, tmpC{3});
                    
                    if any(tmpM(:)==0)
                        indx = indx+1;
                        chunkName{indx} = fullfile(aas_getsubjpath(aap,subj), ...
                            sprintf('chunk_%d_%d_%d.mat', tmpC{1}(1), tmpC{2}(1), tmpC{3}(1)));
                        chunks{indx} = tmpC;
                        if  ~exist(chunkName{indx},'file')
                            chunks2run = [chunks2run, indx];
                        end
                    end
                end
            end
        end
        
        Statistics_cell = cell(length(chunks), 1);
        fprintf('\nSplit data into %d (%d) chunks\n', length(chunks), length(chunks2run));
        switch aap.tasklist.currenttask.settings.parallelisation
            case 'serial'
                % Linear way of doing things...
                for c = chunks2run;
                    fprintf('\nWorking on chunk %d/%d\n', c, length(chunks2run));
                    mvpaa_brain_1st(aap, MVPaa_obj, chunks{c}, chunkName{c}, segMask);
                end
            case 'torque'
                cell_aap = cell(length(chunks2run), 1);
                cell_MVPaa_obj = cell(length(chunks2run), 1);
                cell_segMask = cell(length(chunks2run), 1);
                for c = 1:length(chunks2run);
                    cell_aap{c} = aap;
                    cell_MVPaa_obj{c} = MVPaa_obj;
                    cell_segMask{c} = segMask;
                end
                
                chunkLength = [length(chunks{1}{1}), length(chunks{1}{2}), length(chunks{1}{3})] + ROIradius*2;
                memReq = 48 * regNum * prod(chunkLength) + ... % For data
                    48 * regNum.^2; % For similarity matrices
                timReq = 23*60*60;
                fprintf('Each job is given %0.0f MB and (at most) %02d:%02d:%02d \n', ...
                    memReq/1024^2, floor(timReq/60^2), floor(mod(timReq/60, 60)), floor(mod(timReq, 60)));
                
                qsubcellfun(@mvpaa_brain_1st, ...
                cell_aap, cell_MVPaa_obj, chunks(chunks2run), chunkName(chunks2run), cell_segMask, ...
                'memreq', int64(memReq), ... % Representative chunk size
                'timreq', int64(timReq)); % Time!
            otherwise
                aas_log(aap, true, 'No such parallelisation option!')
        end
        
        % Assign results to macro-structure
        for c = 1:length(chunks);
            chunkData = load(chunkName{c});
            Statistics(chunks{c}{1}, chunks{c}{2}, chunks{c}{3}, :, :) = ...
                reshape(chunkData.Statistics, [length(chunks{c}{1}), length(chunks{c}{2}), length(chunks{c}{3}), size(Statistics,4), size(Statistics,5)]);
            sumSimilarity = sumSimilarity + chunkData.sumSimilarity;
        end
        %Reshape macro-structure
        Statistics = reshape(Statistics, [brainSize(1)*brainSize(2)*brainSize(3), size(Statistics,4), size(Statistics,5)]);
        
        % DIAGNOSTIC DISPLAY OF T-VALUES FOR EACH CON
        %try mvpaa_diagnosticSearchlight(aap, Statistics); catch; end
        
        %% DESCRIBE OUTPUTS
        MVPaa_settings = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'), '-v7.3', ...
            'Statistics', 'MVPaa_settings', 'sumSimilarity')
        aap=aas_desc_outputs(aap,subj,'MVPaa_1st', fullfile(aas_getsubjpath(aap,subj), 'MVPaa_1st.mat'));
        
        unix(['rm ' fullfile(aas_getsubjpath(aap,subj), 'chunk_*.mat')])
end