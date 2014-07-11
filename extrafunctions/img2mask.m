%% img2mas(Mimg, maskMode, thresh)
% Mimg: which image to convert to a mask?
% maskMode: how to threshold? ('pos', 'neg', 'abs', 'prop+', 'prop-')
% thresh: height of threshold

function Mimg = img2mask(Mimg, maskMode, thresh)
if nargin < 2
    maskMode = 'pos';
end
if nargin < 3
    thresh = 0.001;
end

% Load image first
V = spm_vol(Mimg);
Y = spm_read_vols(V);

M = zeros(size(Y));

switch maskMode
    case 'pos'
        % Anything above 0 is 1
        M(Y>thresh) = 1;
    case 'neg'
        % Anything below 0 is 1
        M(Y<thresh) = 0;
    case 'abs'
        Y = abs(Y);
        M(Y>thresh) = 1;
    case 'prop+'
        % Anything above thresh (p=0.05 means thresh 0.95);
        S = sort(Y(Y~=0 & isfinite(Y)));
        M = Y>S(round(thresh*length(S)));
    case 'prop-'
        % Anything below thresh (p=0.05 means thresh 0.05);
        S = sort(Y(Y~=0 & isfinite(Y)));
        M = Y<S(round(thresh*length(S)));
    otherwise
        error('Incorrect masking mode used!')
end

% Adjust V properties to ensure mask works fine...
V.dt(1) = 2;
V.pinfo(1) = 0; 

% Write image back...
spm_write_vol(V,M);