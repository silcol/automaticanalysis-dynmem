% Make movie of an epi time series
% [aap,resp]=aamod_movie(aap,task,subj)
% J Carlin 20120911

function [aap,resp]=aamod_movie(aap,task,subj)

resp='';

switch task
    case 'description'
        resp='Run aamod_movie';
    case 'summary'
        resp='Make EPI movie\n';
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
        outfile = fullfile(subjpath,'diagnostic_aamod_movie_axial.avi');
        volumes2movie(V,outfile,aap.tasklist.currenttask.settings.fps,'axial');
        outfile = fullfile(subjpath,'diagnostic_aamod_movie_saggital.avi');
        volumes2movie(V,outfile,aap.tasklist.currenttask.settings.fps,'saggital');
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
