classdef trial_labels
    properties(Constant)
        % No "real" enums in Octave yet, so fake it
        trial
        PRACTICE = 0 % veridical feedback
        PRACTICE_CLAMP = 1 % 0 clamp (move wherever)
        BASELINE_1 = 2 % no feedback
        BASELINE_2 = 3 % 0 clamp
        PERTURBATION = 4 % 7.5 clamp
        OBSTACLE_1= 6 % slightly to the left of center
        OBSTACLE_2 = 7 % mirror of obstacle1_left
        OBSTACLE_3 = 8 % one to the left, one to right
        OBSTACLE_4 = 9 % mirror image of obstacle2_left
        NO_OBSTACLE = 5 % washout in the original code
    end
end
