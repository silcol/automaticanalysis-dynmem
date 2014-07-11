% AA module - realignment
% [aap,resp]=aamod_realign(aap,task,subj)
% Motion correction of EPI images (a.k.a. realignment) using SPM5
% Rhodri Cusack MRC CBU 2004-6 based on original by Matthew Brett
% Modified by Rik Henson 2006-8 to accept reslice "which" option
% 	(plus more defaults can be passed)
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_fsl_mcflirt(aap,task,subj)

resp='';

switch task
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
            fn = fullfile(aas_getsubjpath(aap,subj),['diagnostic_aamod_realign_' aap.acq_details.sessions(sess).name '.jpg']);
            
            % Custom plotting [TA]
            mv = aas_plot_realignPars(aap,subj,sess,~exist(fn,'file'));
            
            aap.report.mvmax(subj,sess,:)=max(mv);
            % mvmean(sess,:)=mean(mv);
            % mvstd(sess,:)=std(mv);
            % mvall=[mvall;mv];
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
        
        aap=aas_report_addimage(aap,subj,fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_realign.jpg'));

		% Summary in case of more subjects [TA]
        if (subj > 1) && (subj == numel(aap.acq_details.subjects)) % last subject
            
            meas = {'Trans - x','Trans - y','Trans - z','Pitch','Roll','Yaw'};
            for sess=1:nsess
                mvmax = squeeze(aap.report.mvmax(:,sess,:));
                boxplot(mvmax,'label',meas);
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
          
        mriname = aas_prepare_diagnostic(aap, subj);
        subjPth = aas_getsubjpath(aap,subj);
        
        % Preapare variables needed later
        EPIimg = cell(length(aap.acq_details.sessions), 1);
        sess4D = EPIimg;
        rEPIimg = EPIimg;
        movPars = EPIimg;
        
        for sess = aap.acq_details.selected_sessions %
            sess4D{sess} = aas_getsesspath(aap, subj, sess);
            
            % get files from stream
            EPIimg{sess} = strvcat2cell(aas_getimages_bystream(aap,subj,sess,'epi'));
            
            % Copy with a new prefix 'r'
            rEPIimg{sess} = aas_copy2prefix(EPIimg{sess}, 'r');
        end
        
        cEPIimg = [EPIimg{:}]';
        
        %% CONCATENATE DATA
        [data4D, subjMerged] = aas_3d4dmerge(aap, subjPth, mriname, cEPIimg);
        
        [pth, fn, ext] = fileparts(data4D);
        data4Drealigned = fullfile(pth, ['r' fn ext]);
        
        FSLcommand = sprintf('mcflirt -in %s -o %s %s -plots', ...
            data4D, ...
            data4Drealigned, ...
            aap.tasklist.currenttask.settings.MCFLIRToptions);
        disp(FSLcommand)
        [junk, w] = aas_runfslcommand(aap, FSLcommand);
        disp(w);
        
        % Split data back into original format...
        V = spm_vol(rEPIimg);
        V = [V{:}];
        rV = spm_vol(data4Drealigned);
        for f = 1:length(rV)
           Y = spm_read_vols(rV(f)); 
           spm_write_vol(V(f), Y);
        end
        
        % Cleanup...
        delete(data4D)
        delete(data4Drealigned)
        
        %% MEAN EPI
        [pth, fn, ext] = fileparts(data4Drealigned);
        [Mpth, Mfn] = fileparts(EPIimg{1}{1});
        mEPIimg = fullfile(Mpth, ['mean' Mfn ext]);
        movefile(fullfile(pth, [fn ext '_meanvol' ext]), mEPIimg);
        
        %% MOTION PARAMETERS
        FSLpars = load(fullfile(pth, [fn ext '.par']));
        FSLpars = [FSLpars(:,4:6) FSLpars(:,1:3)];
        ind = 0;
        for sess = aap.acq_details.selected_sessions
            V = spm_vol(rEPIimg{sess});
            currPars = FSLpars((ind+1) : (ind + length(V)), :);
            
            [Mpth, Mfn] = fileparts(EPIimg{sess}{1});
            movPars{sess} = fullfile(sess4D{sess}, ['rp_' Mfn '.txt']);
            
            save('-ascii', movPars{sess}, 'currPars');
            ind = ind + size(currPars, 1);
        end
        
        %% DESCRIBE OUTPUTS
        aap = aas_desc_outputs(aap,subj,'meanepi', mEPIimg);
        
        for sess = aap.acq_details.selected_sessions
            aap = aas_desc_outputs(aap,subj,sess,'epi',rEPIimg{sess});
            aap = aas_desc_outputs(aap,subj,sess,'realignment_parameter',movPars{sess});
        end
        
        % Sessionwise custom plot [TA]
        for sess = aap.acq_details.selected_sessions
            aas_plot_realignPars(aap, subj, sess, true);
        end
        
       %% DIAGNOSTICS
        mriname = aas_prepare_diagnostic(aap,subj);
        
        aas_realign_graph(movPars)
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_MP.jpeg']));
        
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
end
