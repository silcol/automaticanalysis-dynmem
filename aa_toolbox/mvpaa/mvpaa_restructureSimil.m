% MVPAA_CORRELATION - Simillate the betas/spmTs
% R - betas/spmTs (or residuals of betas/spmTs)

function [Simil] = mvpaa_restructureSimil(aap, Simil)

% Rename settings to keep easier track...
EP = aap.tasklist.currenttask.settings;

if ~strcmp(EP.triangulation, 'none')
    Simil = permute( ...
        reshape(Simil, ...
        [EP.conditions, ...
        EP.blocks * EP.sessions, ...
        EP.conditions, ...
        EP.blocks * EP.sessions]), ...
        [2, 4, 1, 3]);
end

%% Not that useful when betas are "solid". Default ignores it.
if EP.norm2z
    
    % Normalise the similarity measures within each block
    Simil = reshape(Simil, ...
        [(EP.blocks * EP.sessions)^2, ...
        (EP.conditions)^2]);
    Simil = (Simil - repmat(nanmean(Simil,2),[1, size(Simil,2)])) ...
        ./ repmat(nanstd(Simil,1,2), [1,size(Simil,2)]);
    Simil = reshape(Simil, ...
        [EP.blocks * EP.sessions, ...
        EP.blocks * EP.sessions, ...
        EP.conditions, EP.conditions]);
    
end