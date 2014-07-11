% MVPAA Extraction
% Extracts ROI data from aap.tasklist.currenttask.settingsIs

function Pattern = mvpaa_extraction(aap, data, indROI)

% We only want the indices that are finite and not 0
indROI = indROI(and(isfinite(data(1,indROI)), data(1,indROI) ~= 0));
voxels = length(indROI);

% Check that it's worth to extract data
if voxels > aap.tasklist.currenttask.settings.minVoxels
    % Get all betas quickly
    Pattern = data(:,indROI);
else
    Pattern = [];
end