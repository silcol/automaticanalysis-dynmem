% AA module - tsdiffana - tool to assess time series variance
% Rhodri Cusack MRC CBU Cambridge Aug 2004
% subj=subject num
% sess=session num
% Original code written by Doris Eckstein and James Rowe
% Improved (and hopefully not broken) by Rhodri Cusack and Karolina
% Moutsopoulou Jun 2008

function [aap,resp]=aamod_listspikes(aap,task,subj)

resp='';

switch task
    case 'report'
    case 'doit'
        
        mriname = aas_prepare_diagnostic(aap,subj);
        
        try close(2); catch; end
        figure(2)
        
        % lists all scans with high deviation from mean, based on timediff.mat file
        % created in tsdiffana.m, and on rp*.txt file, created by
        % spm_realign.
        
        % Load the movement parameters
        rp = aas_movPars(aap,subj, [1 0 0; 0 0 0]);
        nsess = length(aap.acq_details.sessions);
        
        for sess = aap.acq_details.selected_sessions
            % Load up differnces through time as produced by tsdiffana
            tdfn = aas_getimages_bystream(aap,subj,sess,'tsdiffana');
            
            try
                load (tdfn, 'td', 'globals', 'slicediff');
            catch
                aas_log(aap,1,sprintf('%s not found: Please run tsdiffana first',tdfn));
            end
            
            xyzlimit = aap.tasklist.currenttask.settings.xyzlimit;
            rotlimit_radians = aap.tasklist.currenttask.settings.rotlimit_degrees*pi/180;
            FDlimit = aap.tasklist.currenttask.settings.FDlimit;
            
            %% Now find big changes from one image to the next
            %  td = mean (across voxels) of square difference between one volume and the next
            %  globals = mean global value across an image
            % Similar to DVARS in Power et al., 2012
            
            tm = td/(mean(globals).^2); % RC/KM added .^2 16/6/2008
            
            switch aap.tasklist.currenttask.settings.tmbaseline
                case 'zero'
                    Btm = 0;
                case 'mean'
                    Btm = mean(tm);
                case 'median'
                    Btm = median(tm);
                case 'smooth'
                    Btm = smooth(1:length(tm),tm,0.1,'rloess');
            end
            
            % Residuals of the line
            Rtm = tm - Btm;
            
            switch aap.tasklist.currenttask.settings.tmmode
                case 'absolute'
                    tmlimit = aap.tasklist.currenttask.settings.tmlimit;
                case 'std'
                    tmlimit = aap.tasklist.currenttask.settings.tmlimit * std(Rtm);
                case 'rstd'
                    % Robust std using only bottom 99% of distribution
                    oRtm = sort(Rtm);
                    oRtm = oRtm(1:round(0.99*length(oRtm)));
                    tmlimit = aap.tasklist.currenttask.settings.tmlimit * std(oRtm);
            end
            
            badTSspikes = [false; (Rtm > tmlimit)];
            
            TSspikes=[find(badTSspikes),tm(badTSspikes(2:end)),slicediff(badTSspikes(2:end))];
            
            %% Now find big movements
            % shift to sync with scan number
            rpdiff = [zeros(1,6); diff(rp{sess})];
            absrpdiff = abs(rpdiff);
            
            if ~isempty(xyzlimit) && ~isempty(rotlimit_radians) && isempty(FDlimit)
                diagnosticSubplots = 4;
                
                badTspikes = any(absrpdiff(:,1:3) > xyzlimit,2);
                badRspikes = any(absrpdiff(:,4:6) > rotlimit_radians,2);
                badMspikes= badTspikes | badRspikes;
                
            elseif ~isempty(FDlimit)
                diagnosticSubplots = 3;
                
                % Transform rotations into displacement on a sphere of radius R
                absrpdiff(:, 4:6) = absrpdiff(:, 4:6) * aap.tasklist.currenttask.settings.radiuscortex;
                frameDelta = sum(absrpdiff, 2);
                
                % Thresholding
                badMspikes = frameDelta > FDlimit;
            else
                aas_log('Wrong setup of limit parameters, either [xyzlimit and rotlimit] or FDlimit')
            end
            
            Mspikes=[find(badMspikes), rpdiff(badMspikes,:)];
            
            %% DIAGNOSTIC
            
            subplot(nsess, diagnosticSubplots, (sess - 1) * diagnosticSubplots + 1)
            hold off
            plot(tm, 'b.')
            hold on
            plot(TSspikes(:,1), TSspikes(:,2), 'ko')
            title(sprintf('Sess %d \t Spikes: %d\n', sess, size(TSspikes,1)))
            
            subplot(nsess, diagnosticSubplots, (sess - 1) * diagnosticSubplots + 2)
            hist(Rtm,50)
            title(sprintf('Distribution of the tm data underlying spikes'))
            
            if ~isempty(xyzlimit) && ~isempty(rotlimit_radians) && isempty(FDlimit)
                subplot(nsess, diagnosticSubplots, (sess - 1) * diagnosticSubplots + 3)
                hold off
                plot(rpdiff(:,1:3))
                hold on
                plot(find(badTspikes), rpdiff(badTspikes,1:3), 'ko')
                title(sprintf('Sess %d \t Translations: %d\n', sess, sum(badTspikes,1)))
                
                subplot(nsess, diagnosticSubplots, (sess - 1) * diagnosticSubplots + 4)
                hold off
                plot(rpdiff(:,4:6))
                hold on
                plot(find(badRspikes), rpdiff(badRspikes,4:6), 'ko')
                title(sprintf('Sess %d \t Rotations: %d\n', sess, sum(badRspikes,1)))
            elseif ~isempty(FDlimit)
                subplot(nsess, diagnosticSubplots, (sess - 1) * diagnosticSubplots + 3)
                hold off
                plot(frameDelta)
                hold on
                plot(find(badMspikes), frameDelta(badMspikes), 'ko')
                title(sprintf('Sess %d \t Framewise Displacements: %d\n', sess, sum(badMspikes,1)))
            end
            
            %% Save things
            fprintf('Sess %d \t Spikes: %d; Motion: %d; Bad: %d\n', sess, size(TSspikes,1), size(Mspikes,1), sum(or(badTSspikes, badMspikes))) 
            
            SPfn = fullfile(aas_getsesspath(aap,subj,sess),sprintf('spikesandMspikes.mat'));
            save(SPfn, 'TSspikes', 'Mspikes');
            
            % Save the time differences
            aap = aas_desc_outputs(aap,subj,sess, 'listspikes', SPfn);
        end
        
        %% Save graphical output to common diagnostics directory
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;
