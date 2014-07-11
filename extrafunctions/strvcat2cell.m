% Converts a vertically concatenated char array into a cell array
function strCell = strvcat2cell(vCatStr, strtokSwitch)
if nargin < 2
    strtokSwitch = 1;
end

if iscell(vCatStr)
    strCell = vCatStr;
elseif ~ischar(vCatStr)
    error('Input is not a character array')
else
    if size(vCatStr,1)==1
        if strtokSwitch == 1
            strCell = {};
            while ~isempty(vCatStr)
                [fn, vCatStr] = strtok(vCatStr);
                strCell = [strCell fn];
            end
        else
            strCell = {vCatStr};
        end
    else
        strCell = {};
        for o = 1:size(vCatStr,1)
            strCell = [strCell deblank(vCatStr(o,:))];
        end
    end
end