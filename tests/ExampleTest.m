classdef ExampleTest < matlab.unittest.TestCase
% ExampleTest - Tests that the example definitions and script work.

    methods (Test)
        function testExampleDefinitions(testCase)
            definitionsFolder = fullfile(optionspec.toolboxdir(), "examples", "definitions");
            definition = optionspec.Definition(fullfile(definitionsFolder, "rigid-registration.json"));
            testCase.verifyEqual(definition.Includes, "example.stack@1.0.0")
            values = definition.defaults();
            testCase.verifyEqual(values.Registration.MaxShift, Inf)
            testCase.verifyEqual(values.Stack.ChunkLength, NaN)
            testCase.verifyEqual(values.Stack.TimepointInterval, [1, Inf])
            testCase.verifyEqual(values.Stack.PartsToProcess, [])
        end

        function testExampleDocumentUpgrade(testCase)
            examplesFolder = fullfile(optionspec.toolboxdir(), "examples");
            definition = optionspec.Definition(fullfile(examplesFolder, "definitions", "rigid-registration.json"));
            values = definition.readDocument(fullfile(examplesFolder, "rigid-registration-1.0.0.json"));
            testCase.verifyEqual(values.Registration, ...
                struct("MaxShift", 20, "UpsampleFactor", 4, "Taper", false))
            testCase.verifyEqual(values.Stack.TimepointInterval, [1, 500])
        end

        function testExampleScriptRuns(testCase)
            scriptPath = fullfile(optionspec.toolboxdir(), "examples", "optionspecExample.m");
            testCase.verifyWarningFree(@() runScript(scriptPath))
        end
    end
end

function runScript(scriptPath)
    [~] = evalc("run(""" + scriptPath + """)");
end
