function mvpaa_diagnosticDenoising(aap, denoisingName, denoisingStructure)

if aap.tasklist.currenttask.settings.diagnostic > 0
    mriname = aas_prepare_diagnostic(aap);
    h = figure;
    
    % The size of our motion parameters can be found in our motion matrices...
    motPars = size(denoisingStructure(1).matrix,2);
    
    for d = 1:motPars
        RPmat = nan(length(aap.tasklist.currenttask.settings.conditionNum));
        
        if length(denoisingStructure) == 1
            
            RPmat(denoisingStructure.affected) = ...
                denoisingStructure.matrix(:,d);
            
        else
            for sess = 1:length(denoisingStructure)
                RPmat(denoisingStructure(sess).affected) = ...
                    denoisingStructure(sess).matrix(:,d);
            end
            
        end
        
        % And actually draw...
        subplot(1, motPars, d)
        imagescnan(RPmat);
        colorbar
        axis equal off
        title(sprintf('Par: %d', d))
    end
    
    saveas(h, fullfile(aap.acq_details.root, 'diagnostics', ...
        [denoisingName '__' mriname '.fig']));
    
    close(h)
end