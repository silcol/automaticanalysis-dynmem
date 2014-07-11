% AA module - Searchlight 1st level ==> THIS IS A FIRST LEVEL TASK
% You will need to make a local copy of this module into the same directory
%  as your user script, or somewhere else on your matlab path, and then modify it to
%  reflect the particular experiment you conducted
%
% Based on aa by Rhodri Cusack MRC CBU Mar 2006-Aug 2007
% Modified by Alejandro Vicente-Grabovetsky Dec-2008

function [aap,resp] = aamod_MVPaa_brain_SPM(aap,task,subj)

resp='';

switch task
    case 'doit'
        
        fprintf('Working with data from participant %s. \n',aap.acq_details.subjects(subj).mriname)
        instreams = aap.tasklist.currenttask.inputstreams.stream;
        
        Statistics = []; MVPaa_settings = [];
        load(aas_getfiles_bystream(aap,subj,'MVPaa_1st'));
        
        % get sn mat file from normalisation
        if aap.tasklist.currenttask.settings.normalise == 1
            normMAT = aas_getfiles_bystream(aap,subj,'normalisation_seg_sn');
        end
        
        % Example BET mask
        Mimg = aas_getfiles_bystream(aap, subj, 'epiBETmask');
        % Brain mask!
        for a = 1:size(Mimg,1)
            if ~isempty(strfind(Mimg(a,:), 'brain_mask'))
                Mimg = deblank(Mimg(a,:));
                break
            end
        end
        
        % FWHM in millimetres
        FWHMmm = aap.tasklist.currenttask.settings.FWHM;
        
        V = spm_vol(Mimg);
        
        %% GET MASK
        mask = spm_read_vols(V);
        % Remove stuff where we don't do stats!
        mask(or(~isfinite(Statistics(:,1,2)), Statistics(:,1,2)==0)) = 0;
        
        % Write out mask image containing only tested locations...
        V.fname = fullfile(aas_getsubjpath(aap,subj), 'mask.nii');
        V.dt(1) = 2;
        
        spm_write_vol(V, mask);
        
        %% GGM fit correction if necessary...
        
        if aap.tasklist.currenttask.settings.ggmfit == 1
            fprintf('GGMfit-ting T-values... \n')
            for c = 1:length(MVPaa_settings.contrasts)
                % Only non-zero non-nan values of image...
                M = and(isfinite(Statistics(:,c,2)), Statistics(:,c,2)~=0);
                
                % First we try the ggm model (Gaussian/Gamma)
                ggmmix = ggmfit(Statistics(M,c,2)', 3, 'ggm');
                
                % If this does not work, we try with gmm (Gaussian)
                if ~isfinite(ggmmix.mus(1)) || ggmmix.mus(1) == 0 ...
                        || ~isfinite(ggmmix.sig(1)) || ggmmix.sig(1) == 0
                    aas_log(aap,0,'Error in ggm, mu and/or sigma are NaN, trying ggm with 2 mixtures...')
                    ggmmix = ggmfit(Statistics(M,c,2)', 2, 'ggm');
                    
                    if isnan(ggmmix.mus(1)) || isnan(ggmmix.sig(1))
                        aas_log(aap,1,'Error in ggm, mu and/or sigma are NaN')
                    end
                end
                
                Statistics(M,c,2) = (Statistics(M,c,2) - ggmmix.mus(1)) ./ ggmmix.sig(1);
            end
        end
        
        %% WRITE .nii
        Statistics = reshape(Statistics, [V.dim(1), V.dim(2), V.dim(3), length(MVPaa_settings.contrasts), length(MVPaa_settings.tests)]);
        
        Flist = V.fname;
        V.dt(1) = 16; % Save in a format that accepts NaNs and negative values...
        
        fprintf('Saving images... \n')
        for c = 1:length(MVPaa_settings.contrasts)
            % Mean, median or beta
            V.fname = fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.nii', c));
            Flist = strvcat(Flist, V.fname);
            spm_write_vol(V, squeeze(Statistics(:,:,:,c,1)));
            
            % T-value
            V.fname = fullfile(aas_getsubjpath(aap,subj), sprintf('spmT_%04d.nii', c));
            Flist = strvcat(Flist, V.fname);
            spm_write_vol(V, squeeze(Statistics(:,:,:,c,2)));
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
        
        % Remove spmT images from Clist
        Clist = Flist;
        for f = size(Clist,1):-1:1
            if ~isempty(strfind(Clist(f,:), 'spmT_')) || ~isempty(strfind(Clist(f,:), 'mask'))
                Clist(f,:) = [];
            end
        end
        
        % Remove spmT images from Clist
        Slist = Flist;
        for f = size(Slist,1):-1:1
            if ~isempty(strfind(Slist(f,:), 'con_')) || ~isempty(strfind(Slist(f,:), 'mask'))
                Slist(f,:) = [];
            end
        end
        
        %% Modify SPM!
        % Load SPM used for this analysis...
        if any(strcmp(instreams, 'firstlevel_spm'))
            load(aas_getfiles_bystream(aap, subj, 'firstlevel_spm'));
            
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
                spm_vol(fullfile(aas_getsubjpath(aap,subj), 'con_0001.nii')), ...
                SPM.xVol.FWHM)';
            
            % Included voxels
            [X Y Z] = ind2sub(SPM.xVol.DIM',find(mask));
            SPM.xVol.XYZ = [X';Y';Z'];
            
            % Length of voxels in analysis
            SPM.xVol.S = length(X);
            
            % Filehandle of resels per voxel image (i.e. none!)
            SPM.xVol.VRpv = [];
            
            for c = 1:length(MVPaa_settings.contrasts)
                % SPM.xCon (.name)
                SPM.xCon(c).name = MVPaa_settings.contrasts(c).name;
                SPM.xCon(c).STAT = 'T';
                SPM.xCon(c).c = ones(size(SPM.xX.X,2),1);
                SPM.xCon(c).eidf = 1;
                SPM.xCon(c).Vcon = spm_vol(fullfile(aas_getsubjpath(aap,subj), sprintf('con_%04d.nii', c)));
                SPM.xCon(c).Vspm = spm_vol(fullfile(aas_getsubjpath(aap,subj), sprintf('spmT_%04d.nii', c)));
            end
            
            % Save SPM
            save(fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'), 'SPM');
        else
            fake_SPM(Slist, Clist, 1, aas_getsubjpath(aap,subj))
        end
        
        %% DESCRIBE OUTPUTS
        aap=aas_desc_outputs(aap,subj,'firstlevel_spm', fullfile(aas_getsubjpath(aap,subj), 'SPM.mat'));
        aap=aas_desc_outputs(aap,subj,'firstlevel_cons', Clist);
        aap=aas_desc_outputs(aap,subj,'firstlevel_spmts', Slist);
end