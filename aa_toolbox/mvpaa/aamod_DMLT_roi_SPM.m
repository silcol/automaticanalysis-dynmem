% AA module - Searchlight 1st level ==> THIS IS A FIRST LEVEL TASK
% You will need to make a local copy of this module into the same directory
%  as your user script, or somewhere else on your matlab path, and then modify it to
%  reflect the particular experiment you conducted
%
% Based on aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Modified by Alejandro Vicente-Grabovetsky Dec-2008

function [aap,resp] = aamod_DMLT_roi_SPM(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        fprintf('Working with data from participant %s. \n',aap.acq_details.subjects(subj).mriname)
        
        DMLT = []; EP = []; DMLout = [];
        load(aas_getfiles_bystream(aap,subj,'DMLT'));
        
        % get sn mat file from normalisation
        if aap.tasklist.currenttask.settings.normalise == 1
            normMAT = aas_getfiles_bystream(aap,subj,'normalisation_seg_sn');
        end
        
        % Load SPM used for this analysis...
        load(aas_getfiles_bystream(aap, subj, 'firstlevel_spm'));
        
        % Example BET mask
        Mimg = aas_getfiles_bystream(aap, subj, 'epiBETmask');
        % Brain mask!
        for a = 1:size(Mimg,1)
            if ~isempty(strfind(Mimg(a,:), 'brain_mask'))
                Mimg = deblank(Mimg(a,:));
                break
            end
        end
        V = spm_vol(Mimg);
        
        % FWHM in millimetres
        FWHMmm = aap.tasklist.currenttask.settings.FWHM;
        
        %% WRITE .img
        % Let's do things for each ROI and each contrast...
        fprintf('Saving images... \n')
        Flist = '';
        for r = 1:size(DMLout, 1)
            for c = 1:size(DMLout, 2)
                indx = (r - 1) * size(DMLout, 2) + c;
                
                % Absolute weights of subject...
                V.fname = fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.img', indx));
                Flist = strvcat(Flist, V.fname);
                
                Y = DMLout{r,c}.weights;
                Y(Y==0) = -eps; % Let's not have 0 anywhere...
                spm_write_vol(V, Y);
            end
        end
        
        %% NORMALISE
        if aap.tasklist.currenttask.settings.normalise == 1
            fprintf('Normalising images... \n')
            
            normPars = aap.spm.defaults.normalise.write;
            normPars.prefix = ''; % We want to keep no prefix...
            
            % This automatically reslices images to warped size
            spm_write_sn(Flist, normMAT, normPars);
        end
        
        %% SMOOTH IMAGES
        if FWHMmm > 0
            fprintf('Smoothing images... \n')
            for f = 2:size(Flist,1);
                Q = Flist(f,:);
                U = Flist(f,:); % No prefixes!
                spm_smooth(Q,U,FWHMmm);
            end
        end
        
        %% MASK SMOOTHED IMAGES!
        % Included mask to mask out untested data
        fprintf('NaNing untested voxels... \n')
        
        mask = spm_read_vols(spm_vol(Flist(1,:)));
        mask = mask > 0;
        
        for f = 2:size(Flist,1)
            V = spm_vol(Flist(f,:));
            Y = spm_read_vols(V);
            if strfind(Flist(f,:), 'spmT')
                % Zero mask in statistics...
                Y(~mask) = 0;
                Y(isnan(Y)) = 0;
            elseif strfind(Flist(f,:), 'con')
                % NaN mask in statistics...
                Y(~mask) = NaN;
            end
            spm_write_vol(V, Y);
        end
        
        %% Modify SPM!
        % Clear SPM.xCon
        SPM.xCon = [];
        
        % Set correct path
        SPM.swd = aas_getsubjpath(aap,subj);
        
        % Set world coordinates for visualisation...
        % ...which should already be found in the images...
        SPM.xVol.M = V.mat;
        SPM.xVol.iM = inv(SPM.xVol.M);
        
        % Size of the volume
        SPM.xVol.DIM = V.dim';
        
        % Smoothness of the volume...
        % ...Get the number of mm per voxel...
        mmVox = vox2mm(V);
        % ...then get the FWHM
        if FWHMmm < min(mmVox./2) % To avoid errors...
            FWHMmm = min(mmVox./2);
        end
        SPM.xVol.FWHM = [FWHMmm FWHMmm FWHMmm];
        SPM.xVol.FWHM = SPM.xVol.FWHM ./ mmVox;
        
        % Spm_resels_vol function
        % NOTE: This is probably not valid for FWE still, since the
        % searchlight procedure means each voxels is already "smoothed" to
        % some extent...
        SPM.xVol.R = spm_resels_vol( ...
            spm_vol(fullfile(aas_getsubjpath(aap,subj), 'con_0001.img')), ...
            SPM.xVol.FWHM)';
        
        % Included voxels
        [X Y Z] = ind2sub(SPM.xVol.DIM',find(mask));
        SPM.xVol.XYZ = [X';Y';Z'];
        
        % Length of voxels in analysis
        SPM.xVol.S = length(X);
        
        % Filehandle of resels per voxel image (i.e. none!)
        SPM.xVol.VRpv = [];
        
        for r = 1:size(DMLout, 1)
            for c = 1:size(DMLout, 2)
                indx = (r - 1) * size(DMLout, 2) + c;
                
                % SPM.xCon (.name)
                SPM.xCon(indx).name = DMLT(c).name;
                SPM.xCon(indx).STAT = 'T';
                SPM.xCon(indx).c = ones(size(SPM.xX.X,2),1);
                SPM.xCon(indx).eidf = 1;
                SPM.xCon(indx).Vcon = spm_vol(fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.img', indx)));
                SPM.xCon(indx).Vspm = '';
            end
        end
        
        % Save SPM
        save(fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'), 'SPM');
        
        %% DESCRIBE OUTPUTS
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm', fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'));
        
        % Add headers to list of files...
        for f = 1:size(Flist,1)
            [Froot, Ffn, Fext] = fileparts(Flist(f,:));
            Flist = strvcat(Flist, fullfile(Froot, [Ffn '.hdr']));
        end
        aap=aas_desc_outputs(aap,subj,'firstlevel_cons', Flist);
end