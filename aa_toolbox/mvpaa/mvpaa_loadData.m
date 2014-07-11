% MVPAA Load Data
% Automatically attempts to load data, based on the model you have...

function [aap, data] = mvpaa_loadData(aap)

streams = aap.tasklist.currenttask.inputstreams.stream;

if any(strcmp(streams, 'firstlevel_betas')) || any(strcmp(streams, 'firstlevel_spmts'))
    % If we are dealing with betas/T-values from a GLM model...
    
    %% Determine which conditions we have in our model
    [SPM, conditionNum, sessionNum, blockNum, conditionNamesUnique, nuisanceNum] = ...
        mvpaa_SPM_determineFactors(aap);
    
    % Which cell belongs to which session?
    aap.tasklist.currenttask.settings.sessionNum = sessionNum;
    
    fprintf('\nThis experiment contains (truly) \n\t%d conditions\n\t%d blocks\n\t%d sessions', ...
        length(unique(conditionNum)), ...
        length(unique(blockNum)), ...
        length(unique(sessionNum)))
    fprintf('\n(%d Nuisance variables)\n\n', sum(nuisanceNum))
    
    %% Load actual SPM images!
    data = mvpaa_SPM_loadData(aap, SPM, ...
        sessionNum, blockNum, conditionNum, conditionNamesUnique);
    
elseif any(strcmp(streams, 'epi'))
    % If we have EPI data, we load it differently
    [data, conditionNum, sessionNum, blockNum] = mvpaa_raw_loadData(aap, 'epi');
else
    aas_log(aap, true, 'Unknown input stream, if you wish to add a new input stream, you may need to write a new function to import it...')
end

% Check if the number of conditions and blocks is equal across the two sessions...
[equalConditions, equalBlocks, equalSessions] = mvpaa_checkFactors(aap, conditionNum, sessionNum, blockNum);

% If we want, we can collapse the different factors together (useful if we
% want to input one massive matrix for the entire design...
if aap.tasklist.currenttask.settings.collapseFactors
    sessions = unique(sessionNum);
    for s = 2:length(sessions)
        conditionNum(sessionNum == sessions(s)) = ...
            conditionNum(sessionNum == sessions(s)) + max(conditionNum(sessionNum == sessions(s-1)));
    end
end

%% Save parameters to aa structure
aap.tasklist.currenttask.settings.conditionNum = conditionNum;
aap.tasklist.currenttask.settings.blockNum = blockNum;
aap.tasklist.currenttask.settings.sessionNum = sessionNum;