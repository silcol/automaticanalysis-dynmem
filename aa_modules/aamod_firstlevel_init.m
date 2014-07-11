% AA module - initialise firstlevel_spm stream for first level GLM. This is
% very general code - shouldn't need a custom version of this ever.
% Instead, add subsequence models that add events etc to the firstlevel_spm
% as needed before estimating

function [aap,resp]=aamod_firstlevel_init(aap,task,subj)

resp='';

switch task
    case 'report'

    case 'doit'
        subjname = aap.acq_details.subjects(subj).mriname;
        clear SPM
        %% Set up basis functions
        if (isfield(aap.tasklist.currenttask.settings,'xBF'))
            SPM.xBF=aap.tasklist.currenttask.settings.xBF;
        else
            SPM.xBF.T          = aap.tasklist.currenttask.settings.T;
            SPM.xBF.UNITS      = aap.tasklist.currenttask.settings.units;
            SPM.xBF.Volterra   = 1;                 % OPTIONS: 1|2 = order of convolution
            SPM.xBF.name       = 'hrf';
            SPM.xBF.length     = 32;                % length in seconds
            SPM.xBF.order      = 1;                 % order of basis set
        end
        firstsess=aap.acq_details.selected_sessions(1);
        % if TR is manually specified (not recommended as source of error)
        if isfield(aap.tasklist.currenttask.settings,'TR') && ...
                ~isempty(aap.tasklist.currenttask.settings.TR)
            SPM.xY.RT =aap.tasklist.currenttask.settings.TR;
        else
            % Get TR from DICOM header checking they're the same for all sessions
            for sess=aap.acq_details.selected_sessions
                DICOMHEADERS=load(aas_getfiles_bystream(aap,subj,sess,'epi_dicom_header'));
                try
                    TR=DICOMHEADERS.DICOMHEADERS{1}.volumeTR;
                catch
                    % [AVG] This is for backwards compatibility!
                    TR=DICOMHEADERS.DICOMHEADERS{1}.RepetitionTime/1000;
                end
                if (sess==firstsess)
                    SPM.xY.RT = TR;
                else
                    if (SPM.xY.RT~=TR)
                        aas_log(aap,true,sprintf('Session %d has different TR from earlier sessions, they can''t be in the same model.',sess));
                    end
                end
            end
        end
        
        %% Get slice order from sliceorder stream if it exists, check same
        % for all sessions
        usesliceorder=aas_stream_has_contents(aap,'sliceorder');
        % NB, the sliceorder stream is no longer a required input so you
        % can probably mess things up now if you run in parallel
        if usesliceorder
            for sess=aap.acq_details.selected_sessions
                sliceorderstruct=load(aas_getfiles_bystream(aap,subj,sess,'sliceorder'));
                if (sess==firstsess)
                    sliceorder=sliceorderstruct.sliceorder;
                    refslice=sliceorderstruct.refslice;
                else
                    if (any(sliceorderstruct.sliceorder~=sliceorder))
                        aas_log(aap,true,sprintf('Session %d has different slice order from earlier sessions, they can''t be in the same model.',sess));
                    end
                end
            end
        end
        
        SPM.xGX.iGXcalc = 'None';
        SPM.xVi.form = 'AR(1)';
        
        %% Adjust time bin T0 according to reference slice & slice order
        %  implements email to CBU from Rik Henson 27/06/07
        %  assumes timings are relative to beginning of scans
        if isempty(aap.tasklist.currenttask.settings.T0)
            if (usesliceorder)
                refwhen=(find(sliceorder==refslice)-1)/(length(sliceorder)-1);
            else
                aas_log(aap,false,'No stream sliceorder found, defaulting timing to SPM.xBF.T0=0 in model');
                refwhen=0;
            end
            SPM.xBF.T0 = round(SPM.xBF.T*refwhen);
        else
            SPM.xBF.T0 = aap.tasklist.currenttask.settings.T0;
        end
        subdata = aas_getsubjpath(aap,subj);
        
        %% Deal with extraparameters. Not needed any more, as
        % aap.directory_conventions.stats_singlesubj
        % can have module specific value, but kept for backwards
        % compatability
        if (isfield(aap.tasklist.currenttask.extraparameters,'stats_suffix'))
            stats_suffix=aap.tasklist.currenttask.extraparameters.stats_suffix;
        else
            stats_suffix=[];
        end
        
        anadir = fullfile(subdata,[aap.directory_conventions.stats_singlesubj stats_suffix]);
        if ~exist(anadir,'dir')
            mkdir(subdata,[aap.directory_conventions.stats_singlesubj stats_suffix]);
        end
        allfiles='';
        %% Set up model
        cols_nuisance=[];
        cols_interest=[];
        sessnuminspm=0;
        currcol=1;
        for sess = aap.acq_details.selected_sessions
            sessnuminspm = sessnuminspm+1;
            %% SETTINGS & GET FILES
            files = aas_getfiles_bystream(aap,subj,sess,'epi');
            allfiles = strvcat(allfiles,files);
            SPM.xX.K(sessnuminspm).HParam = aap.tasklist.currenttask.settings.highpassfilter;
            SPM.nscan(sessnuminspm) = size(files,1);
        end
        SPM.xY.P = allfiles;
        outfile = fullfile(anadir,'SPM.mat');
        save(outfile,'SPM');
        aap = aas_desc_outputs(aap,subj,'firstlevel_spm',outfile);

    case 'checkrequirements'

    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
