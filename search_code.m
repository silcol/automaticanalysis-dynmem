%% SEARCH_CODE
% filesFound = search_code(snippet, editFile, filters, searchToolbox)

function filesFound = search_code(snippet, editFile, filters, searchToolbox)
if nargin < 2
    editFile = 0;
end
if nargin < 3 || isempty(filters)
    filters = {'*.m' '*.xml'};
end
if nargin < 4
    searchToolbox = 1;
end

if searchToolbox == 1
    % We need to be inside the toolbox to work on it
    cd(fileparts(mfilename('fullpath')))
end

toolboxPath = pwd;

fldrDir = genpath(toolboxPath);
addpath(fldrDir); % To add the path to this toolbox!

ind = 0;

filesFound = '';

% Then recurse inside each directory until you run out of paths
while ~isempty(strtok(fldrDir, ':'))
    % Get each of the directories made by gendir
    [fldrCurr fldrDir] = strtok(fldrDir, ':');
    
    for f = 1:length(filters)
        
        D = dir(fullfile(fldrCurr, filters{f}));
        for d = 1:length(D)
            T = textread(fullfile(fldrCurr, D(d).name), '%s', 'whitespace', '', 'bufsize', 1024^2);
            
            if ~isempty(T)
                n = strfind(T{1}, snippet);
            else
                n = [];
            end
            if ~isempty(n)
                filesFound = strvcat(filesFound, sprintf('%s\n', fullfile(fldrCurr, D(d).name)));
                if editFile
                    edit(fullfile(fldrCurr, D(d).name))
                end
            end
        end
    end
end
