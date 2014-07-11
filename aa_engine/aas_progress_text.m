function reverseStr = aas_progress_text(loopsDone, loopsTotal, reverseStr, prefixText)
if nargin < 4
    prefixText = '';
end

% How much percent is done?
percentDone = 100 * loopsDone / loopsTotal;
% Create message
msg = sprintf('%s Percent done: %3.2f', prefixText, percentDone);
% Append to previous message
fprintf([reverseStr, msg]);
% Create string to delete "next" message
reverseStr = repmat(sprintf('\b'), 1, length(msg));
% New line if finished...
if(percentDone == 100)
    fprintf('\n');
end