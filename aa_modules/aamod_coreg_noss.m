% AA module - coregister structural to mean EPI
% Coregistration of structural to mean EPI output by realignment
% Does not require skull stripping any more
% Modified for sparse imaging since prefix for mean is different
% subj=subject num
% Rhodri Cusack MRC CBU 2004-6 based on original by Matthew Brett
%
% Major changes Aug 2010: removed support for central store of structrual
% images. This code was very long in tooth, and unloved.
%
% Tibor Auer MRC CBU Cambridge 2012-2013

function [aap,resp]=aamod_coreg_noss(aap,task,subj)

resp='';

switch task
    case 'report' % [TA]
        if ~exist(fullfile(aas_getsubjpath(aap,subj),['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_structural2meanepi.jpg']),'file')
            aas_fsl_coreg_diag(aap,subj);
        end
        fdiag = dir(fullfile(aas_getsubjpath(aap,subj),'diagnostic_*.jpg'));
        for d = 1:numel(fdiag)
            aap = aas_report_add(aap,subj,'<table><tr><td>');
            aap=aas_report_addimage(aap,subj,fullfile(aas_getsubjpath(aap,subj),fdiag(d).name));
            aap = aas_report_add(aap,subj,'</td></tr></table>');
        end
    case 'doit'
        global defaults;
        flags = defaults.coreg;
        % check local structural directory exists
        subjpath=aas_getsubjpath(aap,subj);
        
        structdir=fullfile(subjpath,aap.directory_conventions.structdirname);
        if (~length(dir(structdir)))
            [s w]=aas_shell(['mkdir ' structdir]);
            if (s)
                aas_log(aap,1,sprintf('Problem making directory%s',structdir));
            end;
        end;
        
        % dirnames,
        % get the subdirectories in the main directory
        dirn = aas_getsesspath(aap,subj,1);
        % get mean EPI stream
        % (looks like getimages is not functional at the moment)
        PG = aas_getfiles_bystream(aap,subj,'meanepi');
        if size(PG,1) > 1
            aas_log(aap, false, 'Found more than 1 mean functional images, using first.');
            PG = deblank(PG(1,:));
        end
        VG = spm_vol(PG);
        
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        if size(Simg,1) > 1
            aas_log(aap, false, sprintf('Found more than 1 structural images, using structural %d', ...
                aap.tasklist.currenttask.settings.structural));
        end
        VF = spm_vol(Simg);
        
        % do coregistration
        x  = spm_coreg(VG, VF,flags.estimate);
        
        M  = inv(spm_matrix(x));
        
        spm_get_space(Simg, M*spm_get_space(Simg));
        
        aap = aas_desc_outputs(aap,subj,'structural',Simg);
        
        % Save graphical output - this will now be done by report task
        try
            figure(spm_figure('FindWin', 'Graphics'));
        catch
            figure(1);
        end;
        print('-djpeg','-r150',fullfile(aas_getsubjpath(aap,subj),'diagnostic_aamod_coreg'));
        
        % Reslice images for diagnostics...
        aas_fsl_coreg_diag(aap,subj);
        
    case 'checkrequirements'
        
end
end
