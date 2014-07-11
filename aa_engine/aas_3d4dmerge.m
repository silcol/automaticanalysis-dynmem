%% aas_fslmerge(imgFns)
function [img4Dfn, merged] = aas_3d4dmerge(aap, img4Dpth, mriname, imgFns)

imgFns = strvcat2cell(imgFns); 

if length(imgFns) == 1
    merged = 0;
    
    disp('Data has only one dimension, so not concatenating')
    
    img4Dfn = cell2strvcat(imgFns);
else
    merged = 1;
    
    disp('Concatenating the data')
    
    img4Dfn = fullfile(img4Dpth, sprintf('4Ddata_%s.nii', mriname));
    
    V4 = spm_file_merge(imgFns, img4Dfn, 0);
    
    %{
    matlabbatch{1}.spm.util.cat.vols = imgFns;
    matlabbatch{1}.spm.util.cat.name = img4Dfn;
    matlabbatch{1}.spm.util.cat.dtype = 0;
    spm_jobman('run', matlabbatch)
    %}
    
    %% OLD FSL WAY...
    %{
    spaced_imgFns = [];
    
    for e = 1:size(imgFns,1)
        [pth, nme, ext] = fileparts(imgFns(e,:));
        spaced_imgFns = [spaced_imgFns nme ext ' '];
    end
    
    img4Dfn = fullfile(img4Dpth, sprintf('4Ddata_%s.nii', mriname));
    
    cd(img4Dpth);
    [junk, w]=aas_runfslcommand(aap, ...
        sprintf('fslmerge -t %s %s', ...
        img4Dfn, ...
        spaced_imgFns));
    %}
end