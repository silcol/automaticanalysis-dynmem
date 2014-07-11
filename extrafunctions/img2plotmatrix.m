% This function loads an image (or matrix), and plots a histogram from it
function h = img2plotmatrix(fileName, labels)

if ischar(fileName)
    fileName = strvcat2cell(fileName);
elseif ~iscell(fileName);
    fileName = {fileName};
end

if nargin < 2
   labels = cell(size(fileName));
   for f = 1:length(fileName)
      labels{f} = sprintf('hist%d', f);
   end
end

%% plotmatrix
Y = cell(size(labels));
for f = 1:length(fileName)
    
    % Get image or matrix...
    if ischar(fileName{f})
        Y{f} = spm_read_vols(spm_vol(fileName{f}));
    else
        Y{f} = fileName{f};
    end
    
    if f == 1
        M = and(~isnan(Y{f}), Y{f} ~= 0);
    end
    
    % Linearise (exclude NaN and zero values)
    Y{f} = Y{f}(M);
    
    if f == 1
       data = nan(size(Y{f}), length(fileName)); 
    end
    
    data(:,f) = Y{f};
end

h.Fig = figure;
h.Xlabel = [];
h.Ylabel = [];
[C, H, AX, BigAx, P] = plotmatrix_aa(data);
disp(C);
h.Title = title('');

% Insert label or title
for f = 1:length(AX)
    set(gcf,'CurrentAxes', AX(1,f));
    h.Xlabel = [h.Xlabel title(labels{f})];
    
    set(gcf,'CurrentAxes', AX(f,1));
    h.Ylabel = [h.Ylabel ylabel(labels{f})];  
end

for f = 1:length(AX(:))
    set(gcf,'CurrentAxes', AX(f));
    pimpFigure(h);
end
