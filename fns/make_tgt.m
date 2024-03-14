
function tgt = make_tgt(id, block_type, is_short, group)
%{
id is a string containing the participant ID (e.g. 'msl000199')
block_type is a string, either 'p' (practice) or 'm' (main)
is_short is true to make a small display
group is "1" (always congruent) or "2" (always incongruent)
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
    N_PROBE_TRIALS = 400;
    N_REACH_TRIALS = 400;  % correct this
end

CLAMP_ANGLE = 30; %
ref_angle = 270; % NB: target assumed to be at top of screen!!
ang_a = (ref_angle - CLAMP_ANGLE);
ang_b = (ref_angle + CLAMP_ANGLE);
if strcmp(group, "1")
    angles = [ang_a, ang_b];
elseif strcmp(group, "2")
    angles = [ang_b, ang_a];
else
    error('Unknown group!');
end

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
block_level.success_time = 0.8;
block_level.group = group;
block_level.angles = angles;

block_level.cursor = struct('size', 4, 'color', WHITE); % mm, white cursor
block_level.center = struct('size', 12, 'color', WHITE, 'offset', struct('x', 0, 'y', 80));
block_level.target = struct('size', 16, 'color', GREEN, 'distance', 120);
block_level.probe = struct('size', 2, 'color', WHITE); % probe circle
block_level.attention = struct(...
    'size', [0 0 30 10], ...
    'color', WHITE); 

block_level.text_left = struct('text', 'Left', 'font_size', 12, 'color', 'WHITE');
block_level.text_right = struct('text', 'Right', 'font_size', 12, 'color', 'WHITE');

block_level.probe_onset_range = [0.2, 0.8]; % seconds
block_level.max_movement_rt = 0.8;
block_level.max_movement_mt = 1.4;

bb_width = block_level.target.distance * 0.5;
bb_height = block_level.target.distance * 0.8;

block_level.probe_area = struct('width', bb_width, 'height', bb_height);

block_level.attention_locations = {...
    [[-15, 80]]; ...
    [[15, 80]]; ...
};      % is this even needed?

if strcmp(block_type, "p")
    reach_or_probe = repmat([1, 2], 1, (N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS)/2);
    attention_type = shuffle(repmat(1:2, 1, N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS));
    attention_type = attention_type(1:length(reach_or_probe));
    trial_attention_combos = [reach_or_probe; attention_type].';
    total_trials = N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS;
elseif strcmp(block_type, "m")
    n_attention_types = length(block_level.attention_locations);
    reach_or_probe = [repmat(1, 1, N_PROBE_TRIALS/2), repmat(2, 1, N_REACH_TRIALS/2)];
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
    trial_level(i).attention_type = trial_attention_combos(i, 2);
    %disp( trial_level(i).attention_type)
    probe_x = rand() * bb_width - bb_width/2;
    probe_y = rand() * bb_height - bb_height/2;
    trial_level(i).probe = struct('onset_time', rand() * (j_max - j_min) + j_min, 'x', probe_x, 'y', probe_y);
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
