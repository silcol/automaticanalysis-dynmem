function imgFns = aas_copy2prefix(imgFns, prefix)

% Copy with prefix
imgFns = strvcat2cell(imgFns);

for f = 1:length(imgFns);
    [pth, fn, ext] = fileparts(imgFns{f});
    newName = fullfile(pth, [prefix fn ext]);
    copyfile(imgFns{f}, newName);
    imgFns{f} = newName;
end

imgFns = cell2strvcat(imgFns);