%% h = img2deltaseries(imgSeriesA, imgSeriesB, seriesLabels)
% This function takes the names or Vb structures of 2 series of images and
% plots them on a graph with errorbars...

function h = img2deltaseries(imgSeriesA, imgSeriesB, seriesLabels)
% Set labels...
if nargin < 3
    seriesLabels = {'imgSeriesA', 'imgSeriesB', 'Delta'};
elseif length(seriesLabels) == 2
    seriesLabels{3} = 'Delta';
end

if isstruct(imgSeriesA)
   Va = imgSeriesA; clear imgSeriesA
elseif ischar(imgSeriesA)
    Va = spm_vol(imgSeriesA);
elseif iscell(imgSeriesA)
    Va = spm_vol(cell2strvcat(imgSeriesA));
else
    error('Incorrect format for series, must be char array, cell array or Vb structure')
end
if isstruct(imgSeriesB)
    Vb = imgSeriesB; clear imgSeriesB
elseif ischar(imgSeriesB)
    Vb = spm_vol(imgSeriesB);
elseif iscell(imgSeriesB)
    Vb = spm_vol(cell2strvcat(imgSeriesB));
else
    error('Incorrect format for series, must be char array, cell array or Vb structure')
end
if length(Va) ~= length(Vb)
    error('Series have different lengths!')
end

% Means + confidence intervals
aTrend = zeros(length(Va), 2);
bTrend = zeros(length(Va), 2);
diffTrend = zeros(length(Va), 2);

for e = 1:length(Va);    
    Ya = spm_read_vols(Va(e));
    Yb = spm_read_vols(Vb(e));
    Yd = Yb-Ya;
    
    M = Yb ~= 0 & isfinite(Yb);
    lenM = sum(M(:));    
    aTrend(e,1) = mean(Ya(M));
    aTrend(e,2) = 2 * std(Ya(M)) ./ sqrt(lenM);
    bTrend(e,1) = mean(Yb(M));
    bTrend(e,2) = 2 * std(Yb(M)) ./ sqrt(lenM);
    diffTrend(e,1) = mean(Yd(M));
    diffTrend(e,2) = 2 * std(Yd(M)) ./ sqrt(lenM);
end
% Scale to 0 by subtracting mean...
aTrend(:,1) = aTrend(:,1) - mean(aTrend(:,1));
bTrend(:,1) = bTrend(:,1) - mean(bTrend(:,1));

%% Plot the trendlines
h = figure;
hold on

% Draw each trendline and remove the errorbar side-lines
ha = errorbar(aTrend(:,1), aTrend(:,2), 'r');
hb = get(ha,'children'); Xdata = get(hb(2),'Xdata'); Xdata = Xdata*0; set(hb(2),'Xdata',Xdata);

ha = errorbar(bTrend(:,1), bTrend(:,2), 'b');
hb = get(ha,'children'); Xdata = get(hb(2),'Xdata'); Xdata = Xdata*0; set(hb(2),'Xdata',Xdata);

ha = errorbar(diffTrend(:,1), diffTrend(:,2), 'g');
hb = get(ha,'children'); Xdata = get(hb(2),'Xdata'); Xdata = Xdata*0; set(hb(2),'Xdata',Xdata);

xlabel('Volumes')
ylabel('Signal')
legend(seriesLabels)