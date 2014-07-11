% average RDMs for each searchlight 
% [aap,resp]=aamod_pilab_searchlight_rdms_average(aap,task,subj)
function [aap,resp]=aamod_pilab_searchlight_rdms_average(aap,task,subj)

resp='';

switch task
    case 'doit'
        % get RDMs
        sessrdmpath = aas_getfiles_bystream(aap,subj,'pilab_data_rdms_sess');
        meanrdmpath = aas_getfiles_bystream(aap,subj,'pilab_data_rdms_mean');
        meanrdms = loadbetter(meanrdmpath);

        % get searchlights
        spherepath = aas_getfiles_bystream(aap,subj,...
            'pilab_rois');
        spheres = loadbetter(spherepath);

        % check that parfor is available
        if ~matlabpool('size')
            try
                matlabpool('local');
            catch
                warning('no matlabpool available')
            end
        end

        % process mean
        meanrdms.data = averagesearchlights(meanrdms.data,spheres.data);
        save(meanrdmpath,'meanrdms');
        aap=aas_desc_outputs(aap,subj,'pilab_data_rdms_mean',...
            meanrdmpath);

        nsess = size(sessrdmpath,1);
        if nsess==1
            % can just shortcut this since it would produce identical
            % output
            save(sessrdmpath,'meanrdms');
        else
            % otherwise, iterate over sessions...
            for s = 1:nsess
                sessrdms = loadbetter(sessrdmpath(s,:));
                sessrdms.data = averagesearchlights(sessrdms.data,...
                    spheres.data);
                save(sessrdmpath(s,:),'meanrdms');
            end
        end
        aap=aas_desc_outputs(aap,subj,'pilab_data_rdms_sess',...
            sessrdmpath);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
