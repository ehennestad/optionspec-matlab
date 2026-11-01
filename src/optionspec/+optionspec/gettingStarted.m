function gettingStarted()
    % GETTINGSTARTED Open the getting started guide for the toolbox
    %
    %   GETTINGSTARTED() opens the getting started guide for the toolbox.
    %
    %   Example:
    %       optionspec.gettingStarted()
    %
    %   See also optionspec.Definition, optionspec.toolboxdir, optionspec.toolboxversion

    % Display welcome message
    fprintf('Welcome to %s!\n\n', 'OptionSpec');
    fprintf('%s\n\n', 'Versioned option definitions in JSON Schema, with JSON value documents and migrations');
    
    % Display version information
    fprintf('Version: %s\n', optionspec.toolboxversion());
    
    % Display directory information
    fprintf('Toolbox directory: %s\n\n', optionspec.toolboxdir());
    
    % Display available functions
    fprintf('Available functions:\n');
    fprintf('  - optionspec.Definition\n');
    fprintf('  - optionspec.toolboxdir\n');
    fprintf('  - optionspec.toolboxversion\n');
    fprintf('  - optionspec.gettingStarted\n\n');
    
    % Display examples
    fprintf('Examples:\n');
    examplesDir = fullfile(optionspec.toolboxdir(), 'examples');
    if isfolder(examplesDir)
        exampleFiles = dir(fullfile(examplesDir, '*.m'));
        if ~isempty(exampleFiles)
            for i = 1:length(exampleFiles)
                fprintf('  - %s\n', exampleFiles(i).name);
            end
        else
            fprintf('  No examples found.\n');
        end
    else
        fprintf('  Examples directory not found.\n');
    end
    
    fprintf('\nFor more information, see https://github.com/ehennestad/optionspec-matlab\n');
end
