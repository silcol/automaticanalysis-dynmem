function fns = mask_img(Mimg, fns, maskVal)
if nargin < 3 || isempty(maskVal)
    maskVal = NaN;
end
if ischar(Mimg)
    % Load mask
    M = spm_read_vols(spm_vol(Mimg));
end
if ischar(fns)
    fns = strvcat2cell(fns);
end

for f = 1:length(fns)
    % Load image
    V = spm_vol(fns{f});
    Y = spm_read_vols(V);
    
    Ydim = size(Y);
    
    if isempty(Mimg)
        % Set things that are 0 to NaN
        Y(or(Y==0, ~isfinite(Y))) = maskVal;
    elseif all(size(M) == Ydim(1:3))
        % Mask image
        notM = find(~M);
        for y = 1:size(Y,4) % For 4-D arrays...
            Y(notM) = maskVal;
            % Get next set of indices...
            notM = notM + numel(M);
        end
    elseif any(size(M) ~= Ydim(1:3))
        error('Mask and image to be masked are not of the same size!')
    end
    
    % Write image back...
    for y = 1:size(Y,4) % For 4-D arrays...
        spm_write_vol(V(y), Y(:,:,:,y));
    end
end