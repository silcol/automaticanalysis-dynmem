% MVPA_LOADCONTRASTS load contrasts for current subject

function aap = mvpaa_loadContrasts(aap)

% Name of subject...
subjname = aap.acq_details.subjects(aap.subj).mriname;

% Get model data from aap
subjmatches=strcmp(subjname,{aap.tasklist.currenttask.settings.model.subject});

% If no exact spec found, try subject wildcard

if (~any(subjmatches))
    subjwild=strcmp('*',{aap.tasklist.currenttask.settings.model.subject});
    if any(subjwild)
        subjmatches = subjwild;
    end
end

%% Should now have just one model spec
modelnum=find(subjmatches);
if (length(modelnum)>1)
    aas_log(aap,true,sprintf('Error while getting MVPaa contrast details as more than one specification for subject %s',subjname));
end
if (isempty(modelnum))
    aas_log(aap,true,'Cannot find MVPaa contrasts specification. Check either user script');
end

% Set contrasts and temporal matrix for this subject...
aap.tasklist.currenttask.settings.contrasts = aap.tasklist.currenttask.settings.model(modelnum).contrast;
aap.tasklist.currenttask.settings.temporal = aap.tasklist.currenttask.settings.model(modelnum).temporal;

%% CONTRAST DIAGNOSTICS...
mvpaa_diagnosticContrast(aap);