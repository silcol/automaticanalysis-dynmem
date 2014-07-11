% AA module
% Runs MVPA classification using the Donders Machine Learning Toolbox
% by Dr Marcel van Gerven
% Cognitive Artificial Intelligence, Room B.02.04
% Donders Institute for Brain, Cognition and Behaviour
% Tel: +31 (0) 24 3615606
% m.vangerven@donders.ru.nl
%
% This is WORK IN PROGRESS and thus UNFINISHED!

function [aap,resp]=aamod_decodeDMLT(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';  % this module needs to be run once per subject
        
    case 'description'
        resp='SPM5 align';
        
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        
        %% PLAN
        % @@@ Implement the masking of data using any other masks we can
        % find? @@@
        
        %% IN PROGRESS
        
        subjDir = aas_getsubjpath(aap,subj);
                
        % Classification labels
        % Name of subject...
        subjname = aap.acq_details.subjects(subj).mriname;
        % Get model data from aap
        subjmatches=strcmp(subjname,{aap.tasklist.currenttask.settings.model.subject});
        % If no exact spec found, try subject wildcard
        if (~any(subjmatches))
            subjwild=strcmp('*',{aap.tasklist.currenttask.settings.model.subject});
            if any(subjwild)
                subjmatches = subjwild;
            end
        end
        %% Should now have just one model spec
        modelnum=find(subjmatches);
        if (length(modelnum)>1)
            aas_log(aap,true,sprintf('Error while getting MVPaa contrast details as more than one specification for subject %s',subjname));
        end
        if (isempty(modelnum))
            aas_log(aap,true,'Cannot find MVPaa contrasts specification. Check either user script');
        end
        
        %% 1: Select the relevant DMLT object and classification labels
        DMLT = aap.tasklist.currenttask.settings.model(modelnum).DMLT;        
        
        %% 1: Get the data - either beta images, contrast images or raw EPIs!
        Bimg = [];
        for Sind=1:length(aap.tasklist.currenttask.inputstreams.stream)
            if ~isempty(strfind(aap.tasklist.currenttask.inputstreams.stream{Sind}, 'cons')) || ...
                    ~isempty(strfind(aap.tasklist.currenttask.inputstreams.stream{Sind}, 'betas')) || ...
                    ~isempty(strfind(aap.tasklist.currenttask.inputstreams.stream{Sind}, 'epi'))
                Bimg = aas_getfiles_bystream(aap,subj,aap.tasklist.currenttask.inputstreams.stream{Sind});
            end
        end
        
        Bnum = size(Bimg,1);
        data = cell(Bnum,1);
        for b = 1:Bnum
            data{b} = spm_read_vols(spm_vol(deblank(Bimg(b,:))));
        end
        
        %% 2: Get the ROIs from which we extract the voxels, etc.
        ROIimg = aas_getfiles_bystream(aap,subj,'rois');
        ROInum = size(ROIimg,1);
        
        % Loop the entire routine over all ROIs
        for r = 1:ROInum
            [Rpth Rfn Rext] = fileparts(deblank(ROIimg(r,:)));
            
            ROI = int8(spm_read_vols(spm_vol(fullfile(Rpth, [Rfn Rext]))));
            
            % Check that the ROI size is equal to the data size
            if any(size(ROI) ~= size(data{1}));
                aas_log(aap, true, 'Your ROI size is different from your data size!');
            end
            
            % Trick for non-binary ROIs...
            if length(unique(ROI))>2
                ROI = ROI > 0;
            end
            voxels = sum(ROI(:));
            
            % ROI to linear index...
            ROI = find(ROI);
            
            % Our "trials" x voxels matrix
            X = nan(Bnum, voxels);
            
            % Get the relevant voxels from the ROI
            for b = 1:Bnum
                X(b,:) = data{b}(ROI);
            end
            
            %% 3: TRAIN/CLASSIFY/WEIGHTS!
            
            for c = 1:length(DMLT)
                
                % X = trials x voxels
                % Y = trails x 1 [column vector of conditions]

                Y = DMLT(c).vector;
                
                % The crucial line that calls the DMLTobj train method 
                DMLT(c).object = DMLT(c).object.train(X,Y);
                
                keyboard
                
                % when DMLTobj is a crossvalidator object:
%                accuracy    = DMLT(c).object.statistic('accuracy');
%                pval        = DMLT(c).object.statistic('binomial');
 
                % when DMLTobj is a permutation object
                pval        = DMLT(c).object.statistic;
        
            end
        end
        
        %% 7: DESCRIBE OUTPUTS!
        
        % Save outputs to mat files...
        save(fullfile(subjDir, 'decodeWeight.mat'), 'decodeWeight');
        save(fullfile(subjDir, 'decodeSig.mat'), 'decodeSig');
        save(fullfile(subjDir, 'decodeMat.mat'), 'decodeMat');
        
        % DMLT outputs
        aap=aas_desc_outputs(aap,subj,'decodeWeight', fullfile(subjDir, 'decodeWeight.mat'));
        aap=aas_desc_outputs(aap,subj,'decodeSig', fullfile(subjDir, 'decodeSig.mat'));
        aap=aas_desc_outputs(aap,subj,'decodeMat', fullfile(subjDir, 'decodeMat.mat'));
        
end