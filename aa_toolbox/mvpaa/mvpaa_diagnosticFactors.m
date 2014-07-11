% MVPAA Check factors
% Automatically checks conditions/blocks in each session
function mvpaa_diagnosticFactors(aap, conditionNum, sessionNum, blockNum)

if aap.tasklist.currenttask.settings.diagnostic > 0
    mriname = aas_prepare_diagnostic(aap);
    
    %% DIAGNOSTIC...
    h = figure;
    hold on
    plot(conditionNum./max(conditionNum), 'r')
    plot(blockNum./max(blockNum), 'g')
    plot(sessionNum./max(sessionNum), 'b')
    legend('Condition', 'Block', 'Session')
    
    print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '.jpeg']));
    
    close(h);
end