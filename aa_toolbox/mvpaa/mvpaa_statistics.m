% MVPAa_STATISTICS Sort how to do MVPA statistics depending on data
% C = correlation data
% EP.triangulation = how are the block*subblock comparisons structured

function Statistics = mvpaa_statistics(aap, Similarity)

% Take only the cells that we will test...
Similarity = Similarity(aap.tasklist.currenttask.settings.testedCells);

switch aap.tasklist.currenttask.settings.statsType
    case {'GLM' 'fullGLM' 'ranksum'}
% Statistics structure
Statistics = nan(length(aap.tasklist.currenttask.settings.contrasts), ...
    length(aap.tasklist.currenttask.settings.tests));
    case {'lsqcurvefit'}
        Statistics = nan(length(aap.tasklist.currenttask.settings.lsqcurvefitUB), ...
            length(aap.tasklist.currenttask.settings.tests));
end

switch aap.tasklist.currenttask.settings.statsType
    case 'GLM'
        % Typical parametric analysis
        for c = 1:size(Statistics,1)
            
            predictor = [aap.tasklist.currenttask.settings.contrasts(c).vector, ...
                aap.tasklist.currenttask.settings.blockNumberingVector];
            
            [b, dev, stats] = glmfit(predictor, Similarity, ...
                aap.tasklist.currenttask.settings.GLMdist, ...
                'constant', 'off');
            
            % Put statistics of the GLM in structure
            Statistics(c, 1) = stats.beta(1);
            Statistics(c, 2) = stats.t(1);
            Statistics(c, 3) = stats.p(1);
            Statistics(c, 4) = stats.se(1);
        end
        
    case 'fullGLM'
        
        predictor = [aap.tasklist.currenttask.settings.contrasts.vector, ...
            aap.tasklist.currenttask.settings.blockNumberingVector];
        
        [b, dev, stats] = glmfit(predictor, Similarity, ...
            aap.tasklist.currenttask.settings.GLMdist, ...
            'constant', 'off');
        
        for c = 1:size(Statistics,1)
            % Put statistics of the GLM in structure
            Statistics(c, 1) = stats.beta(c);
            Statistics(c, 2) = stats.t(c);
            Statistics(c, 3) = stats.p(c);
            Statistics(c, 4) = stats.se(c);
        end
        
    case 'ranksum'
        
        % Typical non-parametric analysis
        for c = 1:size(Statistics,1)
            % Get positive and negative expected similarities
            pos = Similarity(aap.tasklist.currenttask.settings.contrasts(c).vector > 0);
            neg = Similarity(aap.tasklist.currenttask.settings.contrasts(c).vector < 0);
            
            [p, h, stats] = ranksum(pos(:), neg(:));
            
            Statistics(c,1) = median(pos(:)) - median(neg(:));
            % Rank Sum is for independent samples
            % our samples are usually not paired
            Statistics(c,2) = tinv(1-p, length(pos(:))+length(neg(:))-2);
            Statistics(c,3) = p;
        end
        
    case 'lsqcurvefit'
        if length(aap.tasklist.currenttask.settings.contrasts) > 1
            aas_log(aap, 1, 'lsqcurvefit can only cope with one function')
        end
        
        % Starting point indicated or a mean of the Upper/Lower bounds
        if ~isempty(aap.tasklist.currenttask.settings.lsqcurvefitX0)
            x0 = aap.tasklist.currenttask.settings.lsqcurvefitX0;
        else
            x0 = ...
                aap.tasklist.currenttask.settings.lsqcurvefitLB/2 ...
                + aap.tasklist.currenttask.settings.lsqcurvefitUB/2;
        end                
        
        % Estimate best response parameters of chosen function
        [x, resnorm, residual, exitflag, output, lambda, jacobian] = lsqcurvefit(...
            aap.tasklist.currenttask.settings.lsqcurvefitFun, ...
            x0, ...
            aap.tasklist.currenttask.settings.contrasts.vector, Similarity, ...
            aap.tasklist.currenttask.settings.lsqcurvefitLB, aap.tasklist.currenttask.settings.lsqcurvefitUB, ...
            optimset('Display', 'off'));
        
        % What does the similarity structure look like?
        estSimilarity = [];
        eval(['estSimilarity = ' aap.tasklist.currenttask.settings.lsqcurvefitFun ...
            '(x, aap.tasklist.currenttask.settings.contrasts.vector);'])
        
        %{
        scatterMatrix = ...
        scatter2heat(aap.tasklist.currenttask.settings.contrasts.vector, Similarity, [], 100, 'log');
        %}
            
        R = corrcoef(estSimilarity, Similarity);
        [p, t] = corr2pt(R(2), length(Similarity));
        
        for c = 1:length(x)
            Statistics(c,1) = x(c);
            Statistics(c,2) = t;
            Statistics(c,3) = p;
        end
    otherwise
        aas_log(aap, 1, 'No proper statistics type chosen')
end
