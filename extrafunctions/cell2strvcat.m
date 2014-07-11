% Converts a cell array into a vertically concatenated char array
function vCatStr = cell2strvcat(strCell)

if ischar(strCell)
    vCatStr = strCell;
elseif ~iscell(strCell)
    error('Input is not a cell array')
else
    vCatStr = '';
    for o = 1:length(strCell)
        vCatStr = strvcat(vCatStr, strCell{o});
    end
end