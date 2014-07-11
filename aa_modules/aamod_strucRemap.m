function [aap,resp]=aamod_strucRemap(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        % Load the Structural
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        if size(Simg,1) > 1
            Simg = deblank(Simg(aap.tasklist.currenttask.settings.structural, :));
            aas_log(aap, false, sprintf('Found more than 1 structural images, using structural %d\n', ...
                aap.tasklist.currenttask.settings.structural));
        end
        Simg = strvcat2cell(Simg);
        
        %% CONVERT STRUCTURALs TO "1x1x1" mm
        V = spm_vol(Simg{aap.tasklist.currenttask.settings.structural(1)});
        
        % Get centre of mass of the image, that's where the brain is, most likely...
        coords = img2bestFOV(Simg{aap.tasklist.currenttask.settings.structural(1)}, aap.tasklist.currenttask.settings.newVoxFOV);
        
        selectC = cell(2,3); % Mapping of voxels in one to the other...
        
        for d = 1:3
            sizeD = aap.tasklist.currenttask.settings.newVoxFOV(d) - V.dim(d);
            
            if sizeD == 0;
                selectC{1,d} = 1:aap.tasklist.currenttask.settings.newVoxFOV(d);
                selectC{2,d} = 1:V.dim(d);
            elseif sizeD > 0
                selectC{1,d} = floor(sizeD/2) + (1:V.dim(d));
                selectC{2,d} = 1:V.dim(d);
            elseif sizeD < 0
                selectC{1,d} = 1:aap.tasklist.currenttask.settings.newVoxFOV(d);
                selectC{2,d} = round(coords(d) - aap.tasklist.currenttask.settings.newVoxFOV(d)/2) + (1:aap.tasklist.currenttask.settings.newVoxFOV(d));
                
                if max(selectC{2,d}) > V.dim(d)
                    selectC{2,d} = selectC{2,d} - (max(selectC{2,d}) - V.dim(d));
                elseif min(selectC{2,d}) < 1
                    selectC{2,d} = selectC{2,d} + (1 - min(selectC{2,d}));
                end
            end
        end
        
        mmVox = vox2mm(V);
        if isempty(aap.tasklist.currenttask.settings.newVoxFOV)
            aap.tasklist.currenttask.settings.newVoxFOV = mmVox;
        end
        
        for s = 1:length(Simg)
            V = spm_vol(Simg{s});
            Y = spm_read_vols(V);
            
            %% TRANSFORM THE MATRICES...
            M = zeros(aap.tasklist.currenttask.settings.newVoxFOV);
            
            mV = V;
            mV.dim = aap.tasklist.currenttask.settings.newVoxFOV;
            
            % In terms of the sign and assignment of values?
            % [CAN WE MAKE THIS MORE GENRAL?] @@@
            mV.mat(1,4) = mV.mat(1,4) + ...
                (selectC{2,3}(1) - selectC{1,3}(1)) * mmVox(3) ...
                - (aap.tasklist.currenttask.settings.newVoxSize(3) - mmVox(3)) ...
                * aap.tasklist.currenttask.settings.newVoxFOV(3) / 2;
            mV.mat(2,4) = mV.mat(2,4) - ...
                (selectC{2,1}(1) - selectC{1,1}(1)) * mmVox(1)...
                + (aap.tasklist.currenttask.settings.newVoxSize(1) - mmVox(1)) ...
                * aap.tasklist.currenttask.settings.newVoxFOV(1) / 2;
            mV.mat(3,4) = mV.mat(3,4) + ...
                (selectC{2,2}(1) - selectC{1,2}(1)) * mmVox(2)...
                - (aap.tasklist.currenttask.settings.newVoxSize(2) - mmVox(2)) ...
                * aap.tasklist.currenttask.settings.newVoxFOV(2) / 2;
            
            % Make scaling matrix:
            scalMat = zeros(4,4);
            scalMat(1,1) = aap.tasklist.currenttask.settings.newVoxSize(1) ./ mmVox(1);
            scalMat(2,2) = aap.tasklist.currenttask.settings.newVoxSize(2) ./ mmVox(2);
            scalMat(3,3) = aap.tasklist.currenttask.settings.newVoxSize(3) ./ mmVox(3);
            scalMat(4,4) = 1;
            
            mV.mat = mV.mat*scalMat;
            
            % Put locations in the correct position...
            M(selectC{1,1}, selectC{1,2}, selectC{1,3}) = ...
                Y(selectC{2,1}, selectC{2,2}, selectC{2,3});
            
            %% TRANSFORM THE SPACE...
            spm_write_vol(mV,M);
        end
        
        %% DIAGNOSTICS
        mriname = aas_prepare_diagnostic(aap,subj);
        
        spm_check_registration(Simg{aap.tasklist.currenttask.settings.structural(1)}
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '.jpeg']));
        
        %% DESCRIBE OUTPUTS
        aap=aas_desc_outputs(aap,subj,'structural',Simg);
        
end
end