% AA find stream
% Checks if a particular stream exists in the module

function FNs = aas_findstream(aap, streamString, varargin)

FNs = [];
for Sind=1:length(aap.tasklist.currenttask.inputstreams.stream)
    if ~isempty(strfind(aap.tasklist.currenttask.inputstreams.stream{Sind}, streamString))
        if isempty(FNs)
            switch (nargin)
                case 2
                    FNs = aas_getfiles_bystream(aap, aap.tasklist.currenttask.inputstreams.stream{Sind});
                case 3
                    FNs = aas_getfiles_bystream(aap,varargin{1}, aap.tasklist.currenttask.inputstreams.stream{Sind});
                case 4
                    FNs = aas_getfiles_bystream(aap,varargin{1}, varargin{2}, aap.tasklist.currenttask.inputstreams.stream{Sind});
            end
        else
            aas_log(aap, true, 'Several streams to that name found, not sure what to do!');
        end
    end
end
