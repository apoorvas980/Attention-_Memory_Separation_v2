screens = Screen('Screens');
max_scr = max(screens);

X_PITCH = 0.2832; % pixel pitch, specific to "real" monitor
Y_PITCH = 0.2802; % note the non-squareness (though for sizes/distances < ~45mm)
unit = Unitizer(X_PITCH, Y_PITCH);
w = struct();
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseDisplayRotation', 180);
[w.w, w.rect] = PsychImaging('OpenWindow', max_scr, 0);

[w.center(1), w.center(2)] = RectCenter(w.rect);

Screen('BlendFunction', w.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


GREEN = [0 255 0];
RED = [255 0 0];
WHITE = [255 255 255];

barrier = struct(...
    'size', [0 0 12 12], ...
    'color', RED);

barrier_locations = {...
   [[-5, 30]]; ...
   [[5, 30]]; ...
   [[-20, 40]; [0, 40]; [20, 40]]; ...
   [[5, 20]; [-5, 40]]; ...
   []};

barrier_index = 3;

centre = struct('size', 12, 'color', WHITE, 'offset', struct('x', 0, 'y', 80));
centre.x = w.center(1) + unit.x_mm2px(centre.offset.x);
centre.y = w.center(2) + unit.y_mm2px(centre.offset.y);
target = struct('size', 16, 'color', GREEN, 'distance', 80);
target.x = centre.x;
% TODO: check sign
target.y = centre.y - unit.y_mm2px(target.distance);

xys = zeros(2, 2);
sizes = zeros(1, 2);
colors = zeros(3, 2, 'uint8'); % rgb255

xys(:, 1) = [centre.x centre.y];
sizes(1) = unit.x_mm2px(centre.size);
colors(:, 1) = centre.color;

xys(:, 2) = [target.x target.y];
sizes(2) = unit.x_mm2px(target.size);
colors(:, 2) = target.color;

% compute barrier locations
current_barrier_xys = unit.x_mm2px(barrier_locations{barrier_index});
current_barrier_xys(:, 1) = centre.x - current_barrier_xys(:, 1) ;
current_barrier_xys(:, 2) = centre.y - current_barrier_xys(:, 2) ;

barrier_size = unit.x_mm2px(barrier.size);
%TODO: pick CenterRectOnPoint vs CenterRectOnPointd
rects = CenterRectOnPoint(barrier_size, current_barrier_xys(:, 1), current_barrier_xys(:, 2));

% to test whether a point (e.g. the cursor) is in a rectangle,
% loop through each rect individually. The function is not vectorized
any_collide = 0;
for i = 1:size(rects, 1)
    % e.g. replace 870, 665 with the current pixel location of the cursor
    collided = IsInRect(870, 665, rects(i, :));
    disp(collided);
    if collided
        any_collide = 1;
    end
    % 
end
disp(sprintf('Any collided? %i', any_collide));

Screen('DrawDots', w.w, xys, sizes, colors, [], 3, 1);
Screen('FillRect', w.w, barrier.color, rects.');

Screen('Flip', w.w);
WaitSecs(3);
sca;
