% https://github.com/aforren1/HierDynamics2/blob/main/hier_main.m#L100

ListenChar(-1);
KbName('UnifyKeyNames');
SPACE = KbName('SPACE');

keys = zeros(1, 256);

keys(SPACE) = 1;

kb_idx = [];
KbQueueCreate(kb_idx, keys);
KbQueueStart(kb_idx);

t0 = GetSecs();
t1 = t0 + 10;

KbQueueFlush(kb_idx); % demonstrate clearing keyboard queue between trials

while (GetSecs() < t1)
    [press, first_press] = KbQueueCheck(kb_idx);
    if press
        press_time = min(first_press(first_press > 0));
        dt = press_time - t0;
        %t0 = press_time;
        disp(sprintf('SPACE pressed at %f', dt));
    end
end

KbQueueStop(kb_idx);
KbQueueRelease(kb_idx);
ListenChar(0);
