%function [s,w]=aas_shell(cmd)
% aa subroutine - wrapper for shell call
% 
function [s,w]=aas_shell(cmd, quiet, todisplay)

if (~exist('quiet','var'))
    quiet=false;
end;
if (~exist('todisplay','var'))
    todisplay=true;
end;

[s,wshell]=system('echo $0');
wshell=deblank(wshell);
if (~isempty(strfind(wshell,'bash')))
    prefix='export TERM=dumb;'; % stops colours
else
    prefix='setenv TERM dumb;'; % stops colours
end;

% [AVG] I'd like to print what is going on onto the command window...
if todisplay
    [s,w]=system([prefix cmd], '-echo');
else
    [s,w]=system([prefix cmd]);
end
if (~quiet)
    if (strcmp('shell-init: error',w))
        aas_log(aap,false,sprintf('Likely Linux error %s\n',w));
    end;
end;

if (s && ~quiet)
    [s,wenv]=system('/usr/bin/env');
    aap=[];
    aas_log(aap,false,sprintf('***LINUX ERROR FROM SHELL "%s"\n%s\n***WHILE RUNNING COMMAND\n%s\n***WITH ENVIRONMENT VARIABLES\n%s\nEND, CONTINUING\n',wshell,w,[prefix cmd],wenv));
end;
% strip off tcsh: errors at start (see http://www.mathworks.com/support/solutions/data/1-18DNL.html?solution=1-18DNL)
[l r]=strtok(w,10);
while ((length(l)>5) && strcmp(l(1:5),'tcsh:')) || ((length(l)>8) && strcmp(l(1:8),'/bin/sh:'))
    [l r]=strtok(r,10);
end;
w=10;
if (~isempty(l)) w=[l w]; end;
if (~isempty(r)) w=[w r]; end;

