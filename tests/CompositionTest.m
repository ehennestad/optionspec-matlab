classdef CompositionTest < matlab.unittest.TestCase
% CompositionTest - Tests for definitions that include other definitions.
%
%   The fixtures in tests/fixtures/definitions/composition follow the
%   inheritance of NANSEN options: nansen.stack.ImageStackProcessor adds a
%   Run group, nansen.processing.MotionCorrection adds Preprocessing,
%   Preview and Export, and the NoRMCorre processor adds its own options.

    properties
        TemporaryFolder (1,1) string
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
            optionspectest.writeDefinition(testCase.TemporaryFolder, "base.json", ...
                ['{"Run": {"type": "object", "properties": {' ...
                '"mode": {"type": "string", "enum": ["serial", "batch"], "default": "serial"}, ' ...
                '"size": {"type": "integer", "minimum": 1, "maximum": 100, "default": 10}, ' ...
                '"limit": {"type": "number", "x-nonfinite": ["Inf"], "default": "Inf"}, ' ...
                '"shape": {"type": "array", "items": {"type": "integer"}, "minItems": 2, "maxItems": 3, "default": [1, 1]}, ' ...
                '"folder": {"type": "string", "format": "folder-path", "default": ""}}}, ' ...
                '"verbose": {"type": "boolean", "default": false}}']);
        end
    end

    methods (Test)
        function testIncludedOptionsFollowOwnOptions(testCase)
            definition = readFixture("normcorre-processor.json");
            testCase.verifyEqual(string(fieldnames(definition.defaults()))', ...
                ["Configuration", "Run", "Preprocessing", "Preview", "Export"])
        end

        function testGroupsMergeOptionByOption(testCase)
            definition = readFixture("normcorre-processor.json");
            % The redeclared options come first, then the rest of the group
            testCase.verifyEqual(string(fieldnames(definition.defaults().Run))', ...
                ["numFramesPerPart", "ChannelProcessingMode", "frameInterval", ...
                "runOnSeparateWorker", "PrimaryChannel"])
        end

        function testRedeclaredDefaultAndNarrowedEnum(testCase)
            definition = readFixture("normcorre-processor.json");
            values = definition.defaults();
            testCase.verifyEqual(values.Run.numFramesPerPart, 500)
            testCase.verifyEqual(values.Run.ChannelProcessingMode, 'serial')

            optionSchema = definition.getOptionSchema("Run.ChannelProcessingMode");
            testCase.verifyEqual(optionSchema.Enum, {'serial', 'batch'})
            testCase.verifyEqual(optionSchema.UI.widget, 'dropdown', ...
                "Keywords that are not redeclared are inherited.")
            testCase.verifyEqual(optionSchema.Description, ...
                "NoRMCorre corrects channels one at a time or together")

            values.Run.ChannelProcessingMode = 'single';
            testCase.verifyFalse(definition.isValid(values))
        end

        function testIncludedDefaultsAreUnchanged(testCase)
            definition = readFixture("normcorre-processor.json");
            included = readFixture("motion-correction.json");
            values = definition.defaults();
            includedValues = included.defaults();
            testCase.verifyEqual(values.Export, includedValues.Export)
            testCase.verifyEqual(values.Run.frameInterval, [])
            testCase.verifyEqual(includedValues.Run.numFramesPerPart, 1000)
        end

        function testIncludesListsNestedDefinitions(testCase)
            definition = readFixture("normcorre-processor.json");
            testCase.verifyEqual(definition.Includes, ...
                ["fixtures.motion-correction@1.0.0", "fixtures.stack-processor@1.0.0"])
            testCase.verifyEqual(readFixture("stack-processor.json").Includes, strings(1, 0))
        end

        function testOnlyAllOf(testCase)
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "only.json", "", ...
                '{"$id": "test.only", "x-version": "1.0.0", "type": "object", "allOf": [{"$ref": "base.json"}]}');
            definition = optionspec.Definition(filePath);
            testCase.verifyEqual(definition.defaults().Run.size, 10)
        end

        function testTwoIncludes(testCase)
            optionspectest.writeDefinition(testCase.TemporaryFolder, "other.json", ...
                '{"Export": {"type": "object", "properties": {"format": {"type": "string", "default": "tif"}}}}');
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "two.json", '{}', ...
                '"allOf": [{"$ref": "base.json"}, {"$ref": "other.json"}]');
            definition = optionspec.Definition(filePath);
            testCase.verifyEqual(string(fieldnames(definition.defaults()))', ["Run", "verbose", "Export"])
            testCase.verifyEqual(definition.Includes, ["test.base@1.0.0", "test.other@1.0.0"])
        end

        function testReferenceInSubfolder(testCase)
            mkdir(fullfile(testCase.TemporaryFolder, "algorithms"))
            filePath = optionspectest.writeDefinition(fullfile(testCase.TemporaryFolder, "algorithms"), ...
                "step.json", '{}', '"allOf": [{"$ref": "../base.json"}]');
            definition = optionspec.Definition(filePath);
            testCase.verifyEqual(definition.Includes, "test.base@1.0.0")
        end

        function testAllowedNarrowing(testCase)
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "narrow.json", ...
                ['{"Run": {"type": "object", "properties": {' ...
                '"mode": {"enum": ["batch"], "default": "batch"}, ' ...
                '"size": {"minimum": 5, "maximum": 50, "x-ui": {"widget": "slider"}}, ' ...
                '"shape": {"minItems": 3, "default": [1, 1, 1]}}}, ' ...
                '"verbose": {"type": "boolean", "title": "Verbose", "default": true}}'], ...
                '"allOf": [{"$ref": "base.json"}]');
            definition = optionspec.Definition(filePath);
            values = definition.defaults();
            testCase.verifyEqual(values.Run.mode, 'batch')
            testCase.verifyEqual(values.Run.shape, [1, 1, 1])
            testCase.verifyTrue(values.verbose)
            testCase.verifyEqual(definition.getOptionSchema("Run.size").Minimum, 5)
        end

        function testInvalidCompositions(testCase)
            % Each row: properties of a definition that includes base.json,
            % and text the error message must contain
            cases = {
                '{"verbose": {"type": "integer", "default": 1}}', "verbose: an included option cannot change its type"
                '{"Run": {"type": "boolean", "default": true}}', "Run: an included option cannot change its type"
                '{"Run": {"type": "object", "properties": {"size": {"type": ["integer", "null"]}}}}', "cannot change its type"
                '{"Run": {"type": "object", "properties": {"mode": {"enum": ["serial", "parallel"]}}}}', "Run.mode: ""enum"" can only remove values"
                '{"Run": {"type": "object", "properties": {"size": {"minimum": 0}}}}', "Run.size: ""minimum"" cannot widen"
                '{"Run": {"type": "object", "properties": {"size": {"maximum": 1000}}}}', "Run.size: ""maximum"" cannot widen"
                '{"Run": {"type": "object", "properties": {"shape": {"maxItems": 4}}}}', "Run.shape: ""maxItems"" cannot widen"
                '{"Run": {"type": "object", "properties": {"limit": {"x-nonfinite": ["Inf", "NaN"]}}}}', "Run.limit: ""x-nonfinite"" can only remove"
                '{"Run": {"type": "object", "properties": {"folder": {"format": "file-path"}}}}', "Run.folder: ""format"" of an included option cannot change"
                '{"Run": {"type": "object", "properties": {"mode": {"enum": ["batch"]}}}}', "Run.mode default: ""serial"" is not one of ""batch"""
                '{"Run": {"type": "object", "properties": {"limit": {"x-nonfinite": ["NaN"]}}}}', "Run.limit default: Inf is not allowed"
                '{"Run": {"type": "object", "properties": {"extra": {"default": 1}}}}', "Run.extra: ""type"" is missing"
                };
            for i = 1:height(cases)
                filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, ...
                    sprintf("case%d.json", i), cases{i, 1}, '"allOf": [{"$ref": "base.json"}]');
                testCase.verifyDefinitionError(filePath, cases{i, 2}, i)
            end
        end

        function testInvalidReferences(testCase)
            optionspectest.writeDefinition(testCase.TemporaryFolder, "loopA.json", '{}', ...
                '"allOf": [{"$ref": "loopB.json"}]');
            optionspectest.writeDefinition(testCase.TemporaryFolder, "loopB.json", '{}', ...
                '"allOf": [{"$ref": "loopA.json"}]');
            optionspectest.writeDefinition(testCase.TemporaryFolder, "broken.json", ...
                '{"a": {"type": "number"}}');
            optionspectest.writeDefinition(testCase.TemporaryFolder, "closed.json", ...
                '{"verbose": {"type": "boolean", "default": true}}', '"unevaluatedProperties": false');
            optionspectest.writeDefinition(testCase.TemporaryFolder, "duplicate.json", ...
                '{"verbose": {"type": "boolean", "default": true}}');

            % Each row: the "allOf" member of a definition, and text the
            % error message must contain
            cases = {
                '"allOf": [{"$ref": "missing.json"}]', """$ref"" file"
                '"allOf": [{"$ref": "loopA.json"}]', "is circular"
                '"allOf": [{"$ref": "self.json"}]', "is circular"
                '"allOf": [{"$ref": "broken.json"}]', "broken.json"" is not valid"
                '"allOf": [{"$ref": "base.json"}, {"$ref": "duplicate.json"}]', "verbose: declared by more than one"
                '"allOf": [{"$ref": "closed.json"}]', """unevaluatedProperties"" is not allowed in a definition that another definition includes"
                '"allOf": []', """allOf"" must be a non-empty array"
                '"allOf": [{"$ref": "base.json", "title": "x"}]', """allOf"" must be a non-empty array"
                '"allOf": [{"type": "object"}]', """allOf"" must be a non-empty array"
                };
            for i = 1:height(cases)
                fileName = sprintf("reference%d.json", i);
                if contains(cases{i, 1}, "self.json")
                    fileName = "self.json";
                end
                filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, ...
                    fileName, '{}', cases{i, 1});
                testCase.verifyDefinitionError(filePath, cases{i, 2}, i)
            end
        end
    end

    methods
        function verifyDefinitionError(testCase, filePath, expectedText, caseNumber)
            diagnostic = sprintf("Case %d", caseNumber);
            try
                optionspec.Definition(filePath);
                testCase.verifyFail(diagnostic + ": expected an error.")
            catch exception
                testCase.verifyEqual(exception.identifier, 'OPTIONSPEC:InvalidDefinition', diagnostic)
                testCase.verifySubstring(exception.message, char(expectedText), diagnostic)
            end
        end
    end
end

function definition = readFixture(fileName)
    definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "composition", fileName));
end
