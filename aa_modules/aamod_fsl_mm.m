% AA module
% Runs BET (FSL Brain Extration Toolbox) on structural (usually)
% [For best functionality, it is recommended you run this after
% realignment and before writing the normalised EPI image
% If you do it before estimating the normalisation, make sure you normalise
% to a scull-stripped template, if at all possible!]

function [aap,resp]=aamod_fsl_mm(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        
        % Find out what stream we should BET
        inputstream = aap.tasklist.currenttask.inputstreams.stream;
        
        TstatStream = inputstream{:};
        
        % Get the images (and get rid of headers...)
        if (exist('subj','var'))
            Timg = aas_getfiles_bystream(aap,subj, TstatStream);
        else
            Timg = aas_getfiles_bystream(aap, TstatStream);
        end
        
        Timg = aas_ignore_hdr(Timg);
        
        [Tpth, Tfn, Text] = fileparts(Timg(1,:));
        
        % Copy statistic image to later make "mask"
        Mimg = fullfile(Tpth, 'mask.nii');
        V = spm_vol(Timg(1,:));
        Y = spm_read_vols(V);
        V.fname = Mimg;
        spm_write_vol(V,Y);
        Mimg = img2mask(Mimg, 'abs', 0);
        
        % How much memory/time will we need for torque?
        img_size = V.dim(1) * V.dim(2) * V.dim(3);
        
        FSLcommandCell = cell(size(Timg,1), 1);
        aapCell = cell(size(Timg,1), 1);
        for t = 1:size(Timg,1)
            [Tpth, Tfn, Text] = fileparts(Timg(t,:));
            
            FSLcommandCell{t} = sprintf('mm --mask=%s --sdf=%s --logdir=%s %s', ...
                Mimg, deblank(Timg(t,:)) , fullfile(Tpth, [Tfn '_logdir']), ...
                aap.tasklist.currenttask.settings.options);
            aapCell{t} = aap;
        end
        
        % Run MM
        switch aap.tasklist.currenttask.settings.parallel
            case {'none', 'serial'}
                for t = 1:size(Timg,1)
                    fprintf('Running FSL Spatial Mixture Modelling for image %d/%d \n', t, size(Timg,1))
                    
                    [s, w] = aas_runfslcommand(aap, FSLcommandCell{t});
                end
            case 'torque'
                memreq = 640 * img_size;
                timreq = 0.005 * img_size;
                aas_log(aap, false, sprintf('Submitting jobs with %0.2f MB and %0.2f hours', ...
                    memreq/(1024^2), timreq/3600))
                
                [s, w] = qsubcellfun(@aas_runfslcommand, ...
                    aapCell, FSLcommandCell, ...
                    'memreq', int32(memreq), ...
                    'timreq', int32(timreq), ...
                    'stack', 1 ...
                    );
            otherwise
                error('Select correct serial/parallel execution mode')
        end
        
        % Delete voluminous, but useless stuff
        unix(['rm -rf ' fullfile(Tpth, '*_logdir/*samples*.nii')])
        
        %% DESCRIBE OUTPUTS!
        %{
        aap=aas_desc_outputs(aap,subj,'fsl_mm', outStruct);
        %}
end
