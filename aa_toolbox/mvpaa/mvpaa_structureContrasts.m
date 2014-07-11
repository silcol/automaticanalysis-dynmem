% Get session indices
% Get within session indices
% Get without session indices
% Get subblock indices

function aap = mvpaa_structureContrasts(aap)

contrasts = aap.tasklist.currenttask.settings.contrasts;
testedCells = aap.tasklist.currenttask.settings.testedCells;
conditionNumbering = aap.tasklist.currenttask.settings.conditionNumbering;
conditions = length(unique(aap.tasklist.currenttask.settings.conditionNum));

% Adjust tested cells in lsqcurvefit
switch aap.tasklist.currenttask.settings.statsType
    case {'lsqcurvefit'}
        % This should only have a single contrast
        % We ignore cells that have NaNs in the contrast matrix
        testedCells(~isfinite(contrasts.matrix)) = 0;
        
        aap.tasklist.currenttask.settings.testedCells = testedCells;
    otherwise
end


for c = 1:length(contrasts)
    %% SANITY CHECKS
    % Are the contrasts square matrices?
    if size(contrasts(c).matrix,1) ~= size(contrasts(c).matrix,2)
       aas_log(aap, 1, 'Your contrast matrix is not square!') 
    end
    % Do contrast matrices concord to conditions?
    if size(contrasts(c).matrix,1) ~= conditions
       aas_log(aap, 1, 'Your contrast matrix is not the same size as your number of conditions!') 
    end
    % Are contrast matrices symmetric across the leading diagonal?
    if nansum(nanmean(abs(contrasts(c).matrix - contrasts(c).matrix'))) ~= 0
        aas_log(aap, 1, 'Your contrast matrix is not symmetric across the leading diagonal!')
    end
    % Do contrast matrices have more than 1 value?
    if length(unique(contrasts(c).matrix(~isnan(contrasts(c).matrix)))) == 1;
        % [SYLCOL: changed to permit extracting values for each cell]
        aas_log(aap, 0, 'Your contrast matrix does not contain multiple values!') 
    end
    
    contrastVector = contrasts(c).matrix( ... % Select the values we need from contrast matrix
        logical(triu(ones(size( ... % ...but only in the upper triangle of...
        contrasts(c).matrix))))); % ...this condition*condition contrast matrix
    
    % And finally balance the contrast to ensure it is 0 meaned
    contrasts(c).vector = mvpaa_balanceCont(contrastVector(conditionNumbering(testedCells)), ...
        aap.tasklist.currenttask.settings.balanceContrasts);
end

aap.tasklist.currenttask.settings.contrasts = contrasts;

%% Set block numbering for possible use as a set of nuisance regressors
blockNumbering = aap.tasklist.currenttask.settings.blockNumbering(testedCells);
if aap.tasklist.currenttask.settings.regressBlock == 1
    uniqueBlocks = unique(blockNumbering);
    uniqueBlocks(uniqueBlocks == 0) = [];
    
    blockNumberingVector = nan(length(blockNumbering), length(uniqueBlocks));
    for b = 1:length(uniqueBlocks)
        blockNumberingVector(:,b) = blockNumbering == uniqueBlocks(b);
    end
elseif aap.tasklist.currenttask.settings.regressBlock == 0
    blockNumberingVector = ones(size(blockNumbering));
elseif aap.tasklist.currenttask.settings.regressBlock == -1
    blockNumberingVector = [];
else
    error('No such option for regressBlock')
end

aap.tasklist.currenttask.settings.blockNumberingVector = blockNumberingVector;
