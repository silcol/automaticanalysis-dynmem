% AA module
% Runs EPI masking after BET

function [aap, resp]=aamod_bet_masking(aap,task,subj,sess)

resp='';

switch task
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('Align %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        streams=aap.tasklist.currenttask.inputstreams.stream;
        
        for streamind=1:length(streams)
            if ~strcmp(streams{streamind}, 'epiBETmask')
                % Images to mask
                if (exist('sess','var'))
                    P = aas_getfiles_bystream(aap,subj,sess, streams{streamind});
                else
                    P = aas_getfiles_bystream(aap,subj, streams{streamind});
                end
                
                % Get mask
                Mimg = aas_getfiles_bystream(aap,subj, 'epiBETmask');
                % Only first one
                Mimg = Mimg(1,:);
                
                % Copy with a new prefix 'b'
                bP = aas_copy2prefix(P, 'b');
                
                % Mask epis with mask!
                mask_img(Mimg, bP, NaN);
                
                %% DESCRIBE OUTPUTS!
                if (exist('sess','var'))
                    aap=aas_desc_outputs(aap,subj,sess,streams{streamind}, bP);
                else
                    aap=aas_desc_outputs(aap,subj,streams{streamind}, bP);
                end
                
            end
        end
end
