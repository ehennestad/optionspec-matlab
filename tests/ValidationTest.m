classdef ValidationTest < matlab.unittest.TestCase
% ValidationTest - Tests for validating values and converting them to canonical form.

    properties
        ValueTypes optionspec.Definition
        Normcorre optionspec.Definition
    end

    properties (TestParameter)
        DefinitionFile = {"normcorre.json", "suite2p.json", "extract.json", ...
            "backup.json", "fov-manager.json", "value-types.json"}
    end

    methods (TestClassSetup)
        function readDefinitions(testCase)
            testCase.ValueTypes = optionspec.Definition( ...
                optionspectest.fixtureFile("definitions", "value-types.json"));
            testCase.Normcorre = optionspec.Definition( ...
                optionspectest.fixtureFile("definitions", "normcorre.json"));
        end
    end

    methods (Test)
        function testDefaultsAreValidAndCanonical(testCase, DefinitionFile)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", DefinitionFile));
            defaults = definition.defaults();
            testCase.verifyTrue(definition.isValid(defaults))
            testCase.verifyEqual(definition.validate(defaults), defaults)
            testCase.verifyEqual(definition.resolve(), defaults)
        end

        function testConversionToCanonicalForm(testCase)
            % Each row: option, value given, canonical value
            cases = {
                "count", int8(5), 5
                "ratio", single(0.5), 0.5
                "label", "text", 'text'
                "emptyLabel", "", ''
                "choice", "serial", 'serial'
                "optionalLabel", "set", 'set'
                "optionalCount", [], []
                "optionalRange", [], []
                "upperBound", "Inf", Inf
                "upperBound", 'Inf', Inf
                "chunkLength", 'NaN', NaN
                "interval", {1; 'Inf'}, [1, Inf]
                "interval", [2; 10], [2, 10]
                "weights", [0.2; 0.8], [0.2, 0.8]
                "weights", {0.2; 0.8}, [0.2, 0.8]
                "indices", [], zeros(1, 0)
                "indices", {}, zeros(1, 0)
                "flags", [true; true], [true, true]
                "names", {'x'; 'y'}, ["x", "y"]
                "names", ["x"; "y"], ["x", "y"]
                "names", "x", "x"
                "noNames", {}, strings(1, 0)
                "kernel", {[1; 2]; [3; 4]}, [1, 2; 3, 4]
                "mask", [true, false; false, true], [true, false; false, true]
                "emptyMatrix", [], zeros(0, 0)
                };
            for i = 1:height(cases)
                values = testCase.ValueTypes.defaults();
                values.(cases{i, 1}) = cases{i, 2};
                normalized = testCase.ValueTypes.validate(values);
                testCase.verifyEqual(normalized.(cases{i, 1}), cases{i, 3}, sprintf("Case %d", i))
            end
        end

        function testInvalidValues(testCase)
            % Each row: option, invalid value, text the message must contain
            cases = {
                "flag", 1, "flag: expected true or false, found 1"
                "flag", [true, false], "flag: expected true or false"
                "count", 2.5, "count: expected an integer, found 2.5"
                "count", true, "count: expected a number"
                "count", "3", "count: expected a number, found ""3"""
                "count", [1, 2], "count: expected a number"
                "count", 1 + 2i, "count: expected a number"
                "count", [], "count: expected a number"
                "count", Inf, "count: Inf is not allowed"
                "ratio", NaN, "ratio: NaN is not allowed"
                "label", 3, "label: expected text, found 3"
                "label", ['ab'; 'cd'], "label: expected text"
                "label", string(missing), "label: expected text"
                "label", [], "label: expected text"
                "choice", 'parallel', "choice: ""parallel"" is not one of ""serial"", ""batch"", ""single"""
                "choice", 'Batch', "is not one of"
                "level", 3, "level: 3 is not one of 0, 1, 2"
                "lowerBound", NaN, "lowerBound: NaN is not allowed"
                "chunkLength", 0, "chunkLength: 0 is less than the minimum 1"
                "chunkLength", Inf, "chunkLength: Inf is not allowed"
                "interval", [1, 2, 3], "interval: expected at most 2 elements, found 3"
                "interval", 5, "interval: expected at least 2 elements, found 1"
                "interval", [0, Inf], "interval(1): 0 is less than the minimum 1"
                "interval", [1, -Inf], "interval(2): -Inf is not allowed"
                "weights", [1, 2; 3, 4], "weights: expected a vector, found a 2x2 double array"
                "weights", {1, 'a'}, "weights(2): expected a number"
                "names", 'xy', "names: expected a vector, found ""xy"""
                "names", {1}, "names(1): expected text"
                "flags", [1, 0], "flags(1): expected true or false"
                "kernel", [1, 2, 3], ""
                "kernel", {[1, 2], 3}, "kernel: rows have different numbers of elements"
                "kernel", {{1; 'x'}}, "kernel(1,:)(2): expected a number"
                "kernel", ones(2, 2, 2), "kernel: expected a matrix"
                "mask", [1, 0], "mask(1,:)(1): expected true or false"
                "Outer", 1, "Outer: expected a group of options (a scalar struct), found 1"
                "Outer", struct("Inner", {1, 2}), "Outer: expected a group of options"
                };
            for i = 1:height(cases)
                values = testCase.ValueTypes.defaults();
                values.(cases{i, 1}) = cases{i, 2};
                if cases{i, 3} == ""
                    % A single row is a valid matrix
                    testCase.verifyTrue(testCase.ValueTypes.isValid(values), sprintf("Case %d", i))
                    continue
                end
                [tf, issues] = testCase.ValueTypes.isValid(values);
                testCase.verifyFalse(tf, sprintf("Case %d", i))
                testCase.verifySubstring(char(strjoin(issues, newline)), char(cases{i, 3}), ...
                    sprintf("Case %d", i))
                testCase.verifyError(@() testCase.ValueTypes.validate(values), ...
                    "OPTIONSPEC:InvalidValues", sprintf("Case %d", i))
            end
        end

        function testUnknownAndMissingOptions(testCase)
            values = testCase.Normcorre.defaults();
            values.Correction.maxShift = [1, 1, 1];
            values.Misc = rmfield(values.Misc, "UseParallel");
            values.Extra = 1;
            [tf, issues] = testCase.Normcorre.isValid(values);
            testCase.verifyFalse(tf)
            testCase.verifyEqual(sort(issues), sort([ ...
                "Correction.maxShift: unknown option.", ...
                "Misc.UseParallel: missing option.", ...
                "Extra: unknown option."]))
        end

        function testValuesMustBeAStruct(testCase)
            [tf, issues] = testCase.Normcorre.isValid(1);
            testCase.verifyFalse(tf)
            testCase.verifySubstring(char(issues), "(values): expected a group of options")
        end

        function testCanonicalFieldOrder(testCase)
            values = testCase.Normcorre.defaults();
            values.Misc = struct("UseParallel", false, "Verbose", true);
            normalized = testCase.Normcorre.validate(values);
            testCase.verifyEqual(string(fieldnames(normalized.Misc))', ["Verbose", "UseParallel"])
        end

        function testResolvePreset(testCase)
            % The NoRMCorre "Rigid" preset in NANSEN sets one patch row and column
            preset = struct("Configuration", struct("numRows", 1, "numCols", 1));
            values = testCase.Normcorre.resolve(preset);

            expected = testCase.Normcorre.defaults();
            expected.Configuration.numRows = 1;
            expected.Configuration.numCols = 1;
            testCase.verifyEqual(values, expected)
        end

        function testResolveReportsUnknownOptions(testCase)
            preset = struct("Configuration", struct("numRow", 1));
            testCase.verifyError(@() testCase.Normcorre.resolve(preset), "OPTIONSPEC:InvalidValues")
        end

        function testErrorListsEveryProblem(testCase)
            values = testCase.Normcorre.defaults();
            values.Configuration.numRows = 0;
            values.Correction.shiftsMethod = 'spline';
            values.Misc.Verbose = 'yes';
            try
                testCase.Normcorre.validate(values);
                testCase.verifyFail("Expected an error.")
            catch exception
                testCase.verifyEqual(exception.identifier, 'OPTIONSPEC:InvalidValues')
                testCase.verifySubstring(exception.message, 'fixtures.normcorre')
                testCase.verifyEqual(count(string(exception.message), newline + "  - "), 3)
            end
        end
    end
end
