
total_duration = 0.5;
sampling_rate = 48000;

function out = genBeep(freq, duration, sampling_rate)
% make a beep
    out = sin(2 * pi * freq * (0:(duration * sampling_rate)) / sampling_rate);
    out = apodize(out, sampling_rate);
    out = [out; out];
endfunction
% https://github.com/numpy/numpy/blob/96895a1d3e316dcb56b1ba451d5630e35f4c3c58/numpy/lib/function_base.py#L3175
% we *could* get hanning from signal pkg, but it's only a line or two...
function out = hanning(M)
    if (M <= 1)
        error('M must be > 1.');
    end
    n = (1-M):2:M;
    out = 0.5 + 0.5*cos(pi*n/(M-1));
endfunction


% https://github.com/psychopy/psychopy/blob/5d79806a5be72871262dabccf2eb83a7415e2522/psychopy/sound/_base.py#L48
function out = apodize(in, sampling_rate)
    hw_size = floor(sampling_rate / 200); % original had a len(in) // 15, but can't rationalize why...
    hanning_window = hanning(2 * hw_size + 1);
    out = in;
    out(1:hw_size) = out(1:hw_size) .* hanning_window(1:hw_size);
    out((end-hw_size+1):end) = out((end-hw_size+1):end) .* hanning_window((end-hw_size+1):end);
endfunction

%t = (0:(total_duration * sampling_rate))/sampling_rate;

%plot(t, out);

InitializePsychSound(1);
sounds = containers.Map();

audio = PsychPortAudio('Open', 
[], % default device
1 + 8, % playback only, master device
2, % full control of audio device
sampling_rate,
2); % number of channels

PsychPortAudio('Start', audio, 0, 0, 1);
PsychPortAudio('Volume', audio, 1); % TODO: ???

aud_status = PsychPortAudio('GetStatus', audio);
aud_freq = aud_status.SampleRate;

lo = genBeep(440, total_duration, sampling_rate);
hi = genBeep(823, total_duration, sampling_rate);
over = genBeep(440, total_duration, sampling_rate);

sounds('low') = PsychPortAudio('OpenSlave', audio, 1);
PsychPortAudio('FillBuffer', sounds('low'), lo);
sounds('high') = PsychPortAudio('OpenSlave', audio, 1);
PsychPortAudio('FillBuffer', sounds('high'), hi);
sounds('over') = PsychPortAudio('OpenSlave', audio, 1);
PsychPortAudio('FillBuffer', sounds('over'), over);

%{
  To play sound immediately (e.g. feedback),
  PsychPortAudio('Start', sound, 1, 0, 0);

  To schedule, compute the estimated time of the next frame & schedule then:
  t_pred = PredictVisualOnsetForTime(win, 0); % will give estimated time of next frame onset
  PsychPortAudio('Start', sound, 1, t_pred, 0);

  The time of the next flip ought to be a pretty good estimate of the sound onset too.
  If you want to be more careful, you'd need to do some sort of calibration step AFAIK?

  Reminder:don't use wireless headphones if you care about minimizing delay / jitter!
%}
t = GetSecs();
WaitSecs(2);
PsychPortAudio('Start', sounds('low'), 1, GetSecs() + 3, 0);
status = PsychPortAudio('GetStatus', sounds('low'));
disp(status.Active);
PsychPortAudio('Start', sounds('high'), 1, 0, 0);
WaitSecs(3.1);
status = PsychPortAudio('GetStatus', sounds('low'));
disp(status.Active);
disp(sprintf('req: %f, actual: %f, diff: %f', status.RequestedStartTime, status.StartTime, status.RequestedStartTime - status.StartTime))
WaitSecs(2);
status = PsychPortAudio('GetStatus', sounds('low'));
disp(status.Active);
PsychPortAudio('Start', sounds('over', 1, 0, 0));
status = PsychPortAudio('GetStatus', sounds('over'));
disp(status.Active);
PsychPortAudio('Close');
