function [MVPaa_data, dataMask] = mvpaa_maskData(MVPaa_data, segMask)

% Check that the size of the mask and data are equal!
sData = size(MVPaa_data);
sData = sData(2:4);
sMask = size(segMask);
    
if ~all(sData == sMask)
   error('Size of data and mask are not equal!') 
end

% Mask all the data, once!
if ~isempty(segMask)    
    MVPaa_data(:,segMask) = NaN;
end

% Mask mask by data locations containing non-finite values or 0s...
dataMask = squeeze(any(or(~isfinite(MVPaa_data), MVPaa_data==0)));
