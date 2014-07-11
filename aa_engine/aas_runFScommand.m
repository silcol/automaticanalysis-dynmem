function [s w]=aas_runFScommand(aap,FScmd)

pth=getenv('PATH');
% Check whether ${FSLDIR}/bin is already in there
FSbin = fullfile(aap.directory_conventions.freesurferdir,'bin');
mniFSbin = fullfile(aap.directory_conventions.freesurferdir,'mni','bin');
fastFSbin = fullfile(aap.directory_conventions.freesurferdir,'fsfast','bin');

% Add colons to beginning and end of path in case FSbin is at beginning or
% end and not bracketed by them
sf=strfind([':' pth ':'],[':' FSbin ':']);
if (isempty(sf))
    pth = [pth ':' FSbin];
end;
sf=strfind([':' pth ':'],[':' mniFSbin ':']);
if (isempty(sf))
    pth = [pth ':' mniFSbin];
end;
sf=strfind([':' pth ':'],[':' fastFSbin ':']);
if (isempty(sf))
    pth = [pth ':' fastFSbin];
end;
setenv('PATH',pth);

%setenv('MNI_PERL5LIB', fullfile(aap.directory_conventions.freesurferdir, 'mni/lib/perl5/5.8.5'))
%setenv('PERL5LIB', '/opt/freesurfer/mni/lib/perl5/5.8.5')

% DEBUG!
if ~isfield(aap.directory_conventions, 'freesurfershell')
    aap.directory_conventions.freesurfershell = 'none';
end

switch (aap.directory_conventions.freesurfershell)
    case 'none'
        FSsetup = fullfile(aap.directory_conventions.freesurferdir, 'SetUpFreeSurfer.sh');
        FSenv = fullfile(aap.directory_conventions.freesurferdir, 'FreeSurferEnv.sh');
    case 'csh'
        FSsetup = fullfile(aap.directory_conventions.freesurferdir, 'SetUpFreeSurfer.csh');
        FSenv = fullfile(aap.directory_conventions.freesurferdir, 'FreeSurferEnv.csh');
end;

if not(isempty(FSsetup)) && not(FSsetup(end)==';')
    FSsetup=['source ' FSsetup ';'];
end;
if not(isempty(FSenv)) && not(FSenv(end)==';')
    FSenv=['source ' FSenv ';'];
end;

switch (aap.directory_conventions.freesurfershell)
    case 'none'
        cmd=[FSsetup FSenv FScmd];
    case 'csh'
        cmd=[FSsetup FSenv 'csh -c ' FScmd];
end;

disp(cmd)
[s w]=aas_shell(cmd);

% Display error if there was one
if (s)
    aas_log(aap,false,sprintf('Error running %s, which was %s',cmd,w));
end;