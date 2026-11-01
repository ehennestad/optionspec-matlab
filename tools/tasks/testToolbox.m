function testToolbox(varargin)
% testToolbox - Run the toolbox tests with MatBox
%
%   testToolbox() runs the tests in the tests folder, measures coverage of
%   the src/optionspec folder and saves the reports in docs/reports. Name-value arguments other than
%   SourceFolderName are passed on to matbox.tasks.testToolbox.
%
%   The test workflow calls this function when it is on the path, so local
%   runs and CI runs use the same settings.

    optionspectools.installMatBox()
    projectRootDirectory = optionspectools.projectdir();
    % The source folder is passed last so it overrides the one the CI workflows
    % pass, which is the src folder above it
    matbox.tasks.testToolbox(projectRootDirectory, ...
        "TestsFolderName", "tests", ...
        varargin{:}, ...
        "SourceFolderName", fullfile("src", "optionspec"));
end
