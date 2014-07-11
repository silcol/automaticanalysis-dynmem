% Adds an event to a model
% function aap=aid_addcontrast(aap, modulename, subject, contrastname, matrix)
% 
% modulename = name of module (e.g.,'aamod_MVPaa_roi_1st') for contrast
% subject = subject for this contrast
% contrastname = name of the contrast matrix
% vector = temporal vector (or matrix) itself
% transform = how to transform the temporal denoising matrix/regressor?

function aap=mvpaa_addtemporal(aap,modulename,subject,vector, transform)

if nargin<5
    transform = [];
end

% Get number from end of module name if present in format _%05d (e.g, _00001)
if (length(modulename>6)) %#ok<ISMT>
    moduleindex=str2num(modulename(end-4:end));
    if (~strcmp(['_' sprintf('%05d',moduleindex)],modulename(length(modulename)-5:end)))
        moduleindex=1;
    else
        modulename=modulename(1:length(modulename)-6);
    end
else
    moduleindex=1;
end

% find model that corresponds and add event to this if it exists
whichmodel=strcmp({aap.tasksettings.(modulename)(moduleindex).model.subject},subject);

if (~any(whichmodel))
    aas_log(aap, 1, 'You should add contrasts before adding temporal information...')
else
    aap.tasksettings.(modulename)(moduleindex).model(whichmodel).temporal.vector = vector;
    aap.tasksettings.(modulename)(moduleindex).model(whichmodel).temporal.transform = transform;
end