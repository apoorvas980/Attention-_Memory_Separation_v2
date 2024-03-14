MAXIMUM = 2^16;
MOO = 1000;
devs = PsychHID('Devices', 5);

fail = true;

for d = devs

  if strcmp(d.product, 'Thrustmaster T.16000M')
    fail = false;
    break
  end

end

if fail
  error('Joystick not found :(');
end

KbName('UnifyKeyNames');
ESC = KbName('ESCAPE');
Screen('Preference', 'VisualDebugLevel', 3);
screens = Screen('Screens');
max_scr = max(screens);

w = struct();

Screen('Preference', 'SkipSyncTests', 2);
Screen('Preference', 'VisualDebugLevel', 0);
[w.w, w.rect] = Screen('OpenWindow', max_scr, 50, [0, 0, MOO, MOO], [], [], [], []);

[w.center(1), w.center(2)] = RectCenter(w.rect);

% valuators 3 & 4 are the "raw" axes
% I think it generates an event per axis change,
% i.e. if x and y change simultaneously it'll report
% an event per axis (which I think jives with what I know about evdev?)
PsychHID('KbQueueCreate', d.index, [], 4, [], 0);

PsychHID('KbQueueStart', d.index);
x = 0;
y = 0;

nan_pool = nan(2, 400 * 400);
nan_pool(:, 1) = 0;
counter = 1;
foo2 = 1;

while 1
  [~, ~, keys] = KbCheck(-1); % query all keyboards

  if keys(ESC)
    break;
  end

  navail = 1;

  while navail
    [evt, navail] = PsychHID('KbQueueGetEvent', d.index);

    if ~isempty(evt) && navail == 0
      v = evt.Valuators;
      %disp(v);
      x = v(3);
      y = v(4);
      disp(v(3:4) / MAXIMUM)
      x = x / MAXIMUM * MOO + w.center(1);
      y = y / MAXIMUM * MOO + w.center(2);
      nan_pool(1, foo2) = x;
      nan_pool(2, foo2) = y;
      counter = rem(counter, 100) + 1;
      foo2 = foo2 + 1;
    end

  end

  if foo2 > 100
    rnger = foo2;
  else
    rnger = counter;
  end

  Screen('DrawDots', w.w, nan_pool(:, 1:rnger), 1, 255, [], 3, 1);
  Screen('Flip', w.w);

end

PsychHID('KbQueueStop', d.index);
PsychHID('KbQueueRelease', d.index);

sca;
