function cont = mvpaa_label2cont(label, mode, balance, demean)
%% cont = mvpaa_label2cont(label, mode, balance, demean)
% Label = the labels of the different conditions
% Mode = are the labels 'discrete', 'continuous', 'binary'
% Balance = mode in which to balance the contrasts... if it is an empty
% array/string, it will ignore this step

if nargin < 2 || ~ischar(mode)
   error('You did not select a correct mode for your contrast') 
end
if nargin < 3
    balance = 'equalIntervals';
    warning(sprintf('Did not select balance mode, defaulting to %s', balance))
end
if nargin < 4
    demean = 0;
    warning(sprintf('Did not select demean mode, defaulting to %d', demean))
end

[X, Y] = meshgrid(label);

cont = X - Y;
cont = abs(cont);

switch mode
    case {'discrete' 'binary'}
        % If discrete, only the same label gets high similarity, else low
        cont(~isnan(cont)) = ~cont(~isnan(cont));
        cont = 2*cont - 1;
    case 'continuous'
        % If continuous, the closer the value to the label, the more similar
        cont = -cont;
        cont = cont - min(cont(:));
end
switch mode
    case 'binary'
    % binary is a special type, which tests if within category correlations for
    % 1 are greater than correlations for 0... within categories for category 0
    % are NaNed..
    keepM = zeros(size(cont));
    keepM(cont<0) = 1;
    keepM(logical(label), logical(label)) = 1;
    cont(logical(~keepM)) = NaN;
end

% Balance the contrast!
if ~isempty(balance)
   cont = mvpaa_balanceCont(cont, balance, demean); 
end