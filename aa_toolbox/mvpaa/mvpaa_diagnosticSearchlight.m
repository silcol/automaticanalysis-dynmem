function mvpaa_diagnosticSearchlight(aap, Statistics)

if aap.tasklist.currenttask.settings.diagnostic > 0
    
    mriname = aas_prepare_diagnostic(aap);
    
    for c = 1:length(aap.tasklist.currenttask.settings.contrasts)
        
        aMax = ceil(max(abs(Statistics(:,c,2))));
        
        h = img2hist(Statistics(:,c,2), -aMax:0.1:aMax, aap.tasklist.currenttask.settings.contrasts(c).name);
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_con' num2str(2) '.jpeg']));
        
        try close(h); catch; end
    end
end
