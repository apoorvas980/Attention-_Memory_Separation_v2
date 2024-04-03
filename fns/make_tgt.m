
function tgt = make_tgt(id, block_type, is_short, group)
%{
id is a string containing the participant ID (e.g. 'msl000199')
block_type is a string, either 'p' (practice) or 'm' (main)
is_short is true to make a small display
group is "1" (always congruent) or "2" (always incongruent) or "3" (random)
%}

exp_version = 'v1';

desc = {
    exp_version
    'details here'
};

GREEN = [0 255 0];
RED = [255 0 0];
WHITE = [255 255 255];

if is_short
    N_PRACTICE_PROBE_TRIALS = 2;
    N_PRACTICE_REACH_TRIALS = 2;
    N_PROBE_TRIALS = 5;
    N_REACH_TRIALS = 5;
else
    N_PRACTICE_PROBE_TRIALS = 10;
    N_PRACTICE_REACH_TRIALS = 10;
    N_PROBE_TRIALS = 100;
    N_REACH_TRIALS = 300;
end

CLAMP_ANGLE = 30; %
ref_angle = 270; % NB: target assumed to be at top of screen!!
ang_a = (ref_angle - CLAMP_ANGLE);
ang_b = (ref_angle + CLAMP_ANGLE);
angles = struct('left', ang_a, 'right', ang_b);

seed = str2num(sprintf('%d,', id)); % seed using participant's id

% NB!! This is Octave-specific. MATLAB should use rng(), otherwise it defaults to an old RNG impl (see e.g. http://walkingrandomly.com/?p=2945)
rand('state', seed);

block_level = struct();
trial_level = struct();

block_level.exp_info = sprintf('%s\n', desc{:});
block_level.block_type = block_type;
block_level.clamp_angle = CLAMP_ANGLE;
block_level.seed = seed;
block_level.exp_version = exp_version;
block_level.punishment_time = 3; 
block_level.success_time = 1.5;
block_level.group = group;
block_level.angles = angles;
block_level.p_incongruent_probe = 0.2;

block_level.cursor = struct('size', 4, 'color', WHITE); % mm, white cursor
block_level.center = struct('size', 12, 'color', WHITE, 'offset', struct('x', 0, 'y', 80));
block_level.target = struct('size', 16, 'color', GREEN, 'distance', 120);
block_level.probe = struct('size', 2, 'color', RED); % probe circle
block_level.attention = struct(...
    'size', [0 0 30 10], ...
    'color', WHITE); 

block_level.probe_onset_range = [0.2, 0.8]; % seconds
block_level.max_movement_rt = 0.8;
block_level.max_movement_mt = 1.4;

bb_width = block_level.target.distance * 0.5;
bb_height = block_level.target.distance * 0.8;

if strcmp(block_type, "p")
    reach_or_probe = repmat([1, 2], 1, (N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS)/2);
    attention_type = shuffle(repmat(1:2, 1, N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS));
    attention_type = attention_type(1:length(reach_or_probe));
    trial_attention_combos = [reach_or_probe; attention_type].';
    total_trials = N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS;
elseif strcmp(block_type, "m")
    n_attention_types = 2; % left or right
    reach_or_probe = [repmat(2, 1, N_PROBE_TRIALS/2), repmat(1, 1, N_REACH_TRIALS/2)];
    trial_attention_combos = pairs(reach_or_probe, 1:n_attention_types);
    trial_attention_combos = shuffle_2d(trial_attention_combos);
    total_trials = N_PROBE_TRIALS + N_REACH_TRIALS;
else
    error('Only `block_type`s of "p" or "m" supported.')
end

% Update trial_level struct to include new trial parameters
for i = 1:total_trials
    j_max = block_level.probe_onset_range(2);
    j_min = block_level.probe_onset_range(1);
    trial_level(i).reach_or_probe = trial_attention_combos(i, 1);
    attn_type = trial_attention_combos(i, 2);
    trial_level(i).attention_type = attn_type; % 1 is left, 2 is right??
    %disp( trial_level(i).attention_type)
    %{
        If group 1, the clamp angle and cued direction always congruent
        if group 2, always incongruent
        group 3 is random

        For all groups, the probe is congruent 80% (or x%) of the time
        probe should be halfway between start and end target, at some exaggerated angle (60deg?)
    %}
    % probe_x = rand() * bb_width - bb_width/2;
    % probe_y = rand() * bb_height - bb_height/2;
    congruent_probe = rand() > block_level.p_incongruent_probe; % is the probe congruent with the instruction?
    congruent_cursor = 1; % is the cursor congruent with the instruction?
    clamp_angle = 0;
    if attn_type == 1
        clamp_angle = angles.left;
        if strcmp(group, "2")
            clamp_angle = angles.right;
            congruent_cursor = 0;
        elseif strcmp(group, "3") && rand() > 0.5
            clamp_angle = angles.right;
            congruent_cursor = 0;
        end
    elseif attn_type == 2
        clamp_angle = angles.right;
        if strcmp(group, "2")
            clamp_angle = angles.left;
            congruent_cursor = 0;
        elseif strcmp(group, "3") && rand() > 0.5
            clamp_angle = angles.left;
            congruent_cursor = 0;
        end
    end

    if congruent_probe
        if attn_type == 1
            probe_angle = angles.left - CLAMP_ANGLE;
        else
            probe_angle = angles.right + CLAMP_ANGLE;
        end
    else
        if attn_type == 1
            probe_angle = angles.right + CLAMP_ANGLE;
        else
            probe_angle = angles.left - CLAMP_ANGLE;
        end
    end
    
    probe_extent = 0.5 * block_level.target.distance; % TODO: it looks like we transform to the right location in StateMachine, but double check?
    % note that probe angle is 2x the clamp angle
    probe_x = probe_extent * cosd(probe_angle);
    probe_y = probe_extent * sind(probe_angle);

    trial_level(i).congruent_cursor = congruent_cursor;
    trial_level(i).congruent_probe = congruent_probe;
    trial_level(i).probe = struct('onset_time', rand() * (j_max - j_min) + j_min, 'r', probe_extent, 'theta', probe_angle);
    trial_level(i).clamp_angle = clamp_angle;
end

tgt = struct('block', block_level, 'trial', trial_level);

end

function arr = shuffle(arr)
arr = arr(randperm(length(arr)));
end

function arr = shuffle_2d(arr)
arr = arr(randperm(size(arr, 1)), :);
end

function out = pairs(a1, a2)
[p, q] = meshgrid(a1, a2);
out = [p(:) q(:)];
end
