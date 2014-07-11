% AA module - second level statistics
% Only runs if all contrasts present in same order in all subjects at first
% level. If so, makes model with basic t-test for each of contrasts.
% Second-level model from Rik Henson
% Modified for aa by Rhodri Cusack May 2006
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_secondlevel_model(aap,task,i)

resp='';

switch task
    case 'domain'
        resp='study';   % this module needs to be run once per study
        
    case 'description'
        resp='SPM5 second level (RFX) model';
        
    case 'summary'
        subjpath=aas_getsubjpath(i);
        resp=sprintf('Second level model %s\n',subjpath);
        
    case 'report'
        if ~exist(fullfile(aas_getstudypath(aap),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_design.jpg']),'file')
            load(aas_getfiles_bystream(aap,aap.tasklist.currenttask.outputstreams.stream{1}));
            spm_DesRep('DesOrth',SPM.xX);
            saveas(spm_figure('GetWin','Graphics'),fullfile(aas_getstudypath(aap),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_design.jpg']));
            close all;
        end
        fdiag = dir(fullfile(aas_getstudypath(aap),'diagnostic_*.jpg'));
        for d = 1:numel(fdiag)
            aap = aas_report_add(aap,[],'<table><tr><td>');
            aap=aas_report_addimage(aap,[],fullfile(aas_getstudypath(aap),fdiag(d).name));
            aap = aas_report_add(aap,[],'</td></tr></table>');
        end
        
    case 'doit'
        aas_prepare_diagnostic(aap);
        
        % output structures...
        betafns=[];
        confns=[];
        spmtfns=[];
        spmfns = [];
        otherfns = [];
        otherfiles={'mask.hdr','mask.img','ResMS.hdr','ResMS.img','RPV.hdr','RPV.img'};
        
        global defaults
        global UFp
        UFp=0.001;
        
        defaults.modality='FMRI'; % Some problems with the Results otherwise?
        
        nsub=length(aap.acq_details.subjects);
        aas_log(aap,false,sprintf('%d subjects',nsub));
        % New option to allow suffix to output file in extraparameters
        if (isfield(aap.tasklist.currenttask.extraparameters,'stats_suffix'))
            stats_suffix=aap.tasklist.currenttask.extraparameters.stats_suffix;
        else
            stats_suffix=[];
        end
        
        % And make analysis directory
        rfxrootdir = fullfile(aap.acq_details.root,[aap.directory_conventions.rfx stats_suffix]);
        if ~exist(rfxrootdir,'file'); mkdir(aap.acq_details.root,[aap.directory_conventions.rfx stats_suffix]);end
        cd(rfxrootdir);
        
        instreams = aap.tasklist.currenttask.inputstreams.stream;
        streamSPM = strcmp(instreams, 'firstlevel_spm');
        if streamSPM ~= 0
            streamSPM = instreams{streamSPM};
        else
            streamSPM = [];
        end
        streamCon = instreams{~strcmp(instreams, 'firstlevel_spm')};
        
        % Now check all subjects have same number of contrasts and same
        % contrast names at first level
        clear flSPM
        clear flSPMfn;
        for subj = 1:nsub
            if ~isempty(streamSPM)
                flSPMfn{subj}=aas_getfiles_bystream(aap,subj,steamSPM);
            end
            
            % Get the confiles in order...
            confiles{subj} = aas_findstream(aap, streamCon, subj);
            
            confiles{subj} = aas_ignore_hdr(confiles{subj});
            
            % Mask 0s in images to NaN [AVG]
            mask_img([], confiles{subj}, NaN)
            
            if ~isempty(streamSPM)
                SPMtemp=load(flSPMfn{subj});
                flSPM{subj}.SPM.xCon = SPMtemp.SPM.xCon;
            else
                flSPM{subj}.SPM.xCon = [];
                
                for n = 1:size(confiles{subj}, 1)
                    flSPM{subj}.SPM.xCon(n).name = sprintf('contrast_%04d', n);
                end
            end
            
            if (subj~=1)
                if (length(flSPM{subj}.SPM.xCon)~=length(flSPM{1}.SPM.xCon))
                    aas_log(aap,1,sprintf('Number of contrasts in first level analysis for subject %d different from subject 1. They must be the same for aamod_model_secondlevel to work\n',subj));
                    for n=1:length(flSPM(subj).SPM.xCon)
                        if (flSPM{subj}.SPM.xCon(n).name~=flSPM{1}.SPM.xCon(n).name);
                            aas_log(aap,1,sprintf('Names of contrasts at first level different. Contrast %d has name %s for subject %d but %s for subject 1. They must be the same for aamod_model_secondlevel to work\n', ...
                                n,flSPM{subj}.SPM.xCon(n).name,subj,flSPM{1}.xCon(n).name));
                        end
                        % Check here that the names of the files are the same
                        [pth, nme, ext] = fileparts(confiles{subj}(fileind,:));
                        if isempty(strfind(confiles{1}(fileind, :), nme))
                            aas_log(aap,1,sprintf('Names of contrasts files at first level different for subjects 1 and %d\nSubject 1: %s\nSubject %d: %s\n They must be the same for aamod_model_secondlevel to work\n', ...
                                subj, confiles{1}(n,:), subj, confiles{subj}(n,:)));
                        end
                    end
                end
            end
        end
        %                phs = 1; conname='UF_S'
        
        for n = 1:length(flSPM{1}.SPM.xCon)
            conname=flSPM{1}.SPM.xCon(n).name;
            % take out characters that don't go well in filenames...
            conname(conname==':')=[];
            conname(conname==' ')=[];
            conname(conname=='/')=[];
            conname(conname=='\')=[];
            rfxdir = fullfile(rfxrootdir,conname);
            if exist(rfxdir)~=7; mkdir(rfxrootdir,conname);end
            cd(rfxdir);
            
            clear SPM
            
            %-Assemble SPM structure
            %=======================================================================
            
            SPM.nscan = nsub;
            
            for subj=1:nsub
                SPM.xY.P{subj}    = confiles{subj}(n,:);
                SPM.xY.VY(subj)   = spm_vol(SPM.xY.P{subj});
            end
            
            SPM.xX = struct(	'X',	ones(nsub,1),...
                'iH',1,'iC',zeros(1,0),'iB',zeros(1,0),'iG',zeros(1,0),...
                'name',{{'mean'}},'I',[[1:nsub]' ones(nsub,3)],...
                'sF',{{'obs'  ''  ''  ''}});
            
            SPM.xC = [];
            
            SPM.xGX = struct(...
                'iGXcalc',1,	'sGXcalc','omit',				'rg',[],...
                'iGMsca',9,	'sGMsca','<no grand Mean scaling>',...
                'GM',0,		'gSF',ones(nsub,1),...
                'iGC',	12,	'sGC',	'(redundant: not doing AnCova)',	'gc',[],...
                'iGloNorm',9,	'sGloNorm','<no global normalisation>');
            
            SPM.xVi	= struct('iid',1,'V',speye(nsub));
            
            Mdes 	= struct(	'Analysis_threshold',	{'None (-Inf)'},...
                'Implicit_masking',	{'Yes: NaNs treated as missing'},...
                'Explicit_masking',	{'Yes: SPM2 Brain Mask'});
            
            %SPM.xM	= struct('T',-Inf,'TH',ones(nsub*2,1)*-Inf,...
            %		 'I',1,'VM',spm_vol('/home/rh01/SPM/spm5/apriori/brainmask.nii'),'xs',Mdes);
            
            SPM.xM	= struct('T',-Inf,'TH',ones(nsub*2,1)*-Inf,...
                'I',1,'VM',[],'xs',Mdes);
            
            Pdes 	= {{'1 condition, +0 covariate, +0 block, +0 nuisance'; '1 total, having 1 degrees of freedom'; 'leaving 8 degrees of freedom from 9 images'}};
            
            SPM.xsDes = struct(	'Design',		{'One sample t-test'},...
                'Global_calculation',	{'omit'},...
                'Grand_mean_scaling',	{'<no grand Mean scaling>'},...
                'Global_normalisation',	{'<no global normalisation>'},...
                'Parameters',		Pdes);
            
            % Estimate parameters
            %===========================================================================
            spm_unlink(fullfile('.', 'mask.img')); % avoid overwrite dialog
            SPM = spm_spm(SPM);
            
            %% Define contrasts
            eval(sprintf('cd %s',rfxrootdir));
            
            SPM = rmfield(SPM,'xCon'); %just in case
            
            SPM.xCon(1) = spm_FcUtil('Set',sprintf('%s',conname),'T','c',[1],SPM.xX.xKXs);
            SPM.xCon(2) = spm_FcUtil('Set',sprintf('- %s',conname),'T','c',[-1],SPM.xX.xKXs);
            
            spm_contrasts(SPM);
            
            spmfns=strvcat(spmfns,fullfile(rfxdir,'SPM.mat'));
            %  secondlevel_betas (includes related statistical files)
            allbetas=dir(fullfile(rfxdir,'beta_*'));
            for f=1:length(allbetas);
                betafns=strvcat(betafns,fullfile(rfxdir,allbetas(f).name));
            end
            for otherind=1:length(otherfiles)
                otherfns=strvcat(otherfns,fullfile(rfxdir,otherfiles{otherind}));
            end
            allcons=dir(fullfile(rfxdir,'con_*'));
            for f=1:length(allcons);
                confns=strvcat(confns,fullfile(rfxdir,allcons(f).name));
            end
            allspmts=dir(fullfile(rfxdir,'spmT_*'));
            for f=1:length(allspmts);
                spmtfns=strvcat(spmtfns,fullfile(rfxdir,allspmts(f).name));
            end
            
            %% DIAGNOSTICS (check distribution of T-values in contrasts)
            h = img2hist(fullfile(rfxdir, 'spmT_0001.img'), [], conname);
            saveas(h, fullfile(aap.acq_details.root, 'diagnostics', ...
                [mfilename '_' conname '.eps']), 'eps');
            try close(h); catch; end
        end
        %% Describe outputs
        aap=aas_desc_outputs(aap,'secondlevel_spm',spmfns);
        aap=aas_desc_outputs(aap,'secondlevel_betas',betafns);
        aap=aas_desc_outputs(aap,'secondlevel_other',otherfns);
        aap=aas_desc_outputs(aap,'secondlevel_cons',confns);
        aap=aas_desc_outputs(aap,'secondlevel_spmts',spmtfns);
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
        
end
end
