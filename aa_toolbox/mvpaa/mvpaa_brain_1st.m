function mvpaa_brain_1st(aap, MVPaa_obj, chunk, chunkName, segMask)
if nargin < 5
    segMask = [];
end

% Decide how much of the data to load...
brainSize = aap.tasklist.currenttask.settings.brainSize;
ROIradius = aap.tasklist.currenttask.settings.ROIradius;

chunkExp = cell(size(chunk));
chunkMember = cell(size(chunk));
for d = 1:length(chunk);
    chunkExp{d} = [chunk{d} chunk{d}(end)+1:chunk{d}(end)+ROIradius*2] - ROIradius;
    chunkExp{d}(chunkExp{d} < 1) = [];
    chunkExp{d}(chunkExp{d} > brainSize(d)) = [];
    
    chunkMember{d} = ismember(chunkExp{d}, chunk{d});
end
% Mask out voxels we do not want to test...
[X, Y, Z] = ndgrid(chunkMember{:}); % Not meshgrid!
chunkMask = logical(X.*Y.*Z);

%% GET fMRI DATA & MASK IT
MVPaa_data = MVPaa_obj.MVPaa_data(:, chunkExp{:});

% MASK DATA (using segmentation masks, for instance...)
[MVPaa_data, dataMask] = mvpaa_maskData(MVPaa_data, segMask(chunkExp{:}));

dataDim = [size(MVPaa_data, 2) size(MVPaa_data, 3) size(MVPaa_data, 4)];

ROInum = dataDim(1) .* dataDim(2) .* dataDim(3);

%% ROI SPHERE (x-y-z indices)
[ROIx, ROIy, ROIz] = mvpaa_makeSphere(aap);

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

% Loop the routine over all ROIs
reverseStr = ''; % for displaying % progress
ROIcheck = round(ROInum/100);

sumSimilarity = 0;

for r = 1:ROInum %#ok<BDSCI>
    % If voxel is outside chunk, ignore it...
    if ~chunkMask(r)
        continue
    end
    
    % Display the progress at each complete %
    if rem(r, ROIcheck) == 0
        reverseStr = aas_progress_text(r, ROInum, reverseStr, sprintf('ROI %d / %d...', r, ROInum));
    end
    
    [indROI, voxels] = mvpaa_buildROI(r, [ROIx ROIy ROIz], dataDim);
    
    % We only want the indices that contain data that is not finite and not 0
    indROI(dataMask(indROI)==1) = [];
    voxels = length(indROI);
    
    % Check that it's worth to extract data
    if voxels > aap.tasklist.currenttask.settings.minVoxels
        % Get all betas quickly
        Pattern = MVPaa_data(:,indROI);
    else
        continue;
    end
    
    % Compute similarities of the the MVPaa_data
    Similarity = mvpaa_similarity(aap, Pattern);
    sumSimilarity = sumSimilarity + Similarity;
    
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

% Remove stats that are outside of chunk...
Statistics = Statistics(chunkMask, :,:);

save(chunkName, 'Statistics', 'sumSimilarity')