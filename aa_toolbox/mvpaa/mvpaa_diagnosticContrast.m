function mvpaa_diagnosticContrast(aap)

if aap.tasklist.currenttask.settings.diagnostic > 0    
    mriname = aas_prepare_diagnostic(aap);
    
    contrasts = aap.tasklist.currenttask.settings.contrasts;
    aggrVars = [];
    
    % Plot all our contrast matrices...
    h = figure;
    set(h, 'Position', [0 0 1200 650], 'Name', 'Contrasts')
    
    for c = 1:length(contrasts)
        subplot(ceil(sqrt(length(contrasts)/2)), ...
            ceil(sqrt(length(contrasts)/2)*2), c)
        %imagesc(contrasts(c).matrix, 'AlphaData',~isnan(contrasts(c).matrix))
        imagescnan(contrasts(c).matrix)
        axis equal
        axis off
        title(contrasts(c).name)
        
        aggrVars = [aggrVars; contrasts(c).matrix(:)];
    end
    
    print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '.jpeg']));
    
    close(h)
    
    % Plot the correlations between our correlation matrices...
    
    [junk, h] = corrTCs(aggrVars, {contrasts.name});
    
    print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '_corrTC.jpeg']));
    
    close(h)
end