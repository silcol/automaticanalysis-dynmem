% AA module - reslicing
% [aap,resp]=aamod_reslice(aap,task,subj)
% Reslices images to a common space defined by the first image
% subj=subject num
% Rhodri Cusack MRC CBU 2004-6 based on original by Matthew Brett
% Modified by Rik Henson 2006-8 to accept reslice "which" option
% 	(plus more defaults can be passed)

function [aap,resp]=aamod_reslice(aap,task,subj)

resp='';

switch task
    case 'report'
    case 'doit'
        
        streams=aap.tasklist.currenttask.inputstreams.stream;
        for streamind=1:length(streams)
            for sess=aap.acq_details.selected_sessions
                imgs{sess} = aas_getimages_bystream(aap,subj,sess,streams{streamind});
            end
            % Run the reslicing
            spm_reslice(imgs);
            % Describe outputs
            for sess = aap.acq_details.selected_sessions
                rimgs=[];
                for k=1:size(imgs{sess},1);
                    [pth nme ext]=fileparts(imgs{sess}(k,:));
                    rimgs=strvcat(rimgs,fullfile(pth,['r' nme ext]));
                end;
                sessdir=aas_getsesspath(aap,subj,sess);
                aas_desc_outputs(aap,subj,sess,streams{streamind},rimgs);
            end
        end
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end