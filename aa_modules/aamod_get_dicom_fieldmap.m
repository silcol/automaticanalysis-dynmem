% This module finds all of the DICOM files associated with the fieldmaps
% using aas_listdicomfiles, and copies them into the session directory of
% this module, either across the local filesystem or from s3. It then
% creates the output stream.
% function aap=aamod_get_dicom_fieldmap(aap,task,subj)

function [aap resp]=aamod_get_dicom_fieldmap(aap,task,subj)
global aaworker

resp='';

switch task
    case 'description'
        resp=sprintf('Getting fieldmaps DICOM files');
        
    case 'summary'
        resp=sprintf('Getting fieldmaps DICOM files\n');
        
    case 'report'
    case 'doit'
        subjpath=aas_getsubjpath(aap,subj);
        fieldpath=fullfile(subjpath,aap.directory_conventions.fieldmapsdirname);
        
        fieldfolds = {'rawmag' 'rawphase'};
        
        % Manually specified value for fieldmaps series number over-rides automatically scanned value
        if (~isempty(aap.acq_details.subjects(subj).fieldmaps))
            fieldseries=aap.acq_details.subjects(subj).fieldmaps;
        else
            % Load up automatically scanned value, validate
            aisfn=fullfile(subjpath,'autoidentifyseries_saved.mat');
            ais=load(aisfn);
            fieldseries = ais.series_newfieldmap;
            if length(fieldseries)>aap.options.autoidentifyfieldmaps_number
                if aap.options.autoidentifyfieldmaps_choosefirst
                    fieldseries = fieldseries(...
                        1:aap.options.autoidentifyfieldmaps_number);
                elseif aap.options.autoidentifyfieldmaps_chooselast
                    fieldseries = fieldseries(...
                    (end-aap.options.autoidentifyfieldmaps_number+1):end);
                else
                    aas_log(aap,true,sprintf('Was expecting only %d fieldmaps, but autoidentify series found %d. Add extras to ignoreseries or use the choosefirst/chooselast options.',...
                        aap.options.autoidentifyfieldmaps_number,...
                        length(ais.series_newfieldmap)));
                end
            end
        end
        
        dicom_files_src = {};
        % Go through each fieldmap
        out=[];
        for seriesind=1:length(fieldseries)
            [aap dicom_files_src]=aas_listdicomfiles(aap,subj,fieldseries(seriesind));
            
            % Now copy files to this module's directory
            % (support multiple fieldmap acquisitions)
            ffold = fieldfolds{1+rem(1+seriesind,2)};
            % fieldmap toolbox takes a directory as input so must ensure
            % each session/ffold combo has its own dir
            outdir = fullfile(fieldpath,sprintf('%d_%s',...
                fieldseries(seriesind),ffold));
            aas_makedir(aap,outdir);
            outstream={};
            switch(aap.directory_conventions.remotefilesystem)
                case 'none'
                    for ind=1:length(dicom_files_src)
                        [success,msg,msgid] = copyfile(deblank(...
                            dicom_files_src{ind}),outdir);
                        % allow copyfile failures due to permissions issues
                        % (e.g. if copying from networked system)
                        assert(success || strfind(msg,'chflags'),...
                            'copyfile failed!')
                        [pth nme ext]=fileparts(dicom_files_src{ind});
                        outstream{ind}=fullfile(outdir,[nme ext]);
                    end;
                case 's3'
                    s3fles={};
                    for ind=1:length(dicom_files_src)
                        [pth nme ext]=fileparts(dicom_files_src{ind});
                        s3fles=[s3fles [nme ext]];
                        outstream{ind}=fullfile(outdir,s3fles{ind});
                    end;
                    s3_copyfrom_filelist(aap,outdir,s3fles,aaworker.bucketfordicom,pth);
            end;
            out=[out outstream];
        end;
        
        aap=aas_desc_outputs(aap,subj,'dicom_fieldmap',out);
end;
