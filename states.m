classdef states
    properties(Constant)
        % No "real" enums in Octave yet, so fake it
        END = 0
        RETURN_TO_CENTER = 1 % veridical feedback after 2 sec
        REACH = 2 % high tone, go!
        % reach post-trial states
        
        REACH_RT_TOO_SLOW = 4
        REACH_MT_TOO_SLOW = 5
        REACH_GOOD = 6
        
        PROBE = 3 % low tone, stay & wait for probe!
        % probe post-trial states
        PROBE_EARLY_PRESS = 7
        PROBE_LATE_PRESS = 8
        PROBE_MOVED = 9
        PROBE_GOOD = 10
    end
end
