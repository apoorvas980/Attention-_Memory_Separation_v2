classdef StateMachine < handle

    properties
        trial_start_time = 9e99
        too_slow = 0
        press_time = 0
        failed_this_trial = 0
        aud % audio handle
    end % public properties

    properties (Access = private)
        state = states.RETURN_TO_CENTER
        is_transitioning = true
        w % window struct
        tgt % trial table
        un % unit handler
        kb % keyboard index
        beeps % map of beeps
        trial_summary_data % per-trial data summary (e.g. RT, any collisions, ...)
        trial_count = 1 % helps keep track of when to quit task
        within_trial_frame_count = 1 % helps index frame-by-frame data
        beep_start_time = 0 % use as reference for RTs, etc.
        debounce = 0 % make sure that they're not already in the start position when RETURN_TO_CENTER begins
        current_sound
        last_event = struct('x', 0, 'y', 0)
        last_eye_event = struct('x', 0, 'y', 0)
        state_exit_time

        % these are mostly useful for drawing
        attention = struct('vis', false, 'rects', [])
        center = struct('vis', false, 'x', 0, 'y', 0)
        target = struct('vis', false, 'x', 0, 'y', 0)
        cursor = struct('vis', false, 'x', 0, 'y', 0)
        probe = struct('vis', false, 'x', 0, 'y', 0)

    end % private properties

    methods

        function sm = StateMachine(path, tgt, win_info, unit)
            sm.w = win_info;
            sm.tgt = tgt;
            sm.un = unit;
            % set up keyboard for probe trials
            % TODO: clean up keyboard?
            % kb = PsychHID('Devices', 2); % get the master keyboard
            keys = zeros(1, 256);
            keys(KbName('SPACE')) = 1;
            sm.kb = []; %kb.index;
            KbQueueCreate(sm.kb, keys);
            KbQueueStart(sm.kb);
            % set up tones for cueing
            sm.beeps = containers.Map();
            sampling_rate = 48000;

            sm.aud = PsychPortAudio('Open',
                                    [], % default device
                                    1 + 8, % playback only, master device
                                    2, % full control
                                    sampling_rate, % sampling rate
                                    2); % nr channels

            PsychPortAudio('Start', sm.aud, 0, 0, 1);
            PsychPortAudio('Volume', sm.aud, 1); % TODO: ???

            lo = gen_beep(261.6256, 0.2, sampling_rate); % C4
            hi = gen_beep(1046.502, 0.2, sampling_rate); % C6
            over = gen_beep(523.2511, 0.2, sampling_rate); % C5

            sm.beeps('low') = PsychPortAudio('OpenSlave', sm.aud, 1);
            PsychPortAudio('FillBuffer', sm.beeps('low'), lo);

            sm.beeps('high') = PsychPortAudio('OpenSlave', sm.aud, 1);
            PsychPortAudio('FillBuffer', sm.beeps('high'), hi);

            sm.beeps('over') = PsychPortAudio('OpenSlave', sm.aud, 1);
            PsychPortAudio('FillBuffer', sm.beeps('over'), over);

        end % StateMachine constructor

        function update(sm, evts, last_vbl, eye_evts)

            % NB: evt might be empty
            % This function only runs once a frame on the latest input event
            sm.within_trial_frame_count = sm.within_trial_frame_count + 1;
            w = sm.w;
            tgt = sm.tgt;
            u = sm.un;
            trial = tgt.trial(sm.trial_count);
            block = tgt.block;

            if ~isempty(evts) % non-empty event
                sm.cursor.x = evts(end).x;
                sm.cursor.y = evts(end).y;
                sm.last_event.x = sm.cursor.x;
                sm.last_event.y = sm.cursor.y;
            else
                sm.cursor.x = sm.last_event.x;
                sm.cursor.y = sm.last_event.y;
            end

            % check if eye sample(s) inside the center target
            gaze_in_center = 1; % assume the best intentions by default
            for evt = eye_evts
                sm.last_eye_event.x = evt.x;
                sm.last_eye_event.y = evt.y;
                new_gaze_val = point_in_circle([evt.x evt.y],
                                               [sm.center.x sm.center.y], ...
                                                u.x_mm2px(block.center.size) * 0.5);
                if new_gaze_val == 0
                    gaze_in_center = 0;
                end
            end

            est_next_vbl = last_vbl + w.ifi;

            if sm.state == states.RETURN_TO_CENTER
                if sm.entering()
                    err = Eyelink('CheckRecording');
                    if err ~= 0
                        error('Eyelink is not recording anymore (and not on purpose).');
                    end
                    Eyelink('Message', 'TRIALID %d', sm.trial_count);
                    Eyelink('Command', 'record_status_message "TRIAL %d/%d"', sm.trial_count, length(sm.tgt.trial));
                    sm.trial_start_time = est_next_vbl;
                    sm.attention.vis = false;
                    sm.center.vis = true;
                    sm.target.vis = true;
                    sm.cursor.vis = true;
                    sm.probe.vis = false;
                    sm.press_time = 0;
                    sm.failed_this_trial = 0;
                    sm.debounce = true;
                    sm.center.x = w.center(1) + u.x_mm2px(block.center.offset.x);
                    sm.center.y = w.center(2) + u.y_mm2px(block.center.offset.y);
                    sm.target.x = sm.center.x;

                    % subtract to put toward top of the screen
                    sm.target.y = sm.center.y - u.x_mm2px(block.target.distance);

                    % see tests/box_test.m for minimal drawing example
                    attention_locations = block.attention_locations{trial.attention_type};

                    if ~isempty(attention_locations)
                        attention_xys = u.x_mm2px(attention_locations);
                        attention_xys(:, 1) = sm.center.x - attention_xys(:, 1);
                        attention_xys(:, 2) = sm.center.y - attention_xys(:, 2);
                        attention_size = u.x_mm2px(block.attention.size);
                        rects = CenterRectOnPoint(attention_size, attention_xys(:, 1), attention_xys(:, 2));
                        sm.attention.rects = rects;
                    else
                        sm.attention.rects = [];
                    end

                    % schedule sound onset
                    if trial.reach_or_probe == 1 % reach
                        sm.current_sound = sm.beeps('low');
                    elseif trial.reach_or_probe == 2 % probe
                        sm.current_sound = sm.beeps('high');
                    else % oops
                        error('Unexpected reach_or_probe type, should be 1 or 2??');
                    end

                    hold_time = 1;
                    t_pred = PredictVisualOnsetForTime(w.w, est_next_vbl + hold_time);
                    PsychPortAudio('Start', sm.current_sound, 1, t_pred, 0);

                end

                % stuff that happens every frame

                % transition conditions
                % TODO: deleted debouncing, was that important?
                if point_in_circle([sm.cursor.x sm.cursor.y],
                                   [sm.center.x sm.center.y], ...
                                   u.x_mm2px(block.center.size - block.cursor.size) * 0.5) && gaze_in_center
                    sm.attention.vis = true;
                    status = PsychPortAudio('GetStatus', sm.current_sound);
                    % if the sound is playing, they've held in the center for long enough

                    if status.Active
                        % store the audio onset time for reaction times, etc.
                        sm.beep_start_time = status.StartTime;

                        if trial.reach_or_probe == 1
                            sm.state = states.REACH;
                        elseif trial.reach_or_probe == 2
                            sm.state = states.PROBE;
                        else
                            error('Also unexpected reach_or_probe type, should be 1 or 2?!?!');
                        end
                    end
                else
                    hold_time = 1;
                    t_pred = PredictVisualOnsetForTime(w.w, est_next_vbl + hold_time);
                    % TODO: make sure device is idle (not playing?) before this!
                    status = PsychPortAudio('GetStatus', sm.current_sound);
                    % if the sound is playing, they've held in the center for long enough

                    % if status.Active
                    PsychPortAudio('RescheduleStart', sm.current_sound, t_pred, 0);
                    % else
                    %     PsychPortAudio('Start', sm.current_sound, 1, t_pred, 0);
                    % end
                end
            end % RETURN_TO_CENTER

            % reach-related states
            if sm.state == states.REACH

                if sm.entering()
                    sm.attention.vis = false;
                end

                if ~gaze_in_center
                    sm.state = states.STOPPED_FIXATING;
                end
                % Movement trial logic
                % Implement logic for Movement trials
                % Example: Check for collisions, movement speed, etc.
                d1 = distance(sm.center.x, sm.cursor.x, sm.center.y, sm.cursor.y);
                d2 = distance(sm.center.x, sm.target.x, sm.center.y, sm.target.y);
                % disp(sprintf('d1: %.4f, d2: %.4f ', d1, d2));
                if (d1 > d2) 
                    sm.state = states.REACH_GOOD;
                    sm.cursor.vis = false;
                end

                % TODO: double check that directions actually work
                if trial.attention_type == 1
                    angs = block.angles;
                elseif trial.attention_type == 2
                    angs = flip(block.angles);
                else
                    error('Unknown attention type!');
                end

                %target_angle = atan2d(sm.target.y - sm.center.y, sm.target.x - sm.center.x);
                d = distance(sm.cursor.x, sm.center.x, sm.cursor.y, sm.center.y);
                sm.cursor.x = d * cosd(angs(1)) + sm.center.x;
                sm.cursor.y = d * sind(angs(2)) + sm.center.y;

                if (last_vbl - sm.beep_start_time > block.max_movement_rt) && ...
                    point_in_circle([sm.cursor.x sm.cursor.y],
                                    [sm.center.x sm.center.y], ...
                                    u.x_mm2px(block.center.size - block.cursor.size) * 0.5)
                    sm.state = states.REACH_RT_TOO_SLOW;
                    
                end

                % if they take too long to complete the movement, fail early
                if (last_vbl - sm.beep_start_time > block.max_movement_mt)
                    sm.state = states.REACH_MT_TOO_SLOW;
                end

            end %REACH


            if sm.state == states.REACH_RT_TOO_SLOW
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                    end
                end
            end % REACH_RT_TOO_SLOW


            if sm.state == states.REACH_MT_TOO_SLOW
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                    end
                end
            end % REACH_MT_TOO_SLOW


            if sm.state == states.REACH_GOOD
                
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.success_time;
                    PsychPortAudio('Start', sm.beeps('over'), 1, 0, 0);
                    %disp(block.success_time)
                end
                        %disp(sm.state_exit_time)
                        %disp(est_next_vbl)
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                        %disp('check1')
                    if (sm.trial_count + 1) > length(tgt.trial)
                            %disp('check2')
                        sm.state = states.END;
                    else
                            %disp('check3')
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                    end
                end
            end % REACH_GOOD

            %% Probe-related states
            if sm.state == states.PROBE
                if sm.entering()
                    KbQueueFlush(sm.kb);
                    sm.attention.vis = false;
                    % at some variable time, show the probe
                end
                if ~gaze_in_center
                    sm.state = states.STOPPED_FIXATING;
                end
                % stuff that happens every frame
                time_into_trial = est_next_vbl - sm.beep_start_time;

                [press, first_press] = KbQueueCheck(sm.kb);
                if press
                    press_time = min(first_press(first_press > 0));
                    sm.press_time = press_time - trial.probe.onset_time - sm.beep_start_time;
                end

                if ~sm.probe.vis && time_into_trial >= trial.probe.onset_time
                    % draw the probe
                    sm.probe.vis = true;
                    sm.probe.x = trial.probe.x;
                    sm.probe.y = trial.probe.y;
                end

                % start with failure conditions
                if ~point_in_circle([sm.cursor.x sm.cursor.y],
                                    [sm.center.x sm.center.y], ...
                                     u.x_mm2px(block.center.size - block.cursor.size) * 0.5)
                    sm.probe.vis = false;
                    sm.state = states.PROBE_MOVED;
                end

                if ~sm.probe.vis && sm.press_time
                    sm.probe.vis = false;
                    sm.state = states.PROBE_EARLY_PRESS;
                end

                if sm.probe.vis && time_into_trial >= (trial.probe.onset_time + 0.8)
                    sm.probe.vis = false;
                    sm.state = states.PROBE_LATE_PRESS;
                end

                        % success
                if sm.probe.vis && sm.press_time
                    sm.probe.vis = false;
                    sm.state = states.PROBE_GOOD;
                end


            end % PROBE

            if sm.state == states.PROBE_EARLY_PRESS
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                        sm.probe.vis = false;
                    end
                end
            end % PROBE_EARLY_PRESS

            if sm.state == states.PROBE_LATE_PRESS
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                        sm.probe.vis = false;
                    end
                end
            end % PROBE_LATE_PRESS

            if sm.state == states.PROBE_MOVED
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                        sm.probe.vis = false;
                    end
                end
            end % PROBE_MOVED

            if sm.state == states.PROBE_GOOD

                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.success_time;
                    PsychPortAudio('Start', sm.beeps('over'), 1, 0, 0);
                end
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                        sm.probe.vis = false;
                    end
                end
            end % PROBE_GOOD %%attention trials were here

            if sm.state == states.STOPPED_FIXATING
                if sm.entering()
                    sm.cursor.vis = false;
                    sm.state_exit_time = est_next_vbl + block.punishment_time;
                end
                        % stuff that happens every frame
                if est_next_vbl >= sm.state_exit_time
                    if (sm.trial_count + 1) > length(tgt.trial)
                        sm.state = states.END;
                    else
                        sm.state = states.RETURN_TO_CENTER;
                        sm.trial_count = sm.trial_count + 1;
                        sm.within_trial_frame_count = 1;
                        sm.probe.vis = false;
                    end
                end % STOPPED_FIXATING
            end
        end % update


        function draw(sm)
            block = sm.tgt.block;
            trial = sm.tgt.trial(sm.trial_count);
            MAX_NUM_CIRCLES = 5;
            xys = zeros(2, MAX_NUM_CIRCLES);
            sizes = zeros(1, MAX_NUM_CIRCLES);
            colors = zeros(3, MAX_NUM_CIRCLES, 'uint8');

            counter = 1;
            w = sm.w.w;
            wh = sm.w.rect(4);
            u = sm.un;

            % clear to black on the eyelink display
            % Eyelink('Message', '!V CLEAR %d %d %d', 0, 0, 0); % we're not using DataViewer, does it even matter?
            Eyelink('Command', 'clear_screen 0');
            sz = block.center.size * 0.5;
            x = sm.center.x;
            y = sm.center.y;
            Eyelink('Command', 'draw_box %d %d %d %d 7', x - sz, y - sz, x + sz, y + sz);
            Eyelink('Command', 'draw_cross %d %d 15', sm.last_eye_event.x, sm.last_eye_event.y);

            % draw where they're looking
            if 1 % turn off after debugging
                xys(:, counter) = [sm.last_eye_event.x sm.last_eye_event.y];
                sizes(counter) = 10; % px
                colors(:, counter) = [255, 0, 0]; % red
                counter = counter + 1;
            end

            % draw circles first
            if sm.center.vis
                xys(:, counter) = [sm.center.x sm.center.y];
                sizes(counter) = u.x_mm2px(block.center.size);
                colors(:, counter) = block.center.color;
                counter = counter + 1;
            end

            if sm.target.vis
                xys(:, counter) = [sm.target.x sm.target.y];
                sizes(counter) = u.x_mm2px(block.target.size);
                colors(:, counter) = block.target.color;
                counter = counter + 1;
            end

            if sm.cursor.vis
                xys(:, counter) = [sm.cursor.x sm.cursor.y];
                sizes(counter) = u.x_mm2px(block.cursor.size);
                colors(:, counter) = block.cursor.color;
                counter = counter + 1;
            end

            if sm.probe.vis
                mid_x = (sm.center.x + sm.target.x) * 0.5;
                mid_y = (sm.center.y + sm.target.y) * 0.5;
                px = u.x_mm2px(trial.probe.x) + mid_x;
                py = u.y_mm2px(trial.probe.y) + mid_y;
                xys(:, counter) = [px py];
                sizes(counter) = u.x_mm2px(block.probe.size);
                colors(:, counter) = block.probe.color;
                counter = counter + 1;
            end

            if sm.attention.vis && ~isempty(sm.attention.rects) && trial.attention_type == 1
                % Screen('DrawText', w, block.attention.color, sm.attention.rects.');
                DrawFormattedText(w, 'left', 'center', 0.6 * wh, [222, 75, 75]);
            elseif sm.attention.vis && ~isempty(sm.attention.rects) && trial.attention_type == 2
                % Screen('DrawText', w, block.attention.color, sm.attention.rects.');
                DrawFormattedText(w, 'right', 'center', 0.6 * wh, [222, 75, 75]);
            end

            if counter > 1
                Screen('DrawDots', w, xys(:, 1:counter), sizes(1:counter), colors(:, 1:counter), [], 3, 1);
            end

            txt = '';
            
            if sm.state == states.REACH_RT_TOO_SLOW
                txt = 'Move sooner.';
            elseif sm.state == states.REACH_MT_TOO_SLOW
                txt = 'Move faster.';
            elseif sm.state == states.PROBE_EARLY_PRESS
                txt = 'Pressed before probe visible.';
            elseif sm.state == states.PROBE_LATE_PRESS
                txt = 'Pressed too late.';
            elseif sm.state == states.PROBE_MOVED
                txt = 'Do not move on probe trial.';
            elseif sm.state == states.STOPPED_FIXATING
                txt = 'Remember to keep fixating on the starting target.';
            end

            if txt
                % if they ever saw text, they did something wrong
                sm.failed_this_trial = 1;
                DrawFormattedText(w, txt, 'center', 0.6 * wh, [222, 75, 75]);
            end

            Screen('DrawText', w, sprintf('%i/%i', sm.trial_count, length(sm.tgt.trial)), 10, 10, 128);

            
        end % draw

        function state = get_state(sm)
            state = sm.state;
        end

        function center = get_raw_center_state(sm)
            center = sm.center;
        end

        function [tc, wtc] = get_counters(sm)
            tc = sm.trial_count;
            wtc = sm.within_trial_frame_count;
        end

        function val = will_be_new_trial(sm)
            % should we subset?
            val = sm.is_transitioning && (sm.state == states.RETURN_TO_CENTER || sm.state == states.END);
        end

        function restart_trial(sm)
            % restart the current trial
            sm.state = states.RETURN_TO_CENTER;
            sm.within_trial_frame_count = 1;
            sm.trial_start_time = 9e99; % single-frame escape hatch
        end

    end % methods

    methods (Access = private)
        function ret = entering(sm)
            ret = sm.is_transitioning;
            sm.is_transitioning = false;
        end

        % Octave buglet? can set state here even though method access is private
        % but fixed by restricting property access, so not an issue for me
        function state = set.state(sm, value)
            sm.is_transitioning = true; % assume we always mean to call transition stuff when calling this
            sm.state = value;
            Eyelink('Message', 'STATE %d', value);
        end
    end % private methods


end % StateMachine