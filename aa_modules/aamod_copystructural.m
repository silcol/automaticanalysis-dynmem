% AA module - converts strucural from DICOM and copies to central store
% If there is a structural for this subject, copy it to central store
% Also makes 'structurals' directory
% Rhodri Cusack MRC CBU Cambridge Aug 2004

function [aap,resp]=aamod_copystructural(aap,task,subj)

resp='';

switch task       
    case 'description'
        resp='Structural dicom to nifti and copying';
        
    case 'summary'
        if (length(aap.acq_details.subjects(subj).structural)==0)
            resp=sprintf('No structural for subject %s\n',aap.acq_details.subjects(subj).mriname);
        else
            resp=sprintf('Converted structural for subject %s \n', aas_getsubjname(aap,subj));
        end;
        
    case 'report'
    case 'doit'
        
    [aap convertedfns dcmhdr]=aas_convertseries_fromstream(aap,subj,'dicom_structural');
        
    % Save EXAMPLE dicom header (not all as previous code)
    subjpath=aas_getsubjpath(aap,subj);

    mriname = aas_prepare_diagnostic(aap,subj);
    for f = 1:size(convertedfns,1)
        V = spm_vol(convertedfns{f});
        fprintf('Size of structural n=%d %s: %dx%dx%d\n', f, dcmhdr{f}.SeriesDescription, ...
            V.dim(1), V.dim(2), V.dim(3));
        
        %% Display structural diagnostic image
        spm_check_registration(convertedfns{f})
        
        spm_orthviews('reposition', [0 0 0])
        
        print('-djpeg','-r150',fullfile(aap.acq_details.root, 'diagnostics', ...
            [mfilename '__' mriname '_' num2str(f) '.jpeg']));
    end
    
     % Save outputs?
    aap=aas_desc_outputs(aap,subj,'structural',convertedfns);
            
    dcmhdrfn=fullfile(subjpath,'structural_dicom_header.mat');
    save(dcmhdrfn,'dcmhdr');
    aap=aas_desc_outputs(aap,subj,'structural_dicom_header',dcmhdrfn);
 
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end;

