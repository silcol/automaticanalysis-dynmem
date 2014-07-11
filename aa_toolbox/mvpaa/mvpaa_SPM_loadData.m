% MVPAA Load Data
% Automatically attempts to load data, based on the model you have...

function data = mvpaa_SPM_loadData(aap, SPM, ...
    sessionNum, blockNum, conditionNum, conditionNamesUnique)

%% Start loading data
fprintf('Loading beta images \r')

Bimg = aas_findstream(aap,'spmts', aap.subj);
dataType = 'spmts';
if isempty(Bimg)
    Bimg = aas_findstream(aap,'cons', aap.subj);
    dataType = 'cons';
end
if isempty(Bimg)
    Bimg = aas_findstream(aap,'betas', aap.subj);
    dataType = 'betas';
end
% Remove any existing *.hdr data from Bimg
for b = size(Bimg):-1:1
    if strfind(Bimg(b,:), '.hdr')
        Bimg(b, :) = [];
    end
end

reverseStr = ''; % for displaying progress
for d = 1:length(conditionNum)
    
    % Get the relevant numbers
    s = sessionNum(d);
    b = blockNum(d);
    c = conditionNum(d);
    
    % Do we want betas or T-values?
    if strcmp(dataType, 'betas')
        % What should our condition name contain?
        condStr =  ['Sn(' num2str(s) ') ' ... % Session number
            conditionNamesUnique{c} '_sub' num2str(b) '*']; % Condition name
        % Check which beta value corresponds to the expected condition name...
        condComp = strfind({SPM.Vbeta.descrip}, condStr);
        % Get the beta index
        imageNum = find(~cellfun('isempty', condComp));
        
        % Sanity check to see if conditions have been correctly labelled, etc.
        if isempty(strfind(SPM.Vbeta(imageNum).descrip, condStr))
            error(['Something went wrong with the condition labelling' ...
                '\This is probably not your fault! Contact the developer!'])
        end
    elseif strcmp(dataType, 'spmts') || strcmp(dataType, 'cons')
        % What should our condition name contain?
        condStr =  [conditionNamesUnique{c} '_sub' num2str(b)];
        
        % Find all contrasts that contain our condition name
        imageNum = find(strcmp({SPM.xCon.name}, ...
            condStr));
        
        % Get the correct contrast
        % Find the session that is in the correct location
        imageNum = imageNum(find(conditionNum==c) == d);
    end
    
    % Get either betas or or T values...
    V = spm_vol(deblank(Bimg(imageNum,:)));
    Y = spm_read_vols(V);
    
    % Set up data structure...
    if d == 1
       data = nan(length(conditionNum), size(Y,1), size(Y,2), size(Y,3));
    end    
    
    data(d,:,:,:) = Y;
    
    % Display the progress
    reverseStr = aas_progress_text(d, length(conditionNum), reverseStr);    
end