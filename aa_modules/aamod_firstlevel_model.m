% AA module - first level statistics
% **********************************************************************
% You should no longer need to change this module - you may just
% modify the .xml or model in your user script
% **********************************************************************
% Based on original by FIL London and Adam Hampshire MRC CBU Cambridge Feb 2006
% Modified for aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Thanks to Rik Henson for various suggestions (modified) [AVG & TA]

function [aap,resp]=aamod_firstlevel_model(aap,task,subj)

resp='';

switch task
    case 'report' % [TA]
        if ~exist(fullfile(aas_getsubjpath(aap,subj),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_design.jpg']),'file')
            load(aas_getfiles_bystream(aap,subj,aap.tasklist.currenttask.outputstreams.stream{1}));
            spm_DesRep('DesOrth',SPM.xX);
            saveas(spm_figure('GetWin','Graphics'),fullfile(aas_getsubjpath(aap,subj),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_design.jpg']));
            close all;
        end
        fdiag = dir(fullfile(aas_getsubjpath(aap,subj),'diagnostic_*.jpg'));
        for d = 1:numel(fdiag)
            aap = aas_report_add(aap,subj,'<table><tr><td>');
            aap=aas_report_addimage(aap,subj,fullfile(aas_getsubjpath(aap,subj),fdiag(d).name));
            aap = aas_report_add(aap,subj,'</td></tr></table>');
        end

    case 'doit'
        % Get subject directory
        cwd=pwd;

        % Prepare basic SPM model...
        [SPM, anadir, files, allfiles, model, modelC] = aas_firstlevel_model_prepare(aap, subj);

        % Get all the nuisance regressors...
        [movementRegs, compartmentRegs, physiologicalRegs, spikeRegs] = ...
            aas_firstlevel_model_nuisance(aap, subj, files);

        %% Set up CORE model
        cols_nuisance=[];
        cols_interest=[];
        currcol=1;

        sessnuminspm=0;

        for sess = aap.acq_details.selected_sessions
            sessnuminspm=sessnuminspm+1;

            % Settings
            SPM.nscan(sessnuminspm) = size(files{sess},1);
            SPM.xX.K(sessnuminspm).HParam = aap.tasklist.currenttask.settings.highpassfilter;

            % Set up model
            [SPM, cols_interest, cols_nuisance, currcol] = ...
                aas_firstlevel_model_define(aap, sess, sessnuminspm, SPM, model, modelC, ...
                                                             cols_interest, cols_nuisance, currcol, ...
                                                             movementRegs, compartmentRegs, physiologicalRegs, spikeRegs);
        end

        cd (anadir)

        %%%%%%%%%%%%%%%%%%%
        %% DESIGN MATRIX %%
        %%%%%%%%%%%%%%%%%%%
        SPM.xY.P = allfiles;
        SPMdes = spm_fmri_spm_ui(SPM);

        % DIAGNOSTIC
        mriname = aas_prepare_diagnostic(aap, subj);
        try
            saveas(1, fullfile(aap.acq_details.root, 'diagnostics', ...
                                                [mfilename '__' mriname '.fig']));
        catch
        end

        % now check real covariates and nuisance variables are
        % specified correctly
        SPMdes.xX.iG = cols_nuisance;
        SPMdes.xX.iC = cols_interest;

        % Turn off masking if requested
        if ~aap.tasklist.currenttask.settings.firstlevelmasking
            SPMdes.xM.I=0;
            SPMdes.xM.TH=-inf(size(SPMdes.xM.TH));
        end
        
        %% WANTED TO MAKE SPIKE BETAS LOOK LIKE THE IMAGE THEY REMOVE
        % DOES NOT SEEM TO AFFECT RESULTS...
        %{
        for r = 1:length(SPMdes.xX.name);
           if ~isempty(strfind(SPMdes.xX.name{r}, 'SpikeMov'))
              SPMdes.xX.X(SPMdes.xX.X(:, r) < 0 , r) = 0;
              SPMdes.xX.X(SPMdes.xX.X(:, r) > 0 , r) = 1;
           end
        end
        %}
        
        %%%%%%%%%%%%%%%%%%%
        %% ESTIMATE MODEL%%
        %%%%%%%%%%%%%%%%%%%
        spm_unlink(fullfile('.', 'mask.img')); % avoid overwrite dialog
        SPMest = spm_spm(SPMdes);

        %% Describe outputs
        cd (cwd);

        % Describe outputs
        %  firstlevel_spm
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm',fullfile(anadir,'SPM.mat'));

        %  firstlevel_betas (includes related statistical files)
        allbetas=dir(fullfile(anadir,'beta_*'));
        betafns=[];
        for betaind=1:length(allbetas);
            betafns=strvcat(betafns,fullfile(anadir,allbetas(betaind).name));
        end
        if ~aap.tasklist.currenttask.settings.firstlevelmasking
            otherfiles={'ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        else
            otherfiles={'mask.hdr','mask.img','ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        end
        for otherind=1:length(otherfiles)
            betafns=strvcat(betafns,fullfile(anadir,otherfiles{otherind}));
        end
        aap=aas_desc_outputs(aap,subj,'firstlevel_betas',betafns);

        %% DIAGNOSTICS...
        h = firstlevelmodelStats(anadir, [], fullfile(anadir, 'mask.img'));
        saveas(h.regs, fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_regs.eps']), 'psc2');
        saveas(h.betas, fullfile(aap.acq_details.root, 'diagnostics', [mfilename '__' mriname '_betas.eps']), 'psc2');
        
        close(h.regs)
        close(h.betas)
        
        % Clean up
        for sess = aap.acq_details.selected_sessions
            for f = 1:size(files{sess},1)
                delete(files{sess}(f,:));
            end
        end        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end