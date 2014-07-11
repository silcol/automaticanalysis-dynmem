function aas_fsl_coreg_diag(aap,subj)

fP = aas_getfiles_bystream(aap,subj,'meanepi');

subj_dir = aas_getsubjpath(aap,subj);
structdir = fullfile(subj_dir, aap.directory_conventions.structdirname);

sP = dir( fullfile(structdir,[aap.acq_details.subjects(subj).structuralfn '*.nii']));
sP = fullfile(structdir,sP(1).name);

spm_reslice({fP,sP},aap.spm.defaults.coreg.write)

% Create FSL-like overview
rfP = fullfile(fileparts(fP),[aap.spm.defaults.coreg.write.prefix basename(fP) '.nii']);
rsP = fullfile(fileparts(sP),[aap.spm.defaults.coreg.write.prefix basename(sP) '.nii']);

iP = fullfile(subj_dir,['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_structural2meanepi']);

[s w] = aas_runfslcommand(aap,sprintf('slices %s %s -s 3 -a %s.gif',rfP,rsP,iP));

[img,map] = imread([iP '.gif']); s3 = size(img,1)/3;
   
img = horzcat(img(1:s3,:,:),img(s3+1:2*s3,:,:),img(s3*2+1:end,:,:));
imwrite(img, [iP '.jpg']); delete([iP '.gif']);

iP = fullfile(subj_dir,['diagnostic_' aap.tasklist.main.module(aap.tasklist.currenttask.modulenumber).name '_meanepi2structural']);

[s w] = aas_runfslcommand(aap,sprintf('slices %s %s -s 3 -a %s.gif',rsP,rfP,iP));

[img,map] = imread([iP '.gif']); s3 = size(img,1)/3;

img = horzcat(img(1:s3,:,:),img(s3+1:2*s3,:,:),img(s3*2+1:end,:,:));
imwrite(img, [iP '.jpg']); delete([iP '.gif']);

% Clean
delete(rsP); delete(rfP);
end