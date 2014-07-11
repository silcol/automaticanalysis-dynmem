function mvpaa_diagnosticCorrelation(aap, r, ROIfn, Resid, Simil, meanSimil)

if aap.tasklist.currenttask.settings.diagnostic > 0
    mriname = aas_prepare_diagnostic(aap);
    
    h = figure;
    set(h, 'Position', [0 0 1200 500], 'Name', ROIfn)
    
    % Draw residuals
    subplot(1,3,1)
    imagesc( ...
        reshape(Resid, ...
        [size(Resid,1) size(Resid,2)*size(Resid,3)*size(Resid,4)]))
    axis equal
    axis off
    title('Residuals')
    
    % Draw similarity matrix
    subplot(1,3,2)
    imagesc( ...
        reshape(permute( ...
        Simil, [3, 1, 4, 2]), ...
        [size(Simil,3)*size(Simil,1), size(Simil,4)*size(Simil,2)]));
    caxis([-1 1])
    axis equal
    axis off
    title('Similarity matrix...')
    
    % Similarity matrix collapsed across sessions/blocks
    subplot(1,3,3)
    imagesc(squeeze(meanSimil(r, :,:)));
    caxis([-1 1])
    axis equal
    axis off
    title('...collapsed across sessions and blocks')
    
    print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
        [mfilename '__' mriname '_' sprintf('%s', ROIfn) '.jpeg']));
    
    close(h);
end