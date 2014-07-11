% AA initialisation module - Identify dicom headers from Tim Trio
% Rhodri Cusack MRC CBU Cambridge Dec 2005

function  [aap,resp]=aamod_autoidentifyseries_timtrio(aap,task,subj)

resp='';

switch task
    case 'summary'
        resp=[];
        numresp=0;
        if (aap.options.autoidentifyfieldmaps)
            resp{1}='fieldmaps';
            numresp=numresp+1;
        end
        if (aap.options.autoidentifystructural)
            resp{numresp}='structural';
            numresp=numresp+1;
        end
        if (aap.options.autoidentifytmaps)
            resp{numresp}='realtime t-maps';
            numresp=numresp+1;
        end
        switch (numresp)
            case 0
                resp=['No automatic identification done.'];
            case 1
                resp=['Automatically identified ' resp{1} '\n'];
            case 2
                resp=['Automatically identified ' resp{1} ' and ' resp{2} '\n'];
            case 3
                resp=['Automatically identified ' resp{1} ', ' resp{2} ' and ' resp{3} '\n'];
        end
    case 'report'
        
    case 'doit'
        global aaworker
        dontrescan=false;
        aisfn=fullfile(aas_getsubjpath(aap,subj),'autoidentifyseries_saved.mat');
        
        % Get a listing of all of the series for this subject
        rawdata_subj=fullfile(aap.directory_conventions.rawdatadir,aap.acq_details.subjects(subj).mriname);
        switch (aap.directory_conventions.remotefilesystem)
            case 'none'
                % Looks for DICOMs in here and in all subdirectories
                allpths=genpath(rawdata_subj);
                serieslist=[];
                acqlist=[];
                alldicomfiles={};
                while (length(allpths)>0)
                    [thispth allpths]=strtok(allpths,':');
                    if (isempty(thispth)) 
                        break;
                    end
                    fn=dir(fullfile(thispth,aap.directory_conventions.dicomfilter));
                    for fnind=1:length(fn)
                        if (~fn(fnind).isdir)
                            fullfn=fullfile(thispth,fn(fnind).name);
                            H=aas_dicom_headers_light(fullfn);
                            if (isfield(H{1},'SeriesNumber') && isfield(H{1},'AcquisitionNumber'))
                                serieslist=[serieslist H{1}.SeriesNumber];
                                acqlist=[acqlist H{1}.AcquisitionNumber];
                                if (H{1}.SeriesNumber>length(alldicomfiles))
                                    alldicomfiles{H{1}.SeriesNumber}=[];
                                end
                                alldicomfiles{H{1}.SeriesNumber}{end+1}=fullfn;
                            end
                        end
                    end
                    
                end
                
                rawdata_allseries=unique(serieslist);
                disp(rawdata_allseries)
                
                for sess=1:length(rawdata_allseries)
                    H=aas_dicom_headers_light(alldicomfiles{rawdata_allseries(sess)}{1});
                    aas_log(aap,false,sprintf('Series %d with %d dicom files [%s]', ...
                        rawdata_allseries(sess), ...
                        length(alldicomfiles{rawdata_allseries(sess)}), ...
                        H{1}.SeriesDescription)); 
                end
            case 's3'
                % Use delimiter to get series names as CommonPrefixes
                [aap s3resp]=s3_list_objects(aap,aaworker.bucketfordicom,rawdata_subj,[],'/');
                rawdata_allseries={s3resp.CommonPrefixes.Prefix};
        end
        
        series_spgr=[];
        series_newfieldmap=[];
        series_tmaps=[];
        
        filenumber=0;
        
        tmpdir=aas_gettempfilename();
        
        protocolnames=[];
        
        % Go through each series, and examine type
        for sess=1:length(rawdata_allseries)
            % Get the path to a single dicom file from series "sess", downloading from S3 first if necessary
            switch(aap.directory_conventions.remotefilesystem)
                case 's3'
                    seriespth=rawdata_allseries{sess};
                    while (seriespth(end)==filesep)
                        seriespth=seriespth(1:(end-1));
                    end
                    [pth nme ext]=fileparts(seriespth);
                    dicomseriesname=[nme ext];
                    searchpath=fullfile(rawdata_subj,dicomseriesname);
                    aas_log(aap,false,sprintf('Checking here on s3 %s',searchpath));
                    [aap s3resp]=s3_list_objects(aap,aaworker.bucketfordicom,searchpath,[],[],1);
                    
                    [keypth nme ext]=fileparts(s3resp.Contents(1).Key);
                    dicomfilename=[nme ext];
                    s3_copyfrom_filelist(aap,tmpdir,dicomfilename,aaworker.bucketfordicom,keypth);
                    dicomfilepath=fullfile(tmpdir,dicomfilename);
                    % Option to specify series numbers in terms of numbering of
                    % scanner, or ordering of files
                    
                    if (aap.directory_conventions.rawseries_usefileorder)
                        seriesnum=sess;
                    else
                        [aap seriesnum]=aas_getseriesnumber(aap,dicomseriesname);
                    end
                case 'none'
                    seriesnum=rawdata_allseries(sess);
                    dicomfilepath=alldicomfiles{seriesnum}{1};
            end
            
            % For this series, find type from a single DICOM file
            if (~isempty(dicomfilepath))
                hdr=spm_dicom_headers(dicomfilepath);
                
                % Decide whether to ignore this series [djm 20/3/06]
                % absolute number rather than index (jc)
                if ~any(aap.acq_details.subjects(subj).ignoreseries == ...
                        rawdata_allseries(sess))
                    if (aap.options.autoidentifyfieldmaps)
                        % Just identify all possible fieldmaps without
                        % error checking (comes later)
                        if (findstr(hdr{1}.ProtocolName,aap.directory_conventions.protocol_fieldmap))
                            series_newfieldmap=[series_newfieldmap seriesnum];
                        end
                    end
                    
                    if (aap.options.autoidentifystructural)
                        if findstr(lower(hdr{1}.ProtocolName), lower(aap.directory_conventions.protocol_structural))
                            if (series_spgr & ...
                                    aap.options.autoidentifystructural_chooselast==0  & ...
                                    aap.options.autoidentifystructural_choosefirst==0 & ...
                                    aap.options.autoidentifystructural_average==0 & ...
                                    aap.options.autoidentifystructural_multiple==0) %[AVG] for MP2RAGE, for instance
                                aas_log(aap,1,'Automatic series id failed - more than one MPRAGE acquisition was found.');
                            end
                            series_spgr=[series_spgr seriesnum];
                        end
                    end
                    
                    if (aap.options.autoidentifytmaps)
                        % Use directory name rather than protocol to
                        % recognise t maps
                        if (findstr(hdr{1}.ProtocolName,'EvaSeries_tTest'))
                            series_tmaps=[series_tmaps seriesnum];
                        end
                    end
