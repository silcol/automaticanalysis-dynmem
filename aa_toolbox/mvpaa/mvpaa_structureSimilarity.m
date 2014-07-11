% Get session indices
% Get within session indices
% Get without session indices
% Get subblock indices

% mvpaa_labelSimilarityMatrix RENAME
function aap = mvpaa_structureSimilarity(aap)

sessionNum = aap.tasklist.currenttask.settings.sessionNum;
blockNum = aap.tasklist.currenttask.settings.blockNum;
conditionNum = aap.tasklist.currenttask.settings.conditionNum;

ignoreTriL = logical(tril(ones(length(sessionNum))));

%% DEAL WITH SESSIONS

% Find out the cells that contain our sessions
[X Y] = meshgrid(sessionNum);
withinSessionNumbering = round(X .* ...
    mvpaa_label2cont(sessionNum, 'discrete', [], 0));
withinSessionNumbering(withinSessionNumbering < 0) = NaN;

% Find out what is within session and what is across
withinSession = ~isnan(withinSessionNumbering);
acrossSession = ~withinSession;
acrossSession = triu(acrossSession);

% Find out the cells that contain across session comparisons
acrossSessionNumbering = Y + ((X-1).^2 - (X-1))/2;
acrossSessionNumbering(~acrossSession) = NaN;

%% DEAL WITH BLOCKS

% Renumber blockNum to be unique across the
ind = 0;
RblockNum = blockNum;
for sess = unique(sessionNum)
    for block = unique(blockNum(sessionNum==sess))
        ind = ind+1;
        RblockNum(and(sessionNum==sess, blockNum==block)) = ind;
    end
end

[X, Y] = meshgrid(RblockNum);

blockNumbering =  Y + (X.^2 - X)/2;

%% DEAL WITH CONDITIONS
% This numbering system is implemented to cope easily with simple
% condition*condition contrast matrices!
[X, Y] = meshgrid(conditionNum);

% Find out the cells that contain across session comparisons
conditionNumbering = Y + (X.^2 - X)/2;
conditionNumbering = max(conditionNumbering, conditionNumbering');

%% Make repeated data NAN (ignore lower triangle)
withinSession(ignoreTriL) = 0;
acrossSession(ignoreTriL) = 0;
withinSessionNumbering(ignoreTriL) = NaN;
acrossSessionNumbering(ignoreTriL) = NaN;
blockNumbering(ignoreTriL) = NaN;
conditionNumbering(ignoreTriL) = NaN;

%% Decide which cells in the similarity matrix we will be testing
switch aap.tasklist.currenttask.settings.triangulation
    case 'acrossSessions'
        testedCells = acrossSession;
    case 'withinSessions'
        testedCells = withinSession;
    case {'all' 'none'}
        testedCells = or(withinSession, ...
            acrossSession);
end
% Remove spikes from tested cells, if these exist...
if ~isempty(aap.tasklist.currenttask.settings.spikeNulling)
    if any(size(testedCells) ~= size(aap.tasklist.currenttask.settings.spikeNulling))
        aas_log(aap, 1, 'testedCells and spikeNulling matrices are not the same size!')
    end
    
    testedCells(aap.tasklist.currenttask.settings.spikeNulling) = 0;
end

% Put everything in aap structure for later use...
aap.tasklist.currenttask.settings.withinSession = withinSession;
aap.tasklist.currenttask.settings.acrossSession = acrossSession;
aap.tasklist.currenttask.settings.withinSessionNumbering = withinSessionNumbering;
aap.tasklist.currenttask.settings.acrossSessionNumbering = acrossSessionNumbering;
aap.tasklist.currenttask.settings.blockNumbering = blockNumbering;
aap.tasklist.currenttask.settings.conditionNumbering = conditionNumbering;
aap.tasklist.currenttask.settings.testedCells = testedCells;

% Get the unique conditions, blocks and sessions...
aap.tasklist.currenttask.settings.conditions = unique(conditionNum);
aap.tasklist.currenttask.settings.blocks = unique(blockNum);
aap.tasklist.currenttask.settings.sessions = unique(sessionNum);
aap.tasklist.currenttask.settings.observations = length(conditionNum);

%% BONUS: set up stats!
switch aap.tasklist.currenttask.settings.statsType
    case {'GLM', 'fullGLM'}
        aap.tasklist.currenttask.settings.tests = {'beta', 't-value', 'p-value', 'SE'};
    case 'ranksum'
        aap.tasklist.currenttask.settings.tests = {'median', 't-value (est)', 'p-value'};
    case {'lsqcurvefit'}
        aap.tasklist.currenttask.settings.tests = {'parameter', 't-value (model)', 'p-value (model)'};
    otherwise
        aas_log(aap, 1, 'Unknown type of statistics!')
end

%% DIAGNOSTIC (very important to see if all makes sense)
if aap.tasklist.currenttask.settings.diagnostic > 0
    mriname = aas_prepare_diagnostic(aap);
    h = figure;
    
    subplot(2,3,1)
    imagescnan(withinSession)
    axis equal tight
    title('Within sessions')
    
    subplot(2,3,2)
    imagescnan(acrossSession)
    axis equal tight
    title('Across sessions')
    
    subplot(2,3,4)
    imagescnan(withinSessionNumbering)
    axis equal tight
    title('Within session numberings')
    
    subplot(2,3,5)
    imagescnan(acrossSessionNumbering)
    axis equal tight
    title('Across session numberings')
    
    subplot(2,3,3)
    imagescnan(blockNumbering)
    axis equal tight
    title('Block numberings')
    
    subplot(2,3,6)
    imagescnan(conditionNumbering)
    axis equal tight
    title('Condition numberings')
    
    saveas(h, fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '.eps']));
    
    close(h)
end
