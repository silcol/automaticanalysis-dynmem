% AA module
% High pass filter a timeseries of data

function [aap,resp]=aamod_highpass(aap,task,subj,sess)

resp='';

switch task
    case 'domain'
        resp='session';  % this module needs to be run once per subject
        
    case 'description'
        resp='SPM highpass filter';
        
    case 'summary'
        subjpath=aas_getsubjpath(subj);
        resp=sprintf('\n\tHighpass %s\n',subjpath);
        
    case 'report'
        
    case 'doit'
        
        EPIimg = aas_getfiles_bystream(aap,subj,sess,'epi');
        
        % Copy with a new prefix 'h'
        hEPIimg = aas_copy2prefix(EPIimg, 'h');
        
        V = spm_vol(hEPIimg);
                
        %% retrieve TR from DICOM header & set up the HiPass filter
        % if TR is manually specified (not recommended as source of error)
        if (isfield(aap.tasklist.currenttask.settings,'TR'))
            K.RT = aap.tasklist.currenttask.settings.TR;
        else
            % Get TR from DICOM header
            DICOMHEADERS=load(aas_getfiles_bystream(aap,subj,sess,'epi_dicom_header'));
            K.RT = DICOMHEADERS.DICOMHEADERS{1}.volumeTR;
        end
        
        % High pass filter or detrend data
        
        % Let's first set up the parameters...
        K.row = 1:length(V);
        K.HParam = aap.tasklist.currenttask.settings.HParam; % cut-off period in seconds
        
        if K.RT * length(K.row) < K.HParam && ~strcmp(aap.tasklist.currenttask.settings.HFtype, 'detrend')
            aas_log(aap, true, 'The data length is shorter than the cutoff of the filter, consider detrending instead')
        end
        
        if K.RT * length(K.row) > K.HParam
            fprintf('\nWill do high pass filtering of time series with a %d second cut-off', K.HParam)
        else
            fprintf('\nWill do linear detrending across time series')
        end
        
        %% If the dataset is too large, we process it by chunks...
        fprintf('\n\tProcessing data (%d scans)', length(V))
        
        taskComplete = 0;
        chunkDim = aap.tasklist.currenttask.settings.chunks;
        
        while taskComplete == 0
            fprintf('\nTrying with %d chunks', chunkDim)
            
            try
                chunkX = 0;
                chunkY = 0;
                chunkZ = 0;
                for c = 1:chunkDim
                    chunkX = [chunkX floor(V(1).dim(1) * c / chunkDim)];
                    chunkY = [chunkY floor(V(1).dim(2) * c / chunkDim)];
                    chunkZ = [chunkZ floor(V(1).dim(3) * c / chunkDim)];
                end
                
                oldTrend = 0; newTrend = 0;
                
                % Chunking...
                for x = 1:length(chunkX) - 1
                    for y = 1:length(chunkY) - 1
                        for z = 1:length(chunkZ) - 1
                            fprintf('\n\t...chunk %d %d %d', x, y, z)
                            Xind = chunkX(x) + 1 : chunkX(x+1);
                            Yind = chunkY(y) + 1 : chunkY(y+1);
                            Zind = chunkZ(z) + 1 : chunkZ(z+1);
                            
                            EPIdata = zeros(length(V), length(Xind), ...
                                length(Yind), ...
                                length(Zind));
                            
                            % Load each image into 4-D matrix
                            for e = 1:length(V)
                                Y = spm_read_vols(V(e));
                                EPIdata(e,:,:,:) = Y(Xind,Yind,Zind);
                            end
                            
                            if strcmp(aap.tasklist.currenttask.settings.HFtype, 'spm')
                                % Create the frequencies to be removed and apply them...
                                % Important: first dimension must be time dimension!
                                
                                EPIdata = spm_filter(K, EPIdata);
                                
                            elseif strcmp(aap.tasklist.currenttask.settings.HFtype, 'detrend')
                                % Use linear detrending instead (might be slower due to loops)
                                
                                szY=size(EPIdata);
                                Y=reshape(EPIdata,[length(V) prod(szY(2:4))]);
                                mY = repmat(mean(Y,1), [length(V) 1]);
                                % Add mean back after detrending!
                                Y=detrend(Y)+mY;
                                EPIdata = reshape(Y,szY);
                                
                            elseif strcmp(aap.tasklist.currenttask.settings.HFtype, 'butterworth')
                                % Regress out discrete cosine components to do filtering
                                
                                szY=size(EPIdata);
                                Y=reshape(EPIdata,[length(V) prod(szY(2:4))]);
                                X0 = spm_dctmtx( length(V), ...
                                    fix(2*(length(V) * K.RT) / aap.tasklist.currenttask.settings.HParam + 1));
                                X0 = X0(:,2:end);
                                beta = X0\Y;
                                Y = Y-X0*beta;
                                EPIdata = reshape(Y,szY);                                
                            end
                                                        
                            % Now save the data back...
                            for e = 1:length(V)
                                Y = spm_read_vols(V(e));
                                Y(Xind,Yind,Zind) = EPIdata(e,:,:,:);
                                spm_write_vol(V(e),Y);
                            end
                        end
                    end
                end
                % If we get here, then we completed the task...
                taskComplete = 1;
            catch aa_error
                %disp(tSNR_error)
                
                if x > 1 || y > 1 || z > 1
                    aas_log(aap, true, 'The script broke between chunks, you should delete the subject folder for this module and try again...')
                end
                
                if chunkDim > 4
                    aas_log(aap, true, 'Error is probably not due to MEMORY')
                end
                
                chunkDim = chunkDim + 1;
            end
        end
        clear EPIdata
        
        %% DIAGNOSTICS
        mriname = aas_prepare_diagnostic(aap, subj);
                
        h = img2deltaseries(EPIimg, hEPIimg, {'Unfiltered', 'Filtered', 'Delta'});
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_' aap.acq_details.sessions(sess).name '.jpeg']));
        close(h); 
        
        %% DESCRIBE THE OUTPUTS
        
        aap=aas_desc_outputs(aap,subj, sess, 'epi', hEPIimg);
        
end
