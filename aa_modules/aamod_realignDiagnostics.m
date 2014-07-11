% AA module - realignment and unwarp
% As done at the DCCN (Donders Centre for Cognitive Neuroscience)
% [aap,resp]=aamod_realignunwarpDCCN(aap,task,subj)
% Realignment using SPM5
% i=subject num
% Based on aamod_realignunwarp by Rhodri Cusack MRC CBU 2004-6
% Alejandro Vicente Grabovetsky Jan-2012

function [aap,resp]=aamod_realignDiagnostics(aap,task,subj)

resp='';

switch task
    case 'doit'
  
        mvmean=[];
        mvmax=[];
        mvstd=[];
        mvall=[];
        nsess=length(aap.acq_details.sessions);
        
        qq=[];
        
        % @@@ NEED TO CHANGE THIS... for aa4... @@@
        for sess=1:nsess
            
            % load mov-pars
            move_filenames{sess}= aas_getfiles_bystream(aap,subj,sess,'realignment_parameter');
            move_txt_file{sess} = move_filenames{sess}(1,:);
%             mvpars = load(f_name);
            
%             im1fn=aas_getimages(aap,subj,sess,aap.tasklist.currenttask.epiprefix,aap.acq_details.numdummies,1+aap.acq_details.numdummies);
%             im1v=spm_vol(im1fn);
%             qq(sess,:)     = spm_imatrix(im1v.mat);
%             rpfn=spm_select('list',aas_getsesspath(aap,subj,sess),'^rp.*txt');
%             mv=spm_load(fullfile(aas_getsesspath(aap,subj,sess),rpfn));
%             mv=mv+repmat(qq(sess,1:6)-qq(1,1:6),[size(mv,1) 1]);
%             mv(:,4:6)=mv(:,4:6)*180/pi; % convert to degrees!
%             mvmean(sess,:)=mean(mv);
%             mvmax(sess,:)=max(mv);
%             mvstd(sess,:)=std(mv);
%             mvall=[mvall;mv];
        end        
        % Make figures
        aas_realign_graph(move_txt_file);
                   
         % Save graphical output to common diagnostics directory
        if ~exist(fullfile(aap.acq_details.root, 'diagnostics'), 'dir')
            mkdir(fullfile(aap.acq_details.root, 'diagnostics'))
        end

        [~, mriname] = fileparts(aas_getsubjpath(aap,subj));
        print('-dpng','-r200',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.png']));
        
            
    case 'checkrequirements'
        aas_log(aap,0,'will plot diagnostics for movement \n' );
        
end