
function tgt = make_tgt_new(id, block_type, is_short)
%{
id is a string containing the participant ID (e.g. 'msl000199')
block_type is a string, either 'p' (practice) or 'm' (main)
is_short is true to make a small display
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

else % "real", full-length task
    N_PRACTICE_PROBE_TRIALS = 10;
    N_PRACTICE_REACH_TRIALS = 10;
    N_PROBE_TRIALS = 400;
    N_REACH_TRIALS = 400;
end

seed = str2num(sprintf('%d,', id)); % seed using participant's id
% NB!! This is Octave-specific. MATLAB should use rng(), otherwise it defaults to an old RNG impl (see e.g. http://walkingrandomly.com/?p=2945)
rand('state', seed);

block_level = struct();
trial_level = struct();
block_level.exp_info = sprintf('%s\n', desc{:});
block_level.block_type = block_type;
##block_level.manipulation_angle = sign * ABS_MANIP_ANGLE;
block_level.seed = seed;
block_level.exp_version = exp_version;
block_level.punishment_time = 3; % seconds
block_level.success_time = 1;
% sizes taken from https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5505262/
% but honestly not picky
block_level.cursor = struct('size', 4, 'color', WHITE); % mm, white cursor
block_level.center = struct('size', 12, 'color', WHITE, 'offset', struct('x', 0, 'y', 80));
block_level.target = struct('size', 16, 'color', GREEN, 'distance', 120);
block_level.probe = struct('size', 2, 'color', WHITE); % probe circle
block_level.barrier = struct(...
    'size', [0 0 30 10], ...
    'color', WHITE); 
block_level.probe_onset_range = [0.2, 0.8]; % seconds
block_level.max_movement_rt = 0.8;
block_level.max_movement_mt = 1.4;
bb_width = block_level.target.distance * 0.5;
bb_height = block_level.target.distance * 0.8;
% implicit assumption that the probe area is centered between the start location & target
block_level.probe_area = struct('width', bb_width, 'height', bb_height);
%{
type 1: one obstacle slightly to left of center
type 2: same as type 1, but mirrored on y axis
type 3: two obstacles, one slightly to the left and one to the right
type 4: same as type 3, but mirrored on y axis
type 5: no blocks

center locations of blocks
check the number of barriers with size(barrier_locations{barrier trial type}, 1)
get the center coordinate of a given barrier for the trial type with
barrier_locations{barrier trial type}(barrier index)

use CenterRectonPointd(...) + block_level.barrier.size to draw barriers in 
specific locations
%}

block_level.barrier_locations = {...
   [[-15, 80]]; ...
   [[15, 80]]; ...
   [[-20, 40]; [10, 80]]; ...
   [[20, 40]; [-10, 80]]; ...
   []}; 

if strcmp(block_type, "p")
  reach_or_probe = repmat([1, 2], 1, (N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS)/2);
  barrier_type = shuffle(repmat(1:5, 1, N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS));
  barrier_type = barrier_type(1:length(reach_or_probe));
  trial_barrier_combos = [reach_or_probe; barrier_type].';
  total_trials = N_PRACTICE_PROBE_TRIALS + N_PRACTICE_REACH_TRIALS;
elseif strcmp(block_type, "m")
  n_barrier_types = length(block_level.barrier_locations);
  reach_or_probe = [repmat(1, 1, N_PROBE_TRIALS/n_barrier_types),...
                            repmat(2, 1, N_REACH_TRIALS/n_barrier_types)];
  %barrier_type
  trial_barrier_combos = pairs(reach_or_probe, 1:5);
  trial_barrier_combos = shuffle_2d(trial_barrier_combos);
  total_trials = N_PROBE_TRIALS + N_REACH_TRIALS;
else
  error('Only `block_type`s of "p" or "m" supported.')
end

for i = 1:total_trials
    trial_level(i).reach_or_probe = trial_barrier_combos(i, 1);
    trial_level(i).barrier_type = trial_barrier_combos(i, 2);
    j_max = block_level.probe_onset_range(2);
    j_min = block_level.probe_onset_range(1);
    % generate the probe location
    % first generate a location in the bounding box
    % then offset between the start position & target
    % these are in mm
    probe_x = rand() * bb_width - bb_width/2;
    probe_y = rand() * bb_height - bb_height/2;
    trial_level(i).probe = struct('onset_time', rand() * (j_max - j_min) + j_min,
                                  'x', probe_x,
                                  'y', probe_y);
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
