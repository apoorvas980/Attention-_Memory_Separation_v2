% the "real" part of the experiment
%{
Eyetracking components from
https://github.com/kleinerm/Psychtoolbox-3/blob/eyelinktoolboxrc/Psychtoolbox/PsychHardware/EyelinkToolbox/EyelinkDemos/SR-ResearchDemos/GazeContingent/FixWindowBufferedSamples/EyeLink_FixWindowBufferedSamples.m

The idea behind using the buffered samples is that we would get saccade events from the system, rather than on-the-fly computation with the lastest sample
Decided to use buffered version because the display (and therefore event loop rate) is ~60Hz, which is close to too low for saccades, and way too low for 
microsaccades?

%}

function _vmr_exp(is_debug, is_short, group, block_type, settings)
    % profile on;
    
    start_unix = floor(time());
    start_dt = datestr(clock(), 31); %Y-M-D H:M:S
    % beats me why we do this? it's in the eyetracking example
    if ~IsOctave; commandwindow; end

    dummy_mode = 0;
    EyelinkInit(dummy_mode);
    if Eyelink('IsConnected') < 1
        dummy_mode = 1;
    end

    % note that the usual participant ID (msl***) is far too long, so we just take the last 5 numbers and hope for the best
    id = settings.id;
    slice = min(length(id) - 1, 5);
    edf_filename = strcat(settings.id(end-slice:end), '_', num2str(start_unix)); % TODO: need to include EDF extension?
    edf_filename = edf_filename(1:8); % because we're in the stone ages and can't have a longer filename than 8 chars
    failed = Eyelink('OpenFile', edf_filename);
    if failed ~= 0
        error('Failed to open EDF file with name %s', edf_filename);
    end

    eye_software_ver = 0;
    [ver, verstr] = Eyelink('GetTrackerVersion');
    % TODO: any reason we should check dummy_mode instead? Can a successful connection ever return an invalid version number/string?
    if ver ~= 0
        [~, vnumcell] = regexp(verstr,'.*?(\d)\.\d*?','Match','Tokens'); % Extract EL version before decimal point
        eye_software_ver = str2double(vnumcell{1}{1}); % Returns 1 for EyeLink I, 2 for EyeLink II, 3/4 for EyeLink 1K, 5 for EyeLink 1KPlus, 6 for Portable Duo
        % Print some text in Matlab's Command Window
        fprintf('Eyelink: Running experiment on %s version %d\n', verstr, ver);
    end

    Eyelink('Command', 'add_file_preamble_text "%s"', sprintf('motor memory attention task TODO extra info here'));

    % Select which events are saved in the EDF file. Include everything just in case
    Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    % Select which events are available online for gaze-contingent experiments. Include everything just in case
    Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
    % Select which sample data is saved in EDF file or available online. Include everything just in case
    if eye_software_ver > 3  % Check tracker version and include 'HTARGET' to save head target sticker data for supported eye trackers
        Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
        Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
    else
        Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,GAZERES,BUTTON,STATUS,INPUT');
        Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
    end
    

    % constants
    X_PITCH = 0.2832; % pixel pitch, specific to "real" monitor
    Y_PITCH = 0.2802; % note the non-squareness (though for sizes/distances < ~45mm)
    unit = Unitizer(X_PITCH, Y_PITCH);

    tgt = make_tgt(settings.id, block_type, is_short, group);
    % allocate data before running anything
    data = _alloc_data(length(tgt.trial));

    % turn off splash
    KbName('UnifyKeyNames');
    ESC = KbName('ESCAPE');
    Screen('Preference', 'VisualDebugLevel', 3);
    screens = Screen('Screens');
    max_scr = max(screens);

    w = struct(); % container for window-related things

    if is_debug % tiny window, skip all the warnings
        Screen('Preference', 'SkipSyncTests', 2); 
        Screen('Preference', 'VisualDebugLevel', 0);
        [w.w, w.rect] = Screen('OpenWindow', max_scr, 0, [0, 0, 1000, 1000]);
    else
        % real deal, make sure sync tests work
        % for the display (which is rotated 180 deg), we need
        % to do this. Can't use OS rotation, otherwise PTB gets mad
        PsychImaging('PrepareConfiguration');
        [w.w, w.rect] = PsychImaging('OpenWindow', max_scr, 0);
    end

    [w.center(1), w.center(2)] = RectCenter(w.rect);
    % assume color is 8 bit, so don't fuss with WhiteIndex/BlackIndex
    Screen('BlendFunction', w.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('TextSize', w.w, floor(0.06 * w.rect(4)));
    Screen('Flip', w.w); % flip once to warm up
    KbCheck(-1); % force mex load

    w.fps = Screen('FrameRate', w.w);
    w.ifi = Screen('GetFlipInterval', w.w);
    Priority(MaxPriority(w.w));

    w.max_color = Screen('ColorRange', w.w);
    w.gray_color = GrayIndex(w.w);
    w.black_color = BlackIndex(w.w);

    % Eyelink setup, continued
    eyelink = EyelinkInitDefaults(w.w);
    eyelink.calibrationtargetsize = 3; % Outer target size as percentage of the screen
    eyelink.calibrationtargetwidth = 0.7; % Inner target size as percentage of the screen
    eyelink.backgroundcolour = w.black_color; % NB: try to match luminance of the task
    eyelink.calibrationtargetcolour = w.gray_color; % see if we need to repmat or not
    eyelink.msgfontcolour = w.gray_color;

    % X11 apparently gets it really wrong with extended screen, but even gets height wrong??
    % actually gets it wrong with single screen too, so...
    % randr seems to nail it though
    % and for this round, we've just gotten the size from the manual (see *_PITCH above)
    % [w.disp.width, w.disp.height] = Screen('DisplaySize', max_scr);

    InitializePsychSound(1);

    % TODO: add group
    sm = StateMachine(settings.base_path, tgt, w, unit);

    % hide the cursor
    % more for the sake of the operator mouse rather than tablet, which is probably
    % floating at this point
    if ~is_debug
        HideCursor(w.w);
    end

    % Eyelink setup, continued again (now that we have an audio device)
    pahandle = PsychPortAudio('OpenSlave', sm.aud, 1);
    eyelink.ppa_pahandle = pahandle;
    EyelinkUpdateDefaults(eyelink);
    Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, w.rect(3) - 1, w.rect(4) - 1);
    Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, w.rect(3) - 1, w.rect(4) - 1);
    Eyelink('Message', 'calibration_type = HV5'); % horizontal-vertical 5-points, keep it simple
    Eyelink('Command', 'clear_screen 0');

    EyelinkDoTrackerSetup(eyelink);


    % alloc temporary data for input events
    evts(1:20) = struct('t', 0, 'x', 0, 'y', 0);

    ListenChar(-1); % disable keys landing in console

    % joystick pretends to be both mouse *and* A key
    % valuators 3 & 4 are the "raw" axes
    % I think it generates an event per axis change,
    % i.e. if x and y change simultaneously it'll report
    % an event per axis (which I think jives with what I know about evdev?)
    joy = findDev('Thrustmaster T.16000M');
    PsychHID('KbQueueCreate', joy, [], 4, [], 0);
    % start device
    % use KbQueueCheck for trigger &
    % KbQueueGetEvent for axes
    PsychHID('KbQueueStart', joy);

    % flip once more to get a reference time
    % we're assuming linux computers with OpenML support
    % vbl_time helps with scheduling flips, and ref_time helps with relating
    % to input events (b/c it *should* be when the stimulus changes on the screen)
    [vbl_time, disp_time] = Screen('Flip', w.w);
    ref_time = disp_time;
    was_restarted = false;

    frame_count = 1;
    KbQueueFlush(joy, 2); % only flush KbEventGet
    [trial_count, within_trial_frame_count] = sm.get_counters();

    while (beginning_state = sm.get_state())
        % break if esc pressed
        [~, ~, keys] = KbCheck(-1); % query all keyboards
        if keys(ESC) && vbl_time > ref_time + 10
            error('Escape was pressed.');
        end

        % pause, and restart trial when unpaused
        % if they just started the trial, this will re-pause if they delayed more than
        % 20 seconds. I'll fix it eventually, but doesn't really impact things (just jam the "C" key until caught up)
        if (vbl_time - sm.trial_start_time) > 60
            was_restarted = true;
            warning(sprintf('Paused on trial %i', trial_count));
            DrawFormattedText(w.w, 'Paused, press "C" to restart trial', 'center', 'center', 255);
            Screen('Flip', w.w);
            C = KbName('C');
            while true
                [~, keys, ~] = KbWait(-1, 2);
                if keys(C)
                    % restart the trial
                    sm.restart_trial();
                    KbQueueFlush(dev.index, 2);
                    break
                end

                if keys(ESC)
                    error('Escape was pressed.');
                end
            end
            continue % restart this frame
        end

        % sleep part of the frame to reduce lag
        % TODO: tweak this if we end up doing the 120hz + strobing
        % we probably only need 1-2ms to do state updates
        % for 240hz, this cuts off up to 2ms or so?
        % WaitSecs('UntilTime', vbl_time + 0.5 * w.ifi);
        t0 = GetSecs(); % time how long it takes to process the frame
        % process all pending input events
        % check number of pending events once, which should be robust
        % to higher-frequency devices
        n_evts = KbEventAvail(joy);
        % TODO: does MATLAB do non-copy slices?? This sucks
        % is it faster to make this each frame, or to copy from some preallocated chunk?
        % won't execute if event queue is empty
        center = sm.get_raw_center_state(); % still in px
        for i = 1:n_evts
            % events are in the same coordinates as psychtoolbox (px)
            % eventually, we would figure out mapping so that we get to use
            % the full range of valuators, but I haven't been able to get
            % it right yet. So for now, we're stuck with slightly truncated resolution
            % (but still probably plenty)
            [evt, ~] = PsychHID('KbQueueGetEvent', joy, 0);
            evts(i).t = evt.Time;
            v = evt.Valuators;
            % scale the joystick from int16 to 
            v = v / 65536; % scale to 0:1
            % convert to screen pixels (i.e. scaled to height of display)
            v = v * w.rect(4);
            % center on the starting position
            evts(i).x = v(3) + center.x;
            evts(i).y = v(4) + center.y;
        end

        % when we increment a trial, we can reset within_trial_frame_count to 1
        % for the state machine, implement fallthrough by consecutive `if ...`
        % grab counters before they're updated for this frame
        [trial_count, within_trial_frame_count] = sm.get_counters();
        if n_evts < 1
            sm.update([], vbl_time);
        else
            % pass all input events so we can get a decent RT if need be
            sm.update(evts(1:n_evts), vbl_time);
        end
        sm.draw(); % instantiate visuals
        t1 = GetSecs();
        Screen('DrawingFinished', w.w);
        % do other work in our free time
        for i = 1:n_evts % skips if n_evts == 0
            data.trials.frames(trial_count).input_events(within_trial_frame_count).t(i) = evts(i).t;
            data.trials.frames(trial_count).input_events(within_trial_frame_count).x(i) = unit.x_px2mm(evts(i).x);
            data.trials.frames(trial_count).input_events(within_trial_frame_count).y(i) = unit.y_px2mm(evts(i).y);
            % disp('test')
            % TODO: should we store (redundant) position in physical units, or leave for post-processing?
        end
        ending_state = sm.get_state();
        % take subset to reduce storage size (& because anything else is junk)
        % again, I *really* wish I could just take an equivalent to a numpy view...
        % disp(n_evts)
        % disp(sm.get_state)
        % disp(within_trial_frame_count) 
        % disp(trial_count)       
        data.trials.frames(trial_count).input_events(within_trial_frame_count).t = data.trials.frames(trial_count).input_events(within_trial_frame_count).t(1:n_evts);
        data.trials.frames(trial_count).input_events(within_trial_frame_count).x = data.trials.frames(trial_count).input_events(within_trial_frame_count).x(1:n_evts);
        data.trials.frames(trial_count).input_events(within_trial_frame_count).y = data.trials.frames(trial_count).input_events(within_trial_frame_count).y(1:n_evts);

        % swap buffers
        % use vbl_time to schedule subsequent flips, and disp_time for actual
        % stimulus onset time
        [vbl_time, disp_time, ~, missed, ~] = Screen('Flip', w.w, vbl_time + 0.95 * w.ifi);
        % done the frame, we'll write frame data now?
        data.trials.frames(trial_count).frame_count(within_trial_frame_count) = frame_count;
        data.trials.frames(trial_count).vbl_time(within_trial_frame_count) = vbl_time;
        data.trials.frames(trial_count).disp_time(within_trial_frame_count) = disp_time;
        data.trials.frames(trial_count).missed_frame_deadline(within_trial_frame_count) = missed >= 0;
        data.trials.frames(trial_count).start_state(within_trial_frame_count) = beginning_state;
        data.trials.frames(trial_count).end_state(within_trial_frame_count) = ending_state;
        data.trials.frames(trial_count).frame_comp_dur(within_trial_frame_count) = t1 - t0;

        if sm.will_be_new_trial()
            % prune our giant dataset, this is the last frame of the trial
            % TODO: should we let saving trial-level data be handled by the state machine,
            % or let it leak here?
            % we don't need to keep in sync if we use dynamic names:
            for fn = fieldnames(tgt.trial(trial_count))'
                data.trials.(fn{1})(trial_count) = tgt.trial(trial_count).(fn{1});
            end
            data.trials.was_restarted(trial_count) = was_restarted;
            data.trials.press_time(trial_count) = sm.press_time;
            data.trials.failed(trial_count) = sm.failed_this_trial;
            was_restarted = false;
            % alternatively, we just save these without context
            for fn = fieldnames(data.trials.frames(trial_count))'
                data.trials.frames(trial_count).(fn{1}) = data.trials.frames(trial_count).(fn{1})(1:within_trial_frame_count);
            end
        end

        frame_count = frame_count + 1; % grows forever/applies across entire experiment
    end

    KbQueueStop(joy);
    KbQueueRelease(joy);
    DrawFormattedText(w.w, 'Finished, saving data...', 'center', 'center', 255);
    last_flip_time = Screen('Flip', w.w);

    % write data
    data.block.id = settings.id;
    data.block.is_debug = is_debug;
    [status, data.block.git_hash] = system("git log --pretty=format:'%H' -1 2>/dev/null");
    if status
        warning('git hash failed, is git installed?');
    end
    [status, data.block.git_branch] = system("git rev-parse --abbrev-ref HEAD | tr -d '\n' 2>/dev/null");
    if status
        warning('git branch failed, is git installed?');
    end
    [status, data.block.git_tag] = system("git describe --tags | tr -d '\n' 2>/dev/null");
    if status
        warning('git tag failed, has a release been tagged?');
    end
    data.block.sysinfo = uname();
    data.block.oct_ver = version();
    [~, data.block.ptb_ver] = PsychtoolboxVersion();
    info = Screen('GetWindowInfo', w.w); % grab renderer info before cleaning up
    data.block.gpu_vendor = info.GLVendor;
    data.block.gpu_renderer = info.GLRenderer;
    data.block.gl_version = info.GLVersion;
    data.block.missed_deadlines = info.MissedDeadlines;
    data.block.n_flips = info.FlipCount;
    data.block.pixel_pitch = [X_PITCH Y_PITCH];
    data.block.start_unix = start_unix; % whole seconds since unix epoch
    data.block.start_dt = start_dt;
    % mapping from numbers to strings for state
    % these should be in order, so indexing directly (after +1, depending on lang) with `start_state`/`end_state` should work (I hope)
    warning('off', 'Octave:classdef-to-struct');
    fnames = fieldnames(states);
    lfn = length(fnames);
    fout = cell(lfn, 1);
    for i = 1:lfn
        name = fnames{i};
        fout{states.(name)+1} = name;
    end
    data.block.state_names = fout;
    
    % copy common things over
    for fn = fieldnames(tgt.block)'
        data.block.(fn{1}) = tgt.block.(fn{1});
    end

    % data.summary = sm.get_summary(); % get the summary array stored by the state machine. Should only be non-tgt stuff (computed reach angle, RT, ...)
    % write data
    mkdir(settings.data_path); % might already exist, but it doesn't error if so
    to_json(fullfile(settings.data_path, strcat(settings.id, '_', num2str(data.block.start_unix), '.json')), data, 1);
    WaitSecs('UntilTime', last_flip_time + 2); % show last msg for at least 2 sec
    DrawFormattedText(w.w, 'Done!', 'center', 'center', 255);
    last_flip_time = Screen('Flip', w.w);
    WaitSecs('UntilTime', last_flip_time + 1);
    _cleanup(); % clean up
    % profile off;
    % profshow;
end
