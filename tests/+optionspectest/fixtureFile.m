function filePath = fixtureFile(varargin)
%fixtureFile Path of a file in the tests/fixtures folder.
%
%   filePath = optionspectest.fixtureFile("definitions", "normcorre.json")

    testsFolder = fileparts(fileparts(mfilename("fullpath")));
    filePath = string(fullfile(testsFolder, "fixtures", varargin{:}));
end
