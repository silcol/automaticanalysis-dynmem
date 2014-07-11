% AA module - tsdiffana - tool to assess time series variance
% [aap,resp]=aamod_tsdiffana(aap,task,subj,sess)
% Rhodri Cusack MRC CBU Cambridge Aug 2004
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_tsdiffana(aap,task,subj,sess)

resp='';

switch task
    case 'domain'
        resp='session';   % this module needs to be run once per session
    case 'whentorun'
        resp='justonce';  % should this be run everytime or justonce?
    case 'description'
        resp='Run tsdiffana';
    case 'summary'
        resp='Check time series variance using tsdiffana\n';
        
    case 'report' % Updated [TA]
        aap = aas_report_add(aap,subj,'<table><tr><td>');
        aap=aas_report_addimage(aap,subj,fullfile(aas_getsesspath(aap,subj,sess),'diagnostic_aamod_tsdiffana.jpg'));
        aap = aas_report_add(aap,subj,'</td></tr></table>');
    case 'doit'
        sesspath=aas_getsesspath(aap,subj,sess);
        
        aas_makedir(aap,sesspath);
        
        % get files in this directory
        imgs=aas_getimages_bystream(aap,subj,sess,'epi');
        
        tsdiffana(imgs,0);
        
        % Now produce graphical check
        try figure(spm_figure('FindWin', 'Graphics')); catch; figure(1); end;
        print('-djpeg','-r150',fullfile(sesspath,'diagnostic_aamod_tsdiffana'));
        
        % Save the time differences
        aap = aas_desc_outputs(aap,subj,sess, 'tsdiffana', fullfile(sesspath, 'timediff.mat'));
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end