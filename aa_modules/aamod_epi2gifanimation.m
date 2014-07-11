% Make movie of an epi time series
% [aap,resp]=aamod_movie(aap,task,subj)
% J Carlin 20120911

function [aap,resp]=aamod_epi2gifanimation(aap,task,subj)

resp='';

switch task
    case 'doit'
        % now across sessions
        V = [];
        for sess = aap.acq_details.selected_sessions
            sesspath=aas_getsesspath(aap,subj,sess);
            aas_makedir(aap,sesspath);
            % get files in this directory
            imgs=aas_getimages_bystream(aap,subj,sess,'epi');
            if isempty(V)
                V = spm_vol(imgs);
            else
                V = [V; spm_vol(imgs)];
            end
        end
        subjpath = aas_getsubjpath(aap,subj);
        outfile = fullfile(subjpath,'diagnostic_aamod_epi2gifanimation_axial.gif');
        volumes2gifanimation(V,outfile,aap.tasklist.currenttask.settings.fps,'axi');
        outfile = fullfile(subjpath,'diagnostic_aamod_epi2gifanimation_saggital.gif');
        volumes2gifanimation(V,outfile,aap.tasklist.currenttask.settings.fps,'sag');
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
