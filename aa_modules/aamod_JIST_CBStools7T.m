function [aap,resp]=aamod_JIST_CBStools7T(aap,task,subj)

resp='';

switch task
    case 'report'
        
    case 'doit'
        
        % Load the Structural
        Simg = aas_getfiles_bystream(aap,subj,'structural');
        Simg = Simg(aap.tasklist.currenttask.settings.structural, :);
        Simg = strvcat2cell(Simg);
        if length(Simg) < 3
            aas_log(aap,true, 'Not enough structurals for this module')
        end
        
        % All structurals should be in the same dir
        [Spth, Sfn, Sext] = fileparts(Simg{1});
        inv2Img = [Sfn, Sext];
        
        [Spth, Sfn, Sext] = fileparts(Simg{2});
        t1mapImg = [Sfn, Sext];
        
        [Spth, Sfn, Sext] = fileparts(Simg{3});
        flatImg = [Sfn, Sext];
        
        % Change directory to the Spth, so that results are output there...
        cd(Spth)
        
        % The JIST layout required to make this module work
        JIST_layout = 'standard-MP2RAGE-7T-segmentation-400MNI.layout';
        
        if isempty(aap.directory_conventions.JISTlayoutdir)
            AApth = fileparts(fileparts(mfilename('fullpath')));
            JISTlayout_pth = fullfile(AApth, 'external', 'CBStools');
        end
        
        % Copy the JIST layout to the subject folder...
        copyfile(fullfile(JISTlayout_pth, JIST_layout), fullfile(Spth, JIST_layout));
        
        % Open the new JIST layout file, and change the lines
        tmpSpth = strrep(Spth(2:end), '/', '\\/');
        replaceinfile('T1_weighted_image.nii', flatImg, fullfile(Spth, JIST_layout));
        replaceinfile('T1_map_image.nii', t1mapImg, fullfile(Spth, JIST_layout));
        replaceinfile('Inv2_image.nii', inv2Img, fullfile(Spth, JIST_layout));
        replaceinfile('analysis_folder', tmpSpth, fullfile(Spth, JIST_layout));
        
        % We will use the "mipavjava" alias to run our layout
        MIPAVcommand = sprintf('mipavjava edu.jhu.ece.iacl.jist.cli.runLayout %s', ...
            fullfile(Spth, JIST_layout));
        
        % Run the MIVAP command
        [s w] = aas_runMIPAVcommand(aap, MIPAVcommand, Spth);
        
        %% DESCRIBE OUTPUTS
        outstream = dirrec(fullfile(Spth, 'exp-0000'));
        aap=aas_desc_outputs(aap,subj,'CBStools7T',outstream);
end
end