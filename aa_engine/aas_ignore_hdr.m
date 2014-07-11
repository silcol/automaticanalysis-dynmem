% AA helper function
% Remove files with the .hdr extension from the list of files...
function imgFns = aas_ignore_hdr(imgFns)
if iscell(imgFns)
    numFns = length(imgFns);
    
    for t = numFns:-1:1
        [pth, fn, ext] = fileparts(deblank(imgFns{t}));
        if strcmp(ext, '.hdr')
            imgFns(t) = [];
        end
    end
    
elseif ischar(imgFns)
    numFns = size(imgFns,1);
     for t = numFns:-1:1
        [pth, fn, ext] = fileparts(deblank(imgFns(t,:)));
        if strcmp(ext, '.hdr')
            imgFns(t, :) = [];
        end
     end
else
    error('Inappropriate input')
end

end
