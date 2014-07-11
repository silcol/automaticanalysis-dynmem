% MVPA_LOADCONTRASTS load contrasts for current subject

function mvpaa_diagnosticParameters(aap)

names = fieldnames(aap.tasklist.currenttask.settings);

%% Find out inputs for this task...
fprintf('\nINPUTS FOR OUR MVPaa TASK: \n')
streams = aap.tasklist.currenttask.settings.inputstreams.stream;
for s = 1:length(streams)
    fprintf('%s\n', streams{s});
end

% Find out parameters for this task...
fprintf('\nPARAMETERS FOR OUR MVPaa TASK: \n')
for n = 1:length(names)
    switch names{n}
        case {'qsub', 'permanenceofoutput', 'inputstreams', 'outputstreams', 'COMMENT', 'model', 'timeadded'}
            
        otherwise
            fieldVal = aap.tasklist.currenttask.settings.(names{n});
            if iscell(fieldVal)
                fieldVal = fieldVal{:};
            end
            if isnumeric(fieldVal)
                fieldVal = num2str(fieldVal);
            end
            spaces = '';
            for s = 1:(30 - length(names{n}))
                spaces = [spaces ' '];
            end
            fprintf('%s :%s%s\n', names{n}, spaces, fieldVal)
    end
end
fprintf('\n')