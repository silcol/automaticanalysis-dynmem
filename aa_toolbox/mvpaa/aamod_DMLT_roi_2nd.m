% AA module - MVPaa 2nd level
%
% Modified for aa4 by Alejandro Vicente-Grabovetsky Feb-2011

function [aap,resp] = aamod_DMLT_roi_2nd(aap,task)

resp='';

switch task
    case 'doit'
        
        for subj = 1:length(aap.acq_details.subjects)
            load(aas_getfiles_bystream(aap,subj,'DMLT'));
            
            if subj == 1
                % MVPA data for Multivariate results
                indStats = nan(length(aap.acq_details.subjects), ... % Subj
                    size(DMLout,1), ... % ROIs
                    size(DMLout,2)); % Contrasts
                
                Stats = nan( ... 
                    size(DMLout,1), ... % ROIs
                    size(DMLout,2), ... % Contrasts
                    4); % mean, subj, T, df
            end
            
            for r = 1:size(DMLout,1)
                for c = 1:size(DMLout,2)
                    % Gather data from each participant
                    indStats(subj, r, c) = DMLout{r,c}.accuracy;
                end
            end
        end
        
        % 2nd level stats (aggregate StatisticollStat -> collapsed Statistics)
        for r = 1:size(DMLout,1)
            for c = 1:size(DMLout,2)
                Stats(r,c,1) = mean(indStats(:, r, c));
                [h Stats(r,c,2) ci stats] = ttest(indStats(:, r, c));
                Stats(r,c,3) = stats.tstat;
                Stats(r,c,4) = stats.df;
            end
        end
        
        %% Describe outputs...
        save(fullfile(aap.acq_details.root, 'DMLT.mat'), ...
                'Stats', 'DMLT')
        aap=aas_desc_outputs(aap,'DMLT_2nd', fullfile(aap.acq_details.root, 'DMLT.mat'));
end