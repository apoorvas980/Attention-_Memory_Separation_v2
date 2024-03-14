function out = gen_beep(freq, duration, sampling_rate)
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