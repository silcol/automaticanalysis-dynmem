% compare each pilab_data_rdms_mean to each predictor in
% pilab_rsapredictors using permutation testing.
% [aap,resp]=aamod_pilab_rsapermtest(aap,task,subj)
function [aap,resp]=aamod_pilab_rsapermtest(aap,task,subj)

resp='';

switch task
    case 'doit'
        % get data RDMs
        vpath = aas_getfiles_bystream(aap,subj,'pilab_data_rdms_mean');
        disvol = loadbetter(vpath);

        % predictor RDMs
        predictpath = aas_getfiles_bystream(aap,subj,...
            'pilab_rsapredictors');
        predictors = loadbetter(predictpath);
        npredictors = length(predictors);

        % check that parfor is available
        if ~matlabpool('size')
            try
                matlabpool local
            catch
                warning('no matlabpool available')
            end
        end

        % make outputs
        pidir = fullfile(aas_getsubjpath(aap,subj),'pilab');
        resdir = fullfile(pidir,'results');
        mkdirifneeded(resdir);
        % pre-allocate depending on run mode
        switch aap.tasklist.currenttask.settings.outputmode
            case 'searchlight'
                rpaths = cell(npredictors,1);
                ppaths = cell(npredictors,1);
                pfwepaths = cell(npredictors,1);
            case 'roi'
                % one output spanning all ROIs / predictors
                rpaths = fullfile(resdir,'roi_r.mat');
                ppaths = fullfile(resdir,'roi_p.mat');
                pfwepaths = fullfile(resdir,'roi_pFWE.mat');
                % pre-allocate results - struct array with one entry per
                % ROI and one field per analysis. Separate struct arrays
                % for each result type.
                % (a 2-level struct array might be more intuitive but
                % Matlab makes indexing such very painful so we use this
                % slightly more awkward syntax for ease of access)
                predres = cell2struct(cell([npredictors 1]),...
                    [{predictors.name}]);
                res_r = repmat(predres,[1 disvol.nfeatures]);
                names = disvol.meta.features.names;
                res_p = res_r;
                res_pfwe = res_r;
            otherwise
                error('unrecognised outputmode setting: %s',...
                    aap.tasklist.currenttask.settings.outputmode);
        end
        % null dists are too big to go in one mat
        nulldistpaths = cell(npredictors,1);
        figdir = fullfile(resdir,'figures');
        mkdirifneeded(figdir);

        for pre = 1:npredictors
            fprintf('testing %s (%d of %d)...\n',predictors(pre).name,...
                pre,npredictors);
            % permutation test
            tic;
            [r,p,nulldists] = rsapermtest(predictors(pre),...
                disvol.data,aap.tasklist.currenttask.settings.nperms);
            fprintf('finished in %s. ',seconds2str(toc));
            % obtain Nichols / Holmes-style FWE-corrected p values
            pfwe = maxstatpfwe(nulldists);
            fprintf('Min p(FWE) = %.2f\n',min(pfwe(:)));
            % save data depending on mode
            switch aap.tasklist.currenttask.settings.outputmode
                case 'searchlight'
                    % write out niftis of maps
                    % r map
                    rout = fullfile(resdir,sprintf('%s_r.nii',...
                        predictors(pre).name));
                    disvol.data2file(r,rout);
                    rpaths{pre} = rout;
                    % log10 p map
                    pout = fullfile(resdir,sprintf('%s_-log10p.nii',...
                        predictors(pre).name));
                    disvol.data2file(-log10(p),pout);
                    ppaths{pre} = pout;
                    % FWE-corrected p map
                    pfweout = fullfile(resdir,sprintf('%s_-log10pFWE.nii',...
                        predictors(pre).name));
                    disvol.data2file(-log10(pfwe),pfweout);
                    pfwepaths{pre} = pfweout;
                    % diagnostic figure
                    F = figure;
                    imagesc(makeimagestack(disvol.data2mat(r),[0 .5],1),...
                        [0 1]);
                    colormap(hot(1024));
                    set(gca,'dataaspectratio',[1 1 1]);
                    title(stripbadcharacters(predictors(pre).name,' '));
                    C = colorbar;
                    ylabel(C,'rho');
                    set(C,'ytick',[0 1],'ylim',[0 1],'yticklabel',[0 .5]);
                    axis off
                    printstandard(fullfile(figdir,sprintf(...
                                'slices_r_%s',predictors(pre).name)));
                    close(F);
                case 'roi'
                    % update structs
                    % (matlab makes this comically awkward but there you
                    % go)
                    rc = num2cell(r);
                    [res_r.(predictors(pre).name)] = rc{:};
                    pc = num2cell(p);
                    [res_p.(predictors(pre).name)] = pc{:};
                    pfwec = num2cell(pfwe);
                    [res_pfwe.(predictors(pre).name)] = pfwec{:};
                    % maybe save mats and make figures if the loop is done
                    if pre == npredictors
                        % save data
                        save(rpaths,'res_r');
                        save(ppaths,'res_p');
                        save(pfwepaths,'res_pfwe');
                        % make bar chart for each ROI
                        x = 1:npredictors;
                        F = figure;
                        for r = 1:disvol.nfeatures
                            roistr = names{r};
                            % plot rho in bars
                            rho = structfun(@(x)x,res_r(r));
                            B = bar(x,rho,.6,...
                                'edgecolor','none','facecolor',[.6 .6 .6]);
                            ylabel('spearman rho')
                            title(stripbadcharacters(roistr))
                            set(gca,'xtick',x,'xticklabel',...
                                stripbadcharacters(fieldnames(res_r(r)),...
                                ' '),'tickdir','out','ticklength',...
                                get(gca,'ticklength')*.5);
                            xlim([x(1)-1 1+x(end)]);
                            rotateXLabels(gca,45);
                            % add p values on top of each bar
                            p = structfun(@(x)x,res_p(r));
                            % adaptively change precision of p strs
                            % depending on nperms
                            pstr = p2str(p,ceil(log10(...
                                aap.tasklist.currenttask.settings.nperms)));
                            T = text(x,max(rho,zeros(npredictors,1)),...
                                pstr,'rotation',90);
                            % make significant ps bold
                            set(T(p<.05),'fontweight','bold');
                            box off
                            printstandard(fullfile(figdir,sprintf(...
                                'bar_%s',roistr)));
                            clf(F);
                        end
                        close(F);
                    end
                otherwise
                    error('unrecognised outputmode setting: %s',...
                        aap.tasklist.currenttask.settings.outputmode);
            end
            % null distributions - same for ROI and searchlight
            nullout = fullfile(resdir,sprintf('%s_nulldist.mat',...
                predictors(pre).name));
            % save as volume with massive ndata
            nullvol = MriVolume(nulldists,disvol);
            % for mysterious reasons Matlab cannot save this in any older
            % version
            save(nullout,'nullvol','-v7');
            nulldistpaths{pre} = nullout;
        end
        % describe outputs
        aap=aas_desc_outputs(aap,subj,'pilab_r',...
            rpaths);
        aap=aas_desc_outputs(aap,subj,'pilab_p',...
            ppaths);
        aap=aas_desc_outputs(aap,subj,'pilab_p_fwe',...
            pfwepaths);
        aap=aas_desc_outputs(aap,subj,'pilab_nulldist',...
            nulldistpaths);
    case 'checkrequirements'
        
    otherwise
        aas_log(aap,1,sprintf('Unknown task %s',task));
end
