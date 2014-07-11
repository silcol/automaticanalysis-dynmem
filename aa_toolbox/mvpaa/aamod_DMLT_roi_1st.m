% AA module - MVPaa 1st level (ROI based)
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_DMLT_roi_1st(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        %% PREPARATIONS
        warning off
        % Add toolbox path...
        addpath(genpath(aap.directory_conventions.DMLTdir));
        
        mriname = aas_prepare_diagnostic(aap,subj);
        fprintf('Working with data from participant %s. \n', mriname)
                
        %% ANALYSIS
        
        % Load the data into a single big structure...
        [aap, data] = mvpaa_loadData(aap, subj);
        
        % Load the ROIs from which to extract the data
        try
            ROIimg = aas_getfiles_bystream(aap,subj,'rois');
        catch
            % Whole brain?
            ROIimg = aas_getfiles_bystream(aap,subj,'segmasksStrict');
            ROIimg = ROIimg(1,:); % @@@@ [DEBUG] @@@@
        end
        
        ROInum = size(ROIimg,1);
        
        ROIname = {};
        
        % Get the contrasts for this subject...
        DMLT = mvpaa_loadDMLT(aap,subj);
        
        DMLout = cell(ROInum, length(DMLT));
        
        % Loop the routine over all ROIs
        for r = 1:ROInum
            [Rpth Rfn Rext] = fileparts(deblank(ROIimg(r,:)));
            ROIname = [ROIname Rfn];
            
            % Extract betas from each: ROI, voxel, condition, subblock, session
            ROI = uint8(spm_read_vols(spm_vol(fullfile(Rpth, [Rfn Rext]))));
            
            % Check that the ROI size is equal to the data size
            if any(size(ROI) ~= size(data{1,1,1}));
                aas_log(aap, true, 'Your ROI size is different from your data size!');
            end
            
            % Trick for non-binary ROIs...
            if length(unique(ROI))>2
                ROI = ROI > 0;
            end
            voxels = sum(ROI(:));
            
            % Get rid of NaNs in data...
            ROI = and(ROI, ~isnan(data{1,1,1}));
            voxelsReal = sum(ROI(:));
            
            % ROI to linear index...
            ROI = find(ROI);
            
            Betas = mvpaa_extraction(aap, data, ROI);
            
            fprintf('\t ROI = %s; vox. = %d (%d)\n',Rfn, voxelsReal, voxels)
            
            if isempty(Betas)
                aas_log(aap, false, sprintf('Not enough voxels in ROI, minimum is %i, you have %i', ...
                    aap.tasklist.currenttask.settings.minVoxels, voxelsReal));
                continue
            end
            
            for c = 1:length(DMLT)
                % Get the DMLT object...
                DMLTtemp = DMLT(c);
                
                Y = reshape( ...
                    repmat(DMLTtemp.vector(:), [1 aap.tasklist.currenttask.settings.blocks]), ...
                    [1, length(DMLTtemp.vector(:))*aap.tasklist.currenttask.settings.blocks])';
                
                X = reshape(Betas, [size(Betas,1) size(Betas,2)*size(Betas,3)])';
                
                % Remove NaNs
                X = X(~isnan(Y), :);
                Y = Y(~isnan(Y), :);
                
                % If we input it as a string to make it work in aa qsub...
                if ischar(DMLTtemp.object)
                    DMLTtemp.object = eval(DMLTtemp.object);
                end
                
                % The crucial line that calls the DMLT object train method
                DMLTtemp.object = DMLTtemp.object.train(X,Y);
                
                % Ideally, the DMLT method you use should already include
                % crossvalidation, etc...
                DMLTtemp.accuracy = DMLTtemp.object.statistic('accuracy') ...
                    - mean(Y == mode(Y)); % Correct for most common class!
                
                fprintf('\tAccuracy for contrast %s is :%0.3f\n', DMLTtemp.name, DMLTtemp.accuracy);
                
                % Now get the weights for the classifier
                W = 0;
                for w = 1:length(DMLTtemp.object.model)
                    if isfield(DMLTtemp.object.model{w}, 'weights')
                        W = W + DMLTtemp.object.model{w}.weights;
                    elseif isfield(DMLTtemp.object.model{w}, 'primal')
                        W = W + DMLTtemp.object.model{w}.primal;
                    elseif isfield(DMLTtemp.object.model{w}, 'importance')
                        W = W + DMLTtemp.object.model{w}.importance;
                    elseif isfield(DMLTtemp.object.model{w}, 'divergence')
                        W = W + DMLTtemp.object.model{w}.divergence;
                    elseif isfield(DMLTtemp.object.model{w}, 'template')
                        W = W + mean(DMLTobject.model{1}.template);
                    else
                        aas_log(aap, true, 'Cannot find feature weights...')
                    end
                end
                W = W./length(DMLTtemp.object.model);
                DMLTtemp.weights = nan(size(data{1}));
                DMLTtemp.weights(ROI) = W;
                
                DMLout{r,c} = DMLTtemp;
                DMLout{r,c}.object.mva = [];
            end
        end
        aap.tasklist.currenttask.settings.ROIname = ROIname;
        
        %% DESCRIBE OUTPUTS
        EP = aap.tasklist.currenttask.settings;
        save(fullfile(aas_getsubjpath(aap,subj), 'DMLT.mat'), ...
            'DMLout', 'EP', 'DMLT')
        aap=aas_desc_outputs(aap,subj,'DMLT', fullfile(aas_getsubjpath(aap,subj), 'DMLT.mat'));
end