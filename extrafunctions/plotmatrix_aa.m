function [C, h,ax,BigAx,patches,pax] = plotmatrix_aa(varargin)
%PLOTMATRIX_AA Modified heat-scatter plot + histogram
% [C, h, ax,BigAx,patches,pax] = plotmatrix_aa(varargin)
%
% Original help is as follows, but is not fully correct, since first ouput
% argument is C, the correlation matrix for the heatmaps...
% Also, h corresponds to the figure, not the separate elements of the
% plotmatrix...
% 
%
%
%PLOTMATRIX Scatter plot matrix.
%   PLOTMATRIX(X,Y) scatter plots the columns of X against the columns
%   of Y.  If X is P-by-M and Y is P-by-N, PLOTMATRIX will produce a
%   N-by-M matrix of axes. PLOTMATRIX(Y) is the same as PLOTMATRIX(Y,Y)
%   except that the diagonal will be replaced by HIST(Y(:,i)).
%
%   PLOTMATRIX(...,'LineSpec') uses the given line specification in the
%   string 'LineSpec'; '.' is the default (see PLOT for possibilities).
%
%   PLOTMATRIX(AX,...) uses AX as the BigAx instead of GCA.
%
%   [H,AX,BigAx,P,PAx] = PLOTMATRIX(...) returns a matrix of handles
%   to the objects created in H, a matrix of handles to the individual
%   subaxes in AX, a handle to big (invisible) axes that frame the
%   subaxes in BigAx, a matrix of handles for the histogram plots in
%   P, and a matrix of handles for invisible axes that control the
%   histogram axes scales in PAx.  BigAx is left as the CurrentAxes so
%   that a subsequent TITLE, XLABEL, or YLABEL will be centered with
%   respect to the matrix of axes.
%
%   Example:
%       x = randn(50,3); y = x*[-1 2 1;2 0 1;1 -2 3;]';
%       plotmatrix(y)

%   Clay M. Thompson 10-3-94
%   Copyright 1984-2009 The MathWorks, Inc.
%   $Revision: 1.19.4.12 $  $Date: 2011/07/25 03:49:35 $

% Parse possible Axes input
[cax,args,nargs] = axescheck(varargin{:});
error(nargchk(1,3,nargs,'struct'));
nin = nargs;

sym = '.'; % Default scatter plot symbol.
dohist = 0;

if ischar(args{nin}),
    sym = args{nin};
    [l,c,m,msg] = colstyle(sym);
    if ~isempty(msg), error(msg); end
    nin = nin - 1;
end

if nin==1, % plotmatrix(y)
    rows = size(args{1},2); cols = rows;
    x = args{1}; y = args{1};
    dohist = 1;
elseif nin==2, % plotmatrix(x,y)
    rows = size(args{2},2); cols = size(args{1},2);
    x = args{1}; y = args{2};
else
    error(message('MATLAB:plotmatrix:InvalidLineSpec'));
end

% Don't plot anything if either x or y is empty
patches = [];
pax = [];
if isempty(rows) || isempty(cols),
    if nargout>0, h = []; ax = []; BigAx = []; end
    return
end

if ndims(x)>2 || ndims(y)>2,
    error(message('MATLAB:plotmatrix:InvalidXYMatrices'))
end
if size(x,1)~=size(y,1) || size(x,3)~=size(y,3),
    error(message('MATLAB:plotmatrix:XYSizeMismatch'));
end

% Create/find BigAx and make it invisible
BigAx = newplot(cax);
fig = ancestor(BigAx,'figure');
hold_state = ishold(BigAx);
set(BigAx,'Visible','off','color','none')

if any(sym=='.'),
    units = get(BigAx,'units');
    set(BigAx,'units','pixels');
    pos = get(BigAx,'Position');
    set(BigAx,'units',units);
    markersize = max(1,min(15,round(15*min(pos(3:4))/max(1,size(x,1))/max(rows,cols))));
else
    markersize = get(0,'DefaultLineMarkerSize');
end

% Create and plot into axes
ax = zeros(rows,cols);
pos = get(BigAx,'Position');
width = pos(3)/cols;
height = pos(4)/rows;
space = .02; % 2 percent space between axes
pos(1:2) = pos(1:2) + space*[width height];
m = size(y,1);
k = size(y,3);
BigAxHV = get(BigAx,'HandleVisibility');
BigAxParent = get(BigAx,'Parent');
paxes = findobj(fig,'Type','axes','tag','PlotMatrixScatterAx');

C = nan(rows, cols);
for i=rows:-1:1,
    for j=cols:-1:1,
        axPos = [pos(1)+(j-1)*width pos(2)+(rows-i)*height ...
            width*(1-space) height*(1-space)];
        findax = findaxpos(paxes, axPos);
        if isempty(findax),
            ax(i,j) = axes('Position',axPos,'HandleVisibility',BigAxHV,'parent',BigAxParent);
            set(ax(i,j),'visible','on');
        else
            ax(i,j) = findax(1);
        end
        
        scatter2heat(reshape(x(:,j,:),[m k]), ...
            reshape(y(:,i,:),[m k]), ...
            [], 100, 'log');
        colorbar off
        axis tight
        
        % Get correlation cofficient for each scatterplot
        tmp = corrcoef(x(:,j,:), y(:,i,:));
        C(i,j) = tmp(2);
    end
end

% Deleted axis modifications... [AVG]

set(ax(1:rows-1,:),'xticklabel','')
set(ax(:,2:cols),'yticklabel','')
set(BigAx,'XTick',get(ax(rows,1),'xtick'),'YTick',get(ax(rows,1),'ytick'), ...
    'userdata',ax,'tag','PlotMatrixBigAx')
set(ax,'tag','PlotMatrixScatterAx');

if dohist, % Put a histogram on the diagonal for plotmatrix(y) case
    paxes = findobj(fig,'Type','axes','tag','PlotMatrixHistAx');
    pax = zeros(1, rows);
    for i=rows:-1:1,
        axPos = get(ax(i,i),'Position');
        findax = findaxpos(paxes, axPos);
        if isempty(findax),
            histax = axes('Position',axPos,'HandleVisibility',BigAxHV,'parent',BigAxParent);
            set(histax,'visible','on');
        else
            histax = findax(1);
        end
        
        [nn,xx] = hist(reshape(y(:,i,:),[m k]), 100);
        patches(i,:) = bar(histax,xx,nn,'hist');
        set(histax,'xtick',[],'ytick',[],'xgrid','off','ygrid','off');
        % Better way... [AVG]
        set(histax,'xlim',[min(xx) max(xx)])
        set(histax,'ylim',[0 max(nn)])
        set(histax,'tag','PlotMatrixHistAx');
        pax(i) = histax;  % ax handles for histograms
    end
    patches = patches';
end

% Make BigAx the CurrentAxes
set(fig,'CurrentAx',BigAx)
if ~hold_state,
    set(fig,'NextPlot','replace')
end

% Also set Title and X/YLabel visibility to on and strings to empty
set([get(BigAx,'Title'); get(BigAx,'XLabel'); get(BigAx,'YLabel')], ...
    'String','','Visible','on')

h = fig;

function findax = findaxpos(ax, axpos)
tol = eps;
findax = [];
for i = 1:length(ax)
    axipos = get(ax(i),'Position');
    diffpos = axipos - axpos;
    if (max(max(abs(diffpos))) < tol)
        findax = ax(i);
        break;
    end
end
