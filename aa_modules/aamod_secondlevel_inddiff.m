% AA module - second level statistics
% Only runs if all contrasts present in same order in all subjects at first
% level. If so, makes model with basic t-test for each of contrasts.
% Second-level model from Rik Henson
% Modified for aa by Rhodri Cusack May 2006
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_secondlevel_inddiff(aap,task)

resp='';

switch task
    case 'domain'
        resp='study';   % this module needs to be run once per study
        
    case 'description'
        resp='SPM second level individual differences';
        
    case 'doit'
        aas_prepare_diagnostic(aap);        
        
        nsub=length(aap.acq_details.subjects);
        aas_log(aap,false,sprintf('%d subjects',nsub));
        
        % New option to allow suffix to output file in extraparameters
        if (isfield(aap.tasklist.currenttask.extraparameters,'stats_suffix'))
            stats_suffix = aap.tasklist.currenttask.extraparameters.stats_suffix;
        else
            stats_suffix = [];
        end
        
        % And make analysis directory
        rfxrootdir = fullfile(aap.acq_details.root,[aap.directory_conventions.rfx stats_suffix]);
        if ~exist(rfxrootdir,'file'); mkdir(aap.acq_details.root,[aap.directory_conventions.rfx stats_suffix]);end
        cd(rfxrootdir);
        
        instreams = aap.tasklist.currenttask.inputstreams.stream;
        streamBH = strcmp(instreams, 'subject_behaviour');
        if any(streamBH ~= 0)
            streamBH = instreams{streamBH};
        else
            streamBH = [];
        end
        streamCon = instreams{~strcmp(instreams, 'subject_behaviour')};
        
        cfns = {};
        pfns = {};
        tfns = {};        
        
        % Now check all subjects have same number of contrasts and same
        % contrast names at first level
        
        for subj = 1:nsub
            % Get the confiles in order...
            confiles{subj} = aas_findstream(aap, streamCon, subj);
            
            confiles{subj} = aas_ignore_hdr(confiles{subj});
            
            % Mask 0s in images to NaN [AVG]
            mask_img([], confiles{subj}, NaN);
            
            behav = [];
            load(aas_getfiles_bystream(aap, subj, streamBH));
            if subj == 1
                BH = nan(nsub, length(behav));
            end
            BH(subj, :) = behav;
        end
        
        for c = 1:size(confiles{1}, 1)
            for subj = 1:nsub
                V = spm_vol(confiles{subj}(c,:));
                if subj == 1
                    Y = nan(nsub, V.dim(1), V.dim(2), V.dim(3));
                end
                Y(subj,:,:,:) = spm_read_vols(V);
            end
            
            %% DEBUG DIAGNOSTICS
            %{
            h.Fig = figure;
            scatter(Y(:, 88, 87, 46), BH)
            h.Line = lsline;
            
            % Make figure intelligible
            axis tight
            h.Xlabel = xlabel('Activity');
            h.Ylabel = ylabel('Memory error');
            set(h.Line, 'color', 'k', 'linewidth', 5)
            pimpFigure(h);
            
            print('-depsc2', '~/Desktop/scatter.eps');
            close(h.Fig);
            %}
            %%
            
            Y = reshape(Y, [nsub, V.dim(1)*V.dim(2)*V.dim(3)]);
            
            for b = 1:size(BH,2)
                C = corrSeeds2Targets(BH(:,b), Y);
                [P, T] = corr2pt(C, nsub);
                
                C = reshape(C, [V.dim(1) V.dim(2) V.dim(3)]);
                P = 1 - reshape(P, [V.dim(1) V.dim(2) V.dim(3)]); % 1-pval
                T = reshape(T, [V.dim(1) V.dim(2) V.dim(3)]);
                
                cfns = [cfns, fullfile(rfxrootdir, sprintf('inddiff_con%03d_beh%03d_C.nii', c, b))];
                V.fname = cfns{end};
                spm_write_vol(V,C);
                
                pfns = [cfns, fullfile(rfxrootdir, sprintf('inddiff_con%03d_beh%03d_P.nii', c, b))];
                V.fname = pfns{end};
                spm_write_vol(V,P);
                
                tfns = [cfns, fullfile(rfxrootdir, sprintf('inddiff_con%03d_beh%03d_T.nii', c, b))];
                V.fname = tfns{end};
                spm_write_vol(V,T);
            end
        end
        
        %% Describe outputs
        aap=aas_desc_outputs(aap,'secondlevel_id_corr',cfns);
        aap=aas_desc_outputs(aap,'secondlevel_id_pval',pfns);
        aap=aas_desc_outputs(aap,'secondlevel_id_tval',tfns);
                
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
        
end
end
