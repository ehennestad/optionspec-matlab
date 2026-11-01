classdef ToolboxTest <  matlab.unittest.TestCase
% ToolboxTest - Unit test for testing the toolbox functions.


    methods (Test)
        function testToolboxDir(testCase)
            pathStr = optionspec.toolboxdir();
            testCase.verifyClass(pathStr, 'char')
            testCase.verifyTrue(isfolder(pathStr))
            testCase.verifyTrue(isfile(fullfile(pathStr, 'Contents.m')))
        end

        function testToolboxVersion(testCase)
            versionStr = optionspec.toolboxversion();
            testCase.verifyClass(versionStr, 'char')
            testCase.verifyMatches(versionStr, '^\d+\.\d+\.\d+(\.\d+)?$')
        end

        function testGettingStartedFindsExamplesFolder(testCase)
            output = evalc('optionspec.gettingStarted()');
            testCase.verifyFalse(contains(output, 'Examples directory not found'))
        end
    end
end
