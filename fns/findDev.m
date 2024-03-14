function out = findDev(str)
  devs = PsychHID('Devices', 5);
  fail = true;

  for d = devs
    if strcmp(d.product, str)
      fail = false;
      break
    end
  end

  if fail
    error('Device not found :(');
  end

  out = d.index;
end
