% MVPAA Load Data EPI
% Automatically attempts to load MVPaa_data, using the "raw" MVPaa_data
% This can be EPI, or something else (but requires fixing mvpaa_loadData)

function [MVPaa_data, conditionNum, sessionNum, blockNum] = mvpaa_raw_loadData(aap, streamName)

% Get current subject number...
subj = aap.subj;

imgSize = [];

conditionNum = [];
sessionNum = [];
blockNum = [];

try 
    % We are dealing with raw MVPaa_data, so typically, for each session...
    EPIimg = cell(1, max(aap.acq_details.selected_sessions));
    for sess = aap.acq_details.selected_sessions
        EPIimg{sess} = aas_getfiles_bystream(aap, subj, sess, streamName);
        
        V = spm_vol(deblank(EPIimg{sess}(1,:)));
        
        if isempty(imgSize)
            imgSize = V.dim;
        end
        conditionNum = [conditionNum, 1:size(EPIimg{sess},1)];
        sessionNum = [sessionNum, sess*ones(1, size(EPIimg{sess},1))];
        blockNum = [blockNum, ones(1,size(EPIimg{sess},1))];
    end
catch mvpaa_error
    fprintf('No sessions found in stream %s', streamName);
    % Alternatively, we may be dealing with another MVPaa_data format, which is
    % equivalent to raw MVPaa_data, but subject-based...
    EPIimg = cell(1);
    EPIimg{1} = aas_getfiles_bystream(aap, subj, streamName);
    
    V = spm_vol(deblank(EPIimg{1}(1,:)));
    
    if isempty(imgSize)
        imgSize = V.dim;
    end
    conditionNum = [conditionNum, 1:size(EPIimg{1},1)];
    sessionNum = [sessionNum, sess*ones(1, size(EPIimg{1},1))];
    blockNum = [blockNum, ones(1,size(EPIimg{1},1))];
end

% Find out number of images in each session
Nimg = cellfun('size', EPIimg, 1);

MVPaa_data = nan(sum(Nimg), imgSize(1), imgSize(2), imgSize(3));

ind = 0;
for sess = 1:length(Nimg)
    fprintf('Working with session %d\n', sess);
    for d = 1:Nimg(sess)
        ind = ind + 1;
        MVPaa_data(ind, :, :, :) = spm_read_vols(spm_vol(deblank(EPIimg{sess}(d,:))));
    end
end

end