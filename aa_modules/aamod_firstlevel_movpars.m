% AA module - add (possibly extended) movement parameters to first level
% model
% [aap,resp]=aamod_firstlevel_movpars(aap,task,subj)
function [aap,resp]=aamod_firstlevel_movpars(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        %get subject directory
        %% Movement regressors (extended!) [AVG]
        [moves, mnames] = aas_movPars(aap,subj, ...
            aap.tasklist.currenttask.settings.moveMat);
        spmpath = aas_getfiles_bystream(aap,subj,'firstlevel_spm');
        load(spmpath);
        %% Add movpars to model
        sessnuminspm=0;
        for sess = aap.acq_details.selected_sessions
            sessnuminspm=sessnuminspm+1;
            % detect movpars added before other model events
            if ~isfield(SPM,'Sess') || (length(SPM.Sess) < sessnuminspm)
                SPM.Sess(sessnuminspm) = struct('C',struct('C',[],...
                    'name',[]));
            end
            %% Movement and other nuisance regressors: compartments [AVG]
            SPM.Sess(sessnuminspm).C.C    = [SPM.Sess(sessnuminspm).C.C ...
                moves{sess}];
            SPM.Sess(sessnuminspm).C.name = [...
                SPM.Sess(sessnuminspm).C.name mnames];
        end
        save(spmpath,'SPM');
        %% Describe outputs
        % Describe outputs
        %  firstlevel_spm
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',spmpath);

    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
