% Converts motion regressors into matrices that can be used to denoise the
% similarity matrices...
function motionDenoising = mvpaa_motionDenoising_prepare(aap)

% Motion denoising for similarity data cleanup!
streams = aap.tasklist.currenttask.settings.inputstreams.stream;
if any(strcmp(streams, 'realignment_parameter'))
    % First create one large motion denoising matrix once
    RP = [];
    
    % Get motion parameters
    for sess = aap.acq_details.selected_sessions
        RPfn = aas_getfiles_bystream(aap,aap.subj, sess,'realignment_parameter');
        RPfn = deblank(RPfn(1,:));
        RP = [RP; load(RPfn)];
    end
    motionDenoising = mvpaa_Denoising_prepare(aap, ...
        RP, aap.tasklist.currenttask.settings.motionDenoisingMode);
    
    mvpaa_diagnosticDenoising(aap, 'motion', motionDenoising)
else
    motionDenoising = [];
end
