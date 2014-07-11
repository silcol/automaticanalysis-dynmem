function con = mvpaa_balanceCont( con, mode, demean )
%BALANCE_CON Balance an MVPaa contrast for GLM
%   con => N-D array containing the contrast (univariate = 1D, multivariate
%   = 2D, usually)
%   mode => manner in which to balance the contrasts...
%           'zeroBaseline'                 - keep 0s as baseline (disrupts interval spacing)
%           'equalIntervals' (default)     - keep equal intervals, at cost of baseline
%   demean => do we want to demean the contrast? 

%% NEW WAY
if nargin < 2
    mode = 'equalIntervals';
end
if nargin < 3
    demean = 0;
end

if demean > 0
    con = con - nanmean(con(:));
end

% For balancing we need equal 
if any(con(:) < 0) && any(con(:) > 0)
    switch mode
        case 'zeroBaseline'
            pos = (con>0).*con; neg = (con<0).*con;
            ratio = sqrt(abs(nansum(pos(:))/nansum(neg(:))));
            pos = pos/ratio; neg = neg*ratio;
            con = pos + neg;
        case 'equalIntervals'
            con = con - nanmean(con(:));
        case 'none'
            % No balancing (important for lsqcurvefit, and where absolute
            % values may matter)
        otherwise
            error('Incorrect option chosen!')
    end
else
    warning(['Your contrast does not contain negative values, hence it will be unbalanced. ' ...
        ' Consider 0 meaning your contrast before balancing...'])
end

switch mode
    case 'none'
    otherwise
        con = con ./ (nansum(abs(con(:)))/2);
end