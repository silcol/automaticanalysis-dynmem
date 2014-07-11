% AA module - realignment and unwarp
% As done at the DCCN (Donders Centre for Cognitive Neuroscience)
% [aap,resp]=aamod_realignunwarpDCCN(aap,task,subj)
% Realignment using SPM5
% i=subject num
% Based on aamod_realignunwarp by Rhodri Cusack MRC CBU 2004-6
% Alejandro Vicente Grabovetsky Jan-2012
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_realignunwarp(aap,task,subj)

resp='';

switch task
    case 'domain'
        resp='subject';
    case 'description'
        resp='SPM5 realign and unwarp';
    case 'summary'
        resp='Done SPM5 realign and unwarp\n';
    case 'report' % reformatted [TA]
        mvmean=[];
        mvmax=[];
        mvstd=[];
        mvall=[];
        nsess=length(aap.acq_details.sessions);
        
        qq=[];
        
        aap = aas_report_add(aap,subj,'<table><tr>');
        for sess=1:nsess
            aap = aas_report_add(aap,subj,'<td>');
            aap = aas_report_add(aap,subj,['<h3>Session: ' aap.acq_details.sessions(sess).name '</h3>']);
            fn = fullfile(aas_getsubjpath(aap,subj),['diagnostic_aamod_realignunwarp_' aap.acq_details.sessions(sess).name '.jpg']);
            
            % Custom plotting [TA]
            mv = aas_plot_realignPars(aap,subj,sess,~exist(fn,'file'));
            
            aap.report.mvmax(subj,sess,:)=max(mv);
            %             mvmean(sess,:)=mean(mv);
            %             mvstd(sess,:)=std(mv);
            %             mvall=[mvall;mv];
            aap=aas_report_addimage(aap,subj,fn);
            
            aap = aas_report_add(aap,subj,'<h4>Movement maximums</h4>');
            aap = aas_report_add(aap,subj,'<table cellspacing="10">');
            aap = aas_report_add(aap,subj,sprintf('<tr><td align="right">Sess</td><td align="right">x</td><td align="right">y</td><td align="right">z</td><td align="right">rotx</td><td align="right">roty</td><td align="right">rotz</td></tr>',sess));
            aap = aas_report_add(aap,subj,sprintf('<tr><td align="right">%d</td>',sess));
            aap = aas_report_add(aap,subj,sprintf('<td align="right">%8.3f</td>',aap.report.mvmax(subj,sess,:)));
            aap = aas_report_add(aap,subj,sprintf('</tr>',sess));
            aap = aas_report_add(aap,subj,'</table>');
            
            aap = aas_report_add(aap,subj,'</td>');
        end;
        aap = aas_report_add(aap,subj,'</tr></table>');
        
        varcomp=mean((std(mvall).^2)./(mean(mvstd.^2)));
        aap = aas_report_add(aap,subj,'<h3>All variance vs. within session variance</h3><table><tr>');
        aap = aas_report_add(aap,subj,sprintf('<td>%8.3f</td>',varcomp));
        aap = aas_report_add(aap,subj,'</tr></table>');
        
        aap=aas_report_addimage(aap,subj,fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_realignunwarp_FM.jpg'));
        
        % Summary in case of more subjects [TA]
        if (subj > 1) && (subj == numel(aap.acq_details.subjects)) % last subject
            meas = {'Trans - x','Trans - y','Trans - z','Pitch','Roll','Yaw'};
            for sess=1:nsess
                mvmax = squeeze(aap.report.mvmax(:,sess,:));
                figure; boxplot(mvmax,'label',meas);
                boxValPlot = getappdata(getappdata(gca,'boxplothandle'),'boxvalplot');
                fn = fullfile(aas_getstudypath(aap),['diagnostic_aamod_realignunwarp_' aap.acq_details.sessions(sess).name '.jpg']);
                print('-djpeg','-r75',fn);
                close(gcf);
                
                aap = aas_report_add(aap,'moco','<td>');
                aap = aas_report_add(aap,'moco',['<h3>Session: ' aap.acq_details.sessions(sess).name '</h3>']);
                aap=aas_report_addimage(aap,'moco',fn);
                
                for ibp = 1:numel(meas)
                    bp = boxValPlot(ibp,:);
                    subjs = ' None';
                    if bp.numFiniteHiOutliers
                        subjs = [' ' num2str(sort(cell2mat(bp.outlierrows)'))];
                    end
                    aap = aas_report_add(aap,'moco',sprintf('<h4>Outlier(s) in %s:%s</h4>',meas{ibp},subjs));
                end
                
                aap = aas_report_add(aap,'moco','</td>');
            end
        end
        
    case 'doit'
        
        %% Set up a jobs file with some advisable defaults for realign/unwarp!
        jobs = {};
        
        % Get the options from the XML!
        jobs{1}.spatial{1}.realignunwarp.eoptions = ...
            aap.tasklist.currenttask.settings.eoptions;
        jobs{1}.spatial{1}.realignunwarp.uweptions = ...
            aap.tasklist.currenttask.settings.uweoptions;
        jobs{1}.spatial{1}.realignunwarp.uwrptions = ...
            aap.tasklist.currenttask.settings.uwroptions;
        
        % Need to place this string inside a cell?
        jobs{1}.spatial{1}.realignunwarp.eoptions.weight = ...
            {jobs{1}.spatial{1}.realignunwarp.eoptions.weight };
        
        %% Get actual data!
        
        for sess = aap.acq_details.selected_sessions
            fprintf('\nGetting EPI images for session %s', aap.acq_details.sessions(sess).name)
            % Get EPIs
            EPIimg = aas_getimages_bystream(aap,subj,sess,'epi');
            jobs{1}.spatial{1}.realignunwarp.data(sess).scans = cellstr(EPIimg);
            
            % Try get VDMs
            try
                % first try to find a vdm with the session name in it
                EPIimg   = spm_select('List', ...
                    fullfile(aas_getsubjpath(aap,subj), aap.directory_conventions.fieldmapsdirname), ...
                    sprintf('^vdm.*%s.nii$', aap.acq_details.sessions(sess).name));
                
                % if this fails, try to get a vdm with session%d in it
                if isempty(EPIimg)
                    EPIimg   = spm_select('List', ...
                        fullfile(aas_getsubjpath(aap,subj), aap.directory_conventions.fieldmapsdirname), ...
                        sprintf('^vdm.*session%d.nii$',sess));
                end
                jobs{1}.spatial{1}.realignunwarp.data(sess).pmscan = ...
                    cellstr(fullfile(aas_getsubjpath(aap,subj), aap.directory_conventions.fieldmapsdirname, EPIimg));
                fprintf('\nFound a VDM fieldmap')
            catch
                jobs{1}.spatial{1}.realignunwarp.data(sess).pmscan = ...
                    [];
                fprintf('\nWARNING: Failed to find a VDM fieldmap')
            end
        end
        
        %% Run the job!
        
        spm_jobman('run',jobs);
        
        try figure(spm_figure('FindWin', 'Graphics')); catch; figure(1); end;

        % printing SPM graphics can work on some parallel's (like qsub)
        print('-djpeg','-r150',fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_realignunwarp_FM.jpg'));
        for sess = aap.acq_details.selected_sessions
            aas_plot_realignPars(aap,subj,sess,true);
        end
        
        %% Describe outputs
        for sess = aap.acq_details.selected_sessions
            rimgs=[];
            for k=1:length(jobs{1}.spatial{1}.realignunwarp.data(sess).scans);
                [pth nme ext]=fileparts(jobs{1}.spatial{1}.realignunwarp.data(sess).scans{k});
                rimgs=strvcat(rimgs,fullfile(pth,['u' nme ext]));
            end
            aap = aas_desc_outputs(aap,subj,sess,'epi',rimgs);
            
            % Get the realignment parameters...
            fn=dir(fullfile(pth,'rp_*.txt'));
            outpars = fullfile(pth,fn(1).name);
            fn=dir(fullfile(pth,'*uw.mat'));
            outpars = strvcat(outpars, fullfile(pth,fn(1).name));
            aap = aas_desc_outputs(aap,subj,sess,'realignment_parameter',outpars);
            
            if sess==1
                % mean only for first session
                fn=dir(fullfile(pth,'mean*.nii'));
                aap = aas_desc_outputs(aap,subj,1,'meanepi',fullfile(pth,fn(1).name));
            end
        end
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
end
