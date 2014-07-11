% Remove effect of a noise regressor from our Similarity data
% This is contained in the denoising structure which contains a set of
% denoising variables affecting a subset of cells...

function Similarity = mvpaa_Denoising(Similarity, denoisingStructure)

%% Remove effects related to the motion parameters...
if length(denoisingStructure) == 1
    
    dat = Similarity(denoisingStructure.affected);
    pred = denoisingStructure.matrix;
    
    
    % Fit the predictors to the GLM...
    [bb,dev,stats] = glmfit(pred,dat);
    
    % Subtract effect from the data...
    for p = 1:size(pred,2)
        dat = dat - (bb(p+1) .* pred(:,p));
    end
    
    Similarity(denoisingStructure.affected) = dat;
    
elseif length(denoisingStructure) > 1
    for sess = 1:length(denoisingStructure)
        
        % Create predictor matrices...
        dat = Similarity(denoisingStructure(sess).affected);
        
        pred = denoisingStructure(sess).matrix;
        
        % Fit the predictors to the GLM...
        [bb,dev,stats] = glmfit(pred,dat);
        
        % Subtract effect from the data...
        for p = 1:size(pred,2)
            dat = dat - (bb(p+1) .* pred(:,p));
        end
        
        % Remove effect of temporal differences from data...
        Similarity(denoisingStructure(sess).affected) = dat;
    end
end
