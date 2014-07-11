% DEPRECATED... FIX!

% results__ROI_MVPA  prints results of ROI based MVPA analysis
% function mvpaa_ROIresults( mvpaa_pth, threshold, MCcorrection, rois, contrasts)
% mvpaa_pth: path to the MVPaa.mat you want to use
% threshold: alpha level
% MCcorrection: multiple comparisons correction
% rois: vector of ROI numbers to analyse
% contrasts: vector of contrast numbers to analyse

function mvpaa_ROIresults( mvpaa_pth, threshold, MCcorrection, rois, contrasts)
if nargin < 2
    threshold = 0.05;
end
if nargin < 3
    MCcorrection = 'sidac'; 
end
if nargin < 4
    rois = [];
end
if nargin < 5
    contrasts = [];
end

%% PREPARE EVERYTHING

load(mvpaa_pth)

if isempty(rois) < 4
    rois = 1:length(EP.ROIname);
end
if isempty(contrasts) < 5
    contrasts = 1:length(EP.contrasts);
end

% Multiple Comparisons correction
if strcmp(MCcorrection, 'sidac')
    threshold = threshold / (1 - (1 - threshold).^(1/length(rois)));
elseif strcmp(MCcorrection, 'bonferroni')
    threshold = threshold / length(rois);
elseif strcmp(MCcorrection, 'uncorr')
    
else
    error('No idea')
end

%% Display results and apply correction @@@@
%{
fid = fopen(fullfile(pth, 'ROI_data', ['MVPA__' analysis '.txt']), 'wt');

for c=1:size(Mm,2)
    fprintf(fid, '\r MULTIVARIATE. %s \r', EP.contrastsM{1,c});
    for r=1:size(Mm,1)
        printROIresults( 'ttest', EP.roiNamesL{r}, Mm(r,c, data), length(aap.acq_details.subjects), [threshold bonferroni], Mm(r,c, data+indx), fid)
    end
end
fprintf(fid, '\r ------------------- \r');
fclose(fid)
%}

% ROI names...


%% PLOT EVERYTHING
% Usage: handles = barweb(barvalues, errors, width, groupnames, bw_title, bw_xlabel, bw_ylabel,
% bw_colormap, gridstatus, bw_legend, error_sides, legend_type)

for c = contrasts
    figure
    handle = barwebAVG(aggrStats(rois,c,1), ...
        aggrStats(rois,c,4), ...
        aggrStats(rois,c,3), ...
        [], {EP.ROIname{rois}}, EP.contrasts(c).name,[],'Pattern strength', [], []);

    %{ 
        @@@@
    if isfield(Graph, 'threshold')
        l = refline(0, threshold);
        set(l,'LineStyle','--','LineWidth', 1.5, 'Color','red')
    end
        %}
%{
    if nargin>4 %& ~exist([pth '/' Mcons{c,1} '.png'],'file')
        print('-dpng', '-r200', [pth '/' Mcons{c,1} '.png'])
    end
    if nargin>4 %& ~exist([pth '/' Mcons{c,1} '.png'],'file')
        print('-depsc', '-r200', [pth '/' Mcons{c,1} '.eps'])
    end
        %}
end