%                    fprintf('Protocol %s\n',hdr{1}.ProtocolName);
                end
            end
            
        end
        % Save file
        [ais_p ais_f ais_e]=fileparts(aisfn);
        aas_makedir(aap,ais_p);
        aapoptions=aap.options;
        if (exist('alldicomfiles','var'))
            save(aisfn,'series_newfieldmap','series_spgr',...
                'series_tmaps','aapoptions','alldicomfiles',...
                'rawdata_allseries');
        else
            save(aisfn,'series_newfieldmap','series_spgr',...
                'series_tmaps','aapoptions');
        end
        
        % Make comment
        comment=[];
        if (aap.options.autoidentifyfieldmaps)
            % Check that we got the expected number of fieldmaps (or that
            % handling of extra fieldmaps is enabled)
            nmaps = length(series_newfieldmap);
            ntarget = aap.options.autoidentifyfieldmaps_number;
            assert(rem(nmaps,ntarget)==0,'found odd number of fieldmaps');
            assert(nmaps==ntarget || ...
                (aap.options.autoidentifyfieldmaps_choosefirst || ...
                aap.options.autoidentifyfieldmaps_chooselast),...
                sprintf('found %d fieldmaps, expected %d',nmaps,ntarget));
            assert(~all([aap.options.autoidentifyfieldmaps_choosefirst ...
                aap.options.autoidentifyfieldmaps_chooselast]),...
                'cannot specify both choosefirst and chooselast fieldmap');
            aap.acq_details.subjects(subj).siemensfieldmap={};
            % pick first / last ntarget fieldmaps
            if aap.options.autoidentifyfieldmaps_choosefirst
                series_newfieldmap = series_newfieldmap(1:ntarget);
            elseif aap.options.autoidentifyfieldmaps_chooselast
                series_newfieldmap = series_newfieldmap(...
                    (nmaps+1-ntarget):nmaps);
            end
            comment=[comment ' ' sprintf('gre_fieldmapping found %d',...
                series_newfieldmap(1))];
            % Generalisation of fieldmap number...
            for n = 2:ntarget
                comment=[comment ' ' sprintf(' and %d',...
                    series_newfieldmap(n))];
            end
            aap.acq_details.subjects(subj).siemensfieldmap=series_newfieldmap;
        end
        
        if (aap.options.autoidentifystructural)
            if length(series_spgr)>1
                if aap.options.autoidentifystructural_chooselast
                    series_spgr=series_spgr(length(series_spgr));
                elseif aap.options.autoidentifystructural_choosefirst
                    series_spgr = series_spgr(1);
                end
            end
            aap.acq_details.subjects(subj).structural=series_spgr;
            comment=[comment sprintf(' Structural series %d ',...
                series_spgr)];
        end
        
        if (aap.options.autoidentifytmaps)
            aap.acq_details.subjects(subj).tmaps=series_tmaps;
            comment=[comment [' T maps series ' sprintf('%d\t',...
                series_tmaps)]];
        end
        if (length(comment)>0) 
            aas_log(aap,0,comment)
        end
        
        aap=aas_desc_outputs(aap,subj,'autoidentifyseries',aisfn);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
