% Converts motion regressors into matrices that can be used to denoise the
% similarity matrices...
function spikeNulling = mvpaa_spikeNulling_prepare(aap)

% Motion denoising for similarity data cleanup!
streams = aap.tasklist.currenttask.settings.inputstreams.stream;
if any(strcmp(streams, 'listspikes'))
    
    % Get sessionNum
    sessionNum = aap.tasklist.currenttask.settings.sessionNum;
    spikeNulling = zeros(size(sessionNum));
        
    for sess=aap.acq_details.selected_sessions
        SPfn = aas_getimages_bystream(aap,aap.subj,sess, 'listspikes');
        
        % Contains spike scan numbers
        TSspikes = []; Mspikes = [];
        load(SPfn);
        
        % Combine spikes and moves...
        regrscans = union(TSspikes(:,1), Mspikes(:,1));
        
        % Assign them to the spike nulling vector...
        currentSpikes = zeros(sum(sess==sessionNum), 1);
        currentSpikes(regrscans) = 1;
        spikeNulling(sess==sessionNum) = currentSpikes;
    end
    [X, Y] = ndgrid(spikeNulling);
    spikeNulling = logical(X + Y);
else
    spikeNulling = [];
end
