function copy_edf_file(dummy_mode, data_path)
    if ~dummy_mode % connected to eyelink
        fprintf('Saving the EDF file to the local computer...');
        status = Eyelink('ReceiveFile', [], data_path, true); % success if > 0, 0 = cancelled, < 0 = error code
        if status <= 0
            warning('EDF file transfer failed, status code %d', status);
        end
    else
        fprintf('EDF file is not saved in dummy mode.');
    end
end
