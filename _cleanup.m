function _cleanup(dummy_mode, data_path)
    Priority(0);
    sca;
    PsychPortAudio('Close');
    PsychHID('KbQueueRelease');
    try
        Eyelink('StopRecording');
        Eyelink('SetOfflineMode');% Put tracker in idle/offline mode
        Eyelink('CloseFile'); % Close EDF file on Host PC
        Eyelink('Command', 'clear_screen 0');
        WaitSecs(0.5);
        if ~dummy_mode
            copy_edf_file(dummy_mode, data_path);
        end
    catch err
        warning('Tried to clean up Eyelink, but something went wrong...');
    end
    diary off;
    ListenChar(0);
end
