% Converts temporal information vectors (of scans/events) into temporal
% matrices that can be used to:
% 1) denoise the similarity matrix data
% 2) inform the temporal denoising (IN DEVELOPMENT!)

function temporalDenoising = mvpaa_temporalDenoising_prepare(aap)

if ~isempty(aap.tasklist.currenttask.settings.temporal)
    
    
    %% IMPLEMENTED 2 WAYS OF DENOISING
    
    if isstr(aap.tasklist.currenttask.settings.temporalDenoisingMode)
        % One is to create a denoising structure with matrices related to the
        % time between regressors...
        
        temporalDenoising = mvpaa_Denoising_prepare(aap, ...
            aap.tasklist.currenttask.settings.temporal.vector, ...
            aap.tasklist.currenttask.settings.temporalDenoisingMode, ...
            aap.tasklist.currenttask.settings.temporal.transform);
        
        mvpaa_diagnosticDenoising(aap, 'temporal', temporalDenoising)
        
    elseif isnum(aap.tasklist.currenttask.settings.temporalDenoisingMode)
        % Another is to simply use the temporal information to remove the
        % comparisons which are too close in time
        [X Y] = meshgrid(aap.tasklist.currenttask.settings.temporal);
        tempDist = abs(X - Y);
        
        temporalExclusion = tempDist < aap.tasklist.currenttask.settings.temporalDenoisingMode;
        
        if any(size(temporalExclusion)~=size(aap.tasklist.currenttask.settings.testedCells))
            aas_log(aap,1, 'Temporal exclusion matrix not the same size as data...')
        end
        % Set cells that are too close to
        aap.tasklist.currenttask.settings.testedCells(temporalExclusion) = NaN;
        
        temporalDenoising = [];
    end
else
    temporalDenoising = [];
end
