% MVPAA determine factors
% Determine the condition identity, blocks and sessions from the SPM
% structure, and the names assigned to the conditions during the
% 1st level modelling/contrasts steps

function [SPM, conditionNum, sessionNum, blockNum, conditionNamesUnique, nuisanceNum] = mvpaa_SPM_determineFactors(aap)

% Get current subject number...
subj = aap.subj;

SPM = []; load(aas_getfiles_bystream(aap,subj,'firstlevel_spm'));

% Session number
sessionNum = cell(size(SPM.Sess));
% block number
blockNum = cell(size(SPM.Sess));
% Conditions, we don't know how many yet...
conditionNames = cell(size(SPM.Sess));
% Nuisance conditionNames
nuisanceNum = cell(size(SPM.Sess));

%% Extract from SPM variables of interest (sessions, blocks, conditionNames)
for s = 1:length(SPM.Sess)
    % In this session we have N columns for the model
    SPMcolumns = length(SPM.Sess(s).U);
    
    % Set number of conditionNames and of "blocks" (subdivisions of data)
    blockNum{s} = nan(1, SPMcolumns);
    sessionNum{s} = ones(1, SPMcolumns) * s;
    conditionNames{s} = cell(1, SPMcolumns);
    nuisanceNum{s} = zeros(1, SPMcolumns);
    
    for c = 1:length(SPM.Sess(s).U) 
        % Where is the block string for this condition?        
        % Find where the condition name ends, and the "_sub" begins
        sub = strfind(SPM.Sess(s).U(c).name{1}, '_sub');
        
        if isempty(sub); sub = length(SPM.Sess(s).U(c).name{1}) + 1; end
        % Set the names for the conditionNames
        conditionNames{s}{c} = SPM.Sess(s).U(c).name{1}(1:sub-1);
        
        % If condition does not belong to a "block" (subdivision) -> nuisance
        if (sub - 1) == length(SPM.Sess(s).U(c).name{1})
            nuisanceNum{s}(c) = 1;
        else
            % Obtain the number of the subblock/subdivision
            blockNum{s}(c) = str2double(SPM.Sess(s).U(c).name{1}(sub+4:end));
        end
    end
end

%% Aggregated variables:
% Nuisance condition logical...
nuisanceNum = [nuisanceNum{:}];
% Conditions, we don't know how many yet...
conditionNames = [conditionNames{:}];
conditionNames = conditionNames(~nuisanceNum);
% Session number
sessionNum = [sessionNum{:}];
sessionNum = sessionNum(~nuisanceNum);
% Block ("sub-division") number
blockNum = [blockNum{:}];
blockNum = blockNum(~nuisanceNum);
% Condition number in each session
conditionNum = ones(size(conditionNames));

%% Fix the conditionNum variable in 2 easy steps
% Step 1) Find all the unique condition names
conditionNamesUnique = uniqueCells(conditionNames);
% Step 2) Set number in conditionNum depending on conditionNames...
for f = find(conditionNum)
   conditionNum(f) = find(strcmp(conditionNamesUnique, conditionNames{f}));
end