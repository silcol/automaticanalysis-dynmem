% AA module - add trend covariates (polynomials set) to firstlevel model.
% NB this makes high pass filtering redundant. Defaults to 'adaptive',
% meaning that the degree of polynomials is set by the scan time in minutes
% divided by 2 (from Kay).
%
% [aap,resp]=aamod_firstlevel_trends(aap,task,subj)
function [aap,resp]=aamod_firstlevel_trends(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        load(spmpath);
        if strcmp(aap.tasklist.currenttask.settings.maxdegree,...
                'adaptive')
            % use Kay rule for setting n polynomials based on run
            % duration
            getdeg = @(n) round(n*SPM.xY.RT/60/2);
        else
            % just read off parameter
            getdeg = @(n) aap.tasklist.currenttask.settings.maxdegree;
        end
        for sess = 1:length(SPM.Sess);
            nvol = SPM.nscan(sess);
            deg = getdeg(nvol);
            % leave off 0 term since SPM already has run constant
            tm = constructpolynomialmatrix(nvol,1:deg);
            names = arrayfun(@(x)sprintf('poly%02d',x),1:deg,...
                'uniformoutput',false);
            % add to SPM
            SPM.Sess(sess).C.C    = [SPM.Sess(sess).C.C ...
                tm];
            SPM.Sess(sess).C.name = [...
                SPM.Sess(sess).C.name names];
        end
        save(spmpath,'SPM');
        %% Describe outputs
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',spmpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
