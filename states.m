classdef states
    properties(Constant)
        % No "real" enums in Octave yet, so fake it
        END = 0
        RETURN_TO_CENTER = 1 % veridical feedback after 2 sec
        REACH = 2 % high tone, go!
        % reach post-trial states
        
        REACH_RT_TOO_SLOW = 5
        REACH_MT_TOO_SLOW = 6
        REACH_GOOD = 7
        
        PROBE = 3 % low tone, stay & wait for probe!
        % probe post-trial states
        PROBE_EARLY_PRESS = 8
        PROBE_LATE_PRESS = 9
        PROBE_MOVED = 10
        PROBE_GOOD = 11
    end
end
