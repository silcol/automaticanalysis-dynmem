% Converts motion regressors into matrices that can be used to denoise the
% similarity matrices...
function denoisingStructure = mvpaa_Denoising_prepare(aap, denoisingVector, denoisingMode, denoisingTransform)
if nargin < 5
    denoisingTransform = [];
end

% Create one large matrix of motion distances between time-points
denoisingMatrix = cell(1,size(denoisingVector,2));

for d = 1:size(denoisingVector,2)
    % Get a distance metric
    [X Y] = meshgrid(denoisingVector(:,d));
    denoisingMatrix{d} = abs(X - Y);

    % Transform
    if ~isempty(denoisingTransform)
        denoisingMatrix{d} = feval(denoisingTransform, denoisingMatrix{d});
    end
    
    % Our initial denoising matrix must be the same size as our data
    if size(denoisingMatrix{d},1) ~= aap.tasklist.currenttask.settings.observations;
        aas_log(aap,1,sprintf('Your denoising matrix is the wrong size (%d) for your data (%d)', ...
            size(denoisingMatrix{d},1),aap.tasklist.currenttask.settings.observations))
    end
end

% Empty structure to store motion regressors...
denoisingStructure = [];
denoisingStructure.matrix = [];
denoisingStructure.affected = [];

switch denoisingMode
    case 'subject'
        denoisingStructure.affected = or(aap.tasklist.currenttask.settings.withinSession, ...
            aap.tasklist.currenttask.settings.acrossSession);
        
        % Place all infromation in one single vector...
        denoisingRegressor = nan(sum(denoisingStructure.affected(:)), size(denoisingVector,2));
        for d = 1:size(denoisingVector,2)
            % Demean and balance
                denoisingRegressor(:,d) = mvpaa_balanceCont(denoisingMatrix{d}(denoisingStructure.affected), ...
                    'equalIntervals', 1);
        end
        denoisingStructure.matrix = denoisingRegressor;
        
    case 'session'
        
        for sess = aap.tasklist.currenttask.settings.sessions
            denoisingStructure(sess).affected = aap.tasklist.currenttask.settings.withinSessionNumbering == sess;
            
            % Place all infromation in one single vector...
            denoisingRegressor = nan(sum(denoisingStructure(sess).affected(:)), size(denoisingVector,2));
            for d = 1:size(denoisingVector,2)
                % Demean and balance
                denoisingRegressor(:,d) = mvpaa_balanceCont(denoisingMatrix{d}(denoisingStructure(sess).affected), ...
                    'equalIntervals', 1);
            end
            denoisingStructure(sess).matrix = denoisingRegressor;
        end
        
    otherwise
        aas_log(aap,1,sprintf('Invalid option %s in denoisingMode', denoisingMode))
end
