devs = PsychHID('Devices', 5);
% Just "Up" and "Down" when not unified, unification adds *Arrow suffix
%KbName('UnifyKeyNames');
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

fail = true;

for k = devs

  if strcmp(k.product, 'Thrustmaster T.16000M (keys)')
    fail = false;
    break
  end

end

if fail
  error('Joystick not found :(');
end

% valuators 3 & 4 are the "raw" axes
% I think it generates an event per axis change,
% i.e. if x and y change simultaneously it'll report
% an event per axis (which I think jives with what I know about evdev?)
PsychHID('KbQueueCreate', d.index, [], 4, [], 0);
PsychHID('KbQueueCreate', k.index);

PsychHID('KbQueueStart', d.index);
PsychHID('KbQueueStart', k.index);
t1 = GetSecs() + 10;

last_evt = struct('Time', 0);

while GetSecs() < t1
  [evt, navail] = PsychHID('KbQueueGetEvent', d.index);
  [press, first_press] = KbQueueCheck(k.index);

  if ~isempty(evt)
    v = evt.Valuators;
    v = v / 32768;
    fprintf('%i, %i, %f, %i\n', v(3), v(4), evt.Time - last_evt.Time, navail);
    %disp(evt);
    %disp(evt.Time - last_evt.Time);
    last_evt = evt;
  end

  if press
    fprintf('key: %s at %.4f\n', KbName(first_press), min(first_press(first_press > 0)));
  end

end

PsychHID('KbQueueStop', d.index);
PsychHID('KbQueueRelease', d.index);

PsychHID('KbQueueStop', k.index);
PsychHID('KbQueueRelease', k.index);
