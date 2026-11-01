classdef DefinitionTest < matlab.unittest.TestCase
% DefinitionTest - Tests for reading definition files and their defaults.
%
%   The fixtures in tests/fixtures/definitions are modelled on the default
%   options of NANSEN session methods. Each test of defaults compares the
%   values read from a fixture with the struct that the NANSEN code builds.

    properties
        TemporaryFolder (1,1) string
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
        end
    end

    methods (Test)
        function testHeader(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "normcorre.json"));
            testCase.verifyEqual(definition.Id, "fixtures.normcorre")
            testCase.verifyEqual(definition.Version, "3.0.0")
            testCase.verifyEqual(definition.Title, "NoRMCorre motion correction")
            testCase.verifyTrue(isfile(definition.FilePath))
        end

        function testNormcorreDefaults(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "normcorre.json"));

            P = struct();
            P.Configuration.numRows = 4;
            P.Configuration.numCols = 4;
            P.Configuration.patchOverlap = [32, 32, 16];
            P.Configuration.gridUpsampling = [4, 4, 1];
            P.Template.initialBatchSize = 100;
            P.Template.updateTemplate = true;
            P.Template.binWidth = 50;
            P.Correction.maximumShift = [40, 40, 5];
            P.Correction.maximumDeviation = [15, 15, 1];
            P.Correction.subpixelUpsampling = 50;
            P.Correction.numIterations = 1;
            P.Correction.shiftsMethod = 'FFT';
            P.Correction.boundary = 'copy';
            P.Correction.phaseFlag = false;
            P.Misc.Verbose = false;
            P.Misc.UseParallel = true;

            testCase.verifyEqual(definition.defaults(), P)
        end

        function testSuite2pDefaultsHoldInf(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "suite2p.json"));
            values = definition.defaults();
            testCase.verifyEqual(values.Neuropil.radius, Inf)
            testCase.verifyEqual(values.CellDetection.smoothingSigma, 0.5)
            testCase.verifyEqual(values.CellDetection.signalExtractionType, 'surround')
            testCase.verifyEqual(values.Deconvolution.imagingRate, 30)
        end

        function testExtractDefaults(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "extract.json"));
            values = definition.defaults();
            testCase.verifyEqual(values.Main.verbose, 2)
            testCase.verifyEqual(values.Computation.num_parallel_cpu_workers, Inf)
            testCase.verifyEqual(values.Fov.movie_mask, [])
            testCase.verifyEqual(values.CellFind.S_init, [])
            testCase.verifyEqual(values.Optimization.TOL_sub, 1e-6)
            testCase.verifyEqual(definition.getOptionSchema("Main.verbose").Enum, {0, 1, 2})
        end

        function testUngroupedDefaults(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "backup.json"));
            expected = struct("BackupMode", 'merge (no replace)', "BackupLocation", '');
            testCase.verifyEqual(definition.defaults(), expected)
        end

        function testNestedGroupDefaults(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "fov-manager.json"));
            expected = struct("hemisphereToLabel", 'left', "fovOrientation", ...
                struct("flipVertical", false, "flipHorizontal", false, "rotationAngle", -90));
            testCase.verifyEqual(definition.defaults(), expected)
        end

        function testValueTypeDefaults(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "value-types.json"));
            values = definition.defaults();

            testCase.verifyEqual(values.flag, true)
            testCase.verifyEqual(values.count, 3)
            testCase.verifyEqual(values.ratio, 0.25)
            testCase.verifyEqual(values.label, 'soma')
            testCase.verifyEqual(values.emptyLabel, '')
            testCase.verifyEqual(values.choice, 'batch')
            testCase.verifyEqual(values.level, 1)
            testCase.verifyEqual(values.optionalCount, [])
            testCase.verifyEqual(values.optionalLabel, [])
            testCase.verifyEqual(values.optionalVector, [])
            testCase.verifyEqual(values.optionalRange, [1, 2])
            testCase.verifyEqual(values.upperBound, Inf)
            testCase.verifyEqual(values.lowerBound, -Inf)
            testCase.verifyEqual(values.chunkLength, NaN)
            testCase.verifyEqual(values.interval, [1, Inf])
            testCase.verifyEqual(values.weights, [0.5, 0.5])
            testCase.verifyEqual(values.indices, zeros(1, 0))
            testCase.verifyEqual(values.flags, [true, false])
            testCase.verifyEqual(values.names, ["a", "b"])
            testCase.verifyEqual(values.singleName, "only")
            testCase.verifyEqual(values.noNames, strings(1, 0))
            testCase.verifyEqual(values.kernel, [1, 0; 0, 1])
            testCase.verifyEqual(values.mask, [true, false, true])
            testCase.verifyEqual(values.emptyMatrix, zeros(0, 0))
            testCase.verifyEqual(values.Outer.Inner.depth, 3)
        end

        function testOptionSchemaKeepsUserInterfaceHints(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "normcorre.json"));
            optionSchema = definition.getOptionSchema("Configuration.numRows");
            testCase.verifyEqual(optionSchema.UI.widget, 'slider')
            testCase.verifyEqual([optionSchema.Minimum, optionSchema.Maximum], [1, 16])
            testCase.verifyEqual(definition.getOptionSchema("Correction").Type, "object")
        end

        function testUnknownOptionSchema(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "normcorre.json"));
            testCase.verifyError(@() definition.getOptionSchema("Correction.missing"), ...
                "OPTIONSPEC:UnknownOption")
            testCase.verifyError(@() definition.getOptionSchema("Misc.Verbose.deeper"), ...
                "OPTIONSPEC:UnknownOption")
        end

        function testInvalidDefinitions(testCase)
            % Each case is the "properties" object of a definition and text
            % that the error message must contain
            cases = {
                '{"a": {"type": "number"}}', """default"" is missing"
                '{"a": {"default": 1}}', """type"" is missing"
                '{"a": {"type": "float", "default": 1}}', """type"" must name one of"
                '{"a": {"type": ["number", "string"], "default": 1}}', """type"" must name one of"
                '{"a": {"type": "number", "default": "one"}}', "expected a number"
                '{"a": {"type": "number", "default": 1, "pattern": "x"}}', "keyword ""pattern"""
                '{"a": {"type": "number", "default": 1, "$ref": "x.json"}}', "keyword ""$ref"""
                '{"a": {"type": "boolean", "enum": [true], "default": true}}', """enum"" applies only"
                '{"a": {"type": "string", "enum": [], "default": "x"}}', """enum"" must be a non-empty array"
                '{"a": {"type": "string", "enum": ["x", "y"], "default": "z"}}', "is not one of"
                '{"a": {"type": "integer", "enum": [1, 2.5], "default": 1}}', "expected an integer"
                '{"a": {"type": "string", "minimum": 0, "default": "x"}}', """minimum"" and ""maximum"" apply only"
                '{"a": {"type": "number", "minimum": 2, "maximum": 1, "default": 1}}', """minimum"" is greater"
                '{"a": {"type": "number", "minimum": 0, "default": -1}}', "less than the minimum"
                '{"a": {"type": "number", "default": "Inf"}}', "List it in ""x-nonfinite"""
                '{"a": {"type": "number", "x-nonfinite": ["Infinity"], "default": 1}}', """x-nonfinite"" must be"
                '{"a": {"type": "string", "x-nonfinite": ["Inf"], "default": "x"}}', """x-nonfinite"" applies only"
                '{"a": {"type": "array", "default": []}}', "needs ""items"""
                '{"a": {"type": "number", "items": {"type": "number"}, "default": 1}}', """items"", ""minItems"""
                '{"a": {"type": "array", "items": {"type": "number"}, "minItems": 2, "default": [1]}}', "at least 2 elements"
                '{"a": {"type": "array", "items": {"type": "number"}, "minItems": -1, "default": []}}', "non-negative integer"
                '{"a": {"type": "array", "items": {"type": ["number", "null"]}, "default": []}}', "items cannot be null"
                '{"a": {"type": "array", "items": {"type": "number", "default": 1}, "default": []}}', "items cannot have"
                '{"a": {"type": "array", "items": {"type": "object", "properties": {}}, "default": []}}', "items cannot be groups"
                '{"a": {"type": "array", "items": {"type": "array", "items": {"type": "string"}}, "default": []}}', "rows of a matrix"
                '{"a": {"type": "array", "items": {"type": "array", "items": {"type": "number"}}, "default": [[1, 2], [3]]}}', "different numbers of elements"
                '{"a": {"type": "object", "properties": {"b": {"type": "number", "default": 1}}, "default": {}}}', "takes its default from its options"
                '{"a": {"type": ["object", "null"], "properties": {"b": {"type": "number", "default": 1}}}}', "group cannot be null"
                '{"a": {"type": "object"}}', "needs ""properties"""
                '{"a": {"type": "object", "properties": {"b": {"type": "number"}}}}', "a.b: ""default"" is missing"
                '{"a": {"type": "object", "properties": {}, "additionalProperties": true}}', """additionalProperties"" can only be false"
                '{"a": {"type": "number", "format": "folder-path", "default": 1}}', """format"" applies only"
                '{"a": {"type": "string", "format": "uri", "default": ""}}', """format"" must be one of"
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "spinner"}}}', "needs a ""widget"""
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "edit", "color": "red"}}}', "unknown key ""color"""
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "slider"}}}', "widget ""slider"" needs"
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "dropdown"}}}', "widget ""dropdown"" needs"
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "checkbox"}}}', "widget ""checkbox"" needs"
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "folder"}}}', "widget ""folder"" needs"
                '{"a": {"type": "number", "default": 1, "x-ui": {"widget": "edit", "step": 0}}}', """step"" must be a positive number"
                };
            for i = 1:height(cases)
                filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, ...
                    sprintf("case%d.json", i), cases{i, 1});
                testCase.verifyError(@() optionspec.Definition(filePath), ...
                    "OPTIONSPEC:InvalidDefinition", sprintf("Case %d: %s", i, cases{i, 1}))
                testCase.verifyErrorMessageContains(filePath, cases{i, 2}, i)
            end
        end

        function testInvalidTopLevel(testCase)
            cases = {
                '{"x-version": "1.0.0", "type": "object", "properties": {}}', """$id"" is missing"
                '{"$id": "test.a", "type": "object", "properties": {}}', """x-version"" is missing"
                '{"$id": "test.a", "x-version": "1.0", "type": "object", "properties": {}}', """x-version"" is missing or not"
                '{"$id": "test a", "x-version": "1.0.0", "type": "object", "properties": {}}', "without spaces"
                '{"$id": "test.a", "x-version": "1.0.0", "properties": {}}', """type"" must be ""object"""
                '{"$id": "test.a", "x-version": "1.0.0", "type": "object"}', """properties"" is missing"
                '{"$schema": "http://json-schema.org/draft-07/schema#", "$id": "test.a", "x-version": "1.0.0", "type": "object", "properties": {}}', """$schema"" must be"
                '{"$id": "test.a", "x-version": "1.0.0", "type": "object", "properties": {}, "definitions": {}}', "Top-level keyword"
                '{"$id": "test.a", "x-version": "1.0.0", "type": "object", "properties": {}, "unevaluatedProperties": true}', """unevaluatedProperties"" can only be false"
                '[1, 2]', "must be a JSON object"
                };
            for i = 1:height(cases)
                filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, ...
                    sprintf("top%d.json", i), "", cases{i, 1});
                testCase.verifyError(@() optionspec.Definition(filePath), ...
                    "OPTIONSPEC:InvalidDefinition", sprintf("Case %d", i))
                testCase.verifyErrorMessageContains(filePath, cases{i, 2}, i)
            end
        end

        function testAllProblemsAreListed(testCase)
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "many.json", ...
                '{"a": {"type": "number"}, "b": {"type": "string", "default": 1}, "c": {"default": true}}');
            try
                optionspec.Definition(filePath);
                testCase.verifyFail("Expected an error.")
            catch exception
                testCase.verifyEqual(count(string(exception.message), newline + "  - "), 3)
            end
        end

        function testInvalidOptionNameIsAnError(testCase)
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "name.json", ...
                '{"frame-rate": {"type": "number", "default": 1}}');
            testCase.verifyError(@() optionspec.Definition(filePath), "OPTIONSPEC:InvalidKey")
        end

        function testValidMinimalDefinition(testCase)
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "minimal.json", '{}', ...
                '"$schema": "https://json-schema.org/draft/2020-12/schema", "unevaluatedProperties": false');
            definition = optionspec.Definition(filePath);
            testCase.verifyEqual(definition.defaults(), struct())
        end
    end

    methods
        function verifyErrorMessageContains(testCase, filePath, expectedText, caseNumber)
            try
                optionspec.Definition(filePath);
            catch exception
                testCase.verifySubstring(exception.message, char(expectedText), ...
                    sprintf("Case %d", caseNumber))
            end
        end
    end
end
