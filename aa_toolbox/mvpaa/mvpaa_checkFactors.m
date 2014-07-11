% MVPAA Check factors
% Automatically checks conditions/blocks in each session

function [equalConditions, equalBlocks, equalSessions] = mvpaa_checkFactors(aap, conditionNum, sessionNum, blockNum)

% Check if unique number of conditions, sessions and blocks corresponds
% to the total number of datapoints...

% What are the unique conditions
conditionUnique = unique(conditionNum(conditionNum>0));
blockUnique = unique(blockNum(blockNum>0));
sessionUnique = unique(sessionNum(sessionNum>0));

%% Check if the design is simple...
% (i.e. each session has equal number of conditions and blocks)
% Check examining if number of conditions in each block is contstant
factorUniqueA = unique(blockNum * 10^6 + conditionNum);

if length(factorUniqueA) ~= (length(blockUnique) * length(conditionUnique))
    aas_log(aap, aap.tasklist.currenttask.settings.constantFactors == 1, ...
        'Number of conditions is disparate across blocks')
    equalConditions = 0;
else
    equalConditions = 1;
end

% Check examining blocks in each session:
factorUniqueB = unique(sessionNum * 10^6 + blockNum);

if length(factorUniqueB) ~= (length(sessionUnique) * length(blockUnique))
    aas_log(aap, aap.tasklist.currenttask.settings.constantBlocks == 1, ...
        'Number of blocks is disparate across sessions')
    equalBlocks = 0;
else
    equalBlocks = 1;
end

% Check examining conditions in each session:
factorUniqueC = unique(sessionNum * 10^6 + conditionNum);

if length(factorUniqueC) ~= (length(sessionUnique) * length(conditionUnique))
    aas_log(aap, aap.tasklist.currenttask.settings.constantSessions == 1, ...
        'Number sessions id disparate across conditions (i.e. conditions are disparate across sessions)')
    equalSessions = 0;
else
    equalSessions = 1;
end

%% Check if the design is valid (where we have no repeated sets of factors)
% (i.e. we must not have repeated instances of identical conditions)
factorUnique = unique(sessionNum * 10^12 + blockNum * 10^6 + conditionNum);

if length(factorUnique) ~= length(conditionNum)
    aas_log(aap, true, ...
        'You have repeated factors (condition, block, session combinations)')
end

%% DIAGNOSTIC...
mvpaa_diagnosticFactors(aap, conditionNum, sessionNum, blockNum)
