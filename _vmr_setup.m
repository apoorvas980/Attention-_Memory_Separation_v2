% top-level boilerplate-- "real" experiment in _vmr_exp.m
% Note this assumes only octave. Some things don't exist in MATLAB, and
% I don't want to take the time to fix/standardize at this point
function _vmr_setup(is_debug, is_short)
    delete('latest.log');
    diary 'latest.log'; % write warnings/errs to logfile
    diary on;
    if ~(IsOctave() && IsLinux())
        warning([sprintf('This experiment was written to specifically target linux + Octave.\n'), ...
                 'Things will probably fail if you have not adapted to other systems.']);
    end
    try
        vmr_inner(is_debug, is_short);
    catch err
        % clean up PTB here
        % Do we need anything else? Audio/input/..
        _cleanup();
        rethrow(err);
    end
end

function vmr_inner(is_debug, is_short)
    if IsOctave()
        ignore_function_time_stamp("all");
    end
    ref_path = fileparts(mfilename('fullpath'));
    addpath(fullfile(ref_path, 'fns')); % add misc things to search path
    settings = struct('id', 'test', 'base_path', ref_path, 'data_path', fullfile(ref_path, 'data'));
    
    if ~is_debug
        id = input(sprintf('Enter the participant ID, or leave blank to use the default value (%s): ', num2str(settings.id)), "s");
        if ~isempty(id)
            settings.id = id;
        end
    end

    group = x_or_y('Group 1 or 2? ', ["1", "2"]);
    block_type = x_or_y('Is this the practice (p) or main task (m)? ', ["p", "m"]);
    _vmr_exp(is_debug, is_short, group, block_type, settings);
end
