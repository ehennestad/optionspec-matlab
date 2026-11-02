classdef InferDefinitionTest < matlab.unittest.TestCase
% InferDefinitionTest - Tests for definitions inferred from option structs.
%
%   The structs in optionspectest.nansenOptionStructs follow the option
%   structs of NANSEN session methods, with <name>_ hint fields.

    properties
        TemporaryFolder (1,1) string
        Structs struct
    end

    properties (TestParameter)
        StructName = {"Normcorre", "Suite2p", "Extract", "Backup", "FovManager", "MotionCorrection"}
    end

    methods (TestClassSetup)
        function readStructs(testCase)
            testCase.Structs = optionspectest.nansenOptionStructs();
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
        end
    end

    methods (Test)
        function testDefaultsAreTheStructValues(testCase, StructName)
            options = testCase.Structs.(StructName);
            definition = testCase.inferAndRead(options, StructName);
            testCase.verifyEqual(definition.defaults(), expectedDefaults(options))
        end

        function testInferredDefinitionMatchesItsStruct(testCase, StructName)
            % Reading back what was written gives no differences
            options = testCase.Structs.(StructName);
            definition = testCase.inferAndRead(options, StructName);
            [changes, level] = optionspec.checkDefinition(options, definition);
            testCase.verifyEqual(level, "none")
            testCase.verifyEmpty(changes)
        end

        function testStructMatchesHandWrittenDefinition(testCase)
            % The NoRMCorre struct with declarations and the hand-written
            % normcorre.json fixture differ only in descriptions and hints
            [changes, level] = optionspec.checkDefinition(testCase.Structs.Normcorre, ...
                optionspectest.fixtureFile("definitions", "normcorre.json"));
            testCase.verifyEqual(level, "patch")
            testCase.verifyEqual(unique(string({changes.Kind})), "annotation")
        end

        function testInferenceFromValues(testCase)
            options = struct("flag", true, "count", int16(3), "ratio", 0.5, "upper", Inf, ...
                "label", 'soma', "name", "dendrite", "weights", [0.2; 0.8], "flags", [true, false], ...
                "kernel", [1, 2; 3, 4], "names", {{'a', 'b'}}, "tags", ["x", "y"], ...
                "notSet", [], "noWeights", zeros(1, 0), "group", struct("depth", 1));
            definition = testCase.inferAndRead(options, "values");

            expectedTypes = struct("flag", "boolean", "count", "integer", "ratio", "number", ...
                "upper", "number", "label", "string", "name", "string", "weights", "array", ...
                "flags", "array", "kernel", "array", "names", "array", "tags", "array", ...
                "notSet", "array", "noWeights", "array", "group", "object");
            for name = string(fieldnames(expectedTypes))'
                testCase.verifyEqual(definition.getOptionSchema(name).Type, expectedTypes.(name), name)
            end
            testCase.verifyEqual(definition.getOptionSchema("ratio").NonFinite, ["Inf", "-Inf", "NaN"])
            testCase.verifyEmpty(definition.getOptionSchema("count").NonFinite)
            testCase.verifyEqual(definition.getOptionSchema("weights").Items.Type, "number")
            testCase.verifyEmpty(definition.getOptionSchema("weights").MinItems, ...
                "A vector without a declaration has any length.")
            testCase.verifyEqual(definition.getOptionSchema("kernel").Items.Type, "array")
            testCase.verifyEqual(definition.getOptionSchema("names").Items.Type, "string")
            testCase.verifyTrue(definition.getOptionSchema("notSet").Nullable)

            values = definition.defaults();
            testCase.verifyEqual(values.name, 'dendrite')
            testCase.verifyEqual(values.weights, [0.2, 0.8])
            testCase.verifyEqual(values.names, ["a", "b"])
            testCase.verifyEqual(values.notSet, [])
            testCase.verifyEqual(values.count, 3)
        end

        function testHints(testCase)
            definition = testCase.inferAndRead(testCase.Structs.MotionCorrection, "hints");
            testCase.verifyEqual(definition.getOptionSchema("Preview.run").UI.widget, 'button')
            saveDirectory = definition.getOptionSchema("Export.SaveDirectory");
            testCase.verifyEqual(saveDirectory.Format, "folder-path")
            testCase.verifyEqual(saveDirectory.UI.widget, 'folder')
            testCase.verifyEqual(definition.getOptionSchema("Export.IntensityAdjustmentPercentile").Enum, ...
                {0.05, 0.005, 0})
            testCase.verifyEmpty(definition.getOptionSchema("Export.FileName").UI, ...
                "The transient hint does not change the schema.")
            testCase.verifyFalse(isfield(definition.defaults().Export, "FileName_"), ...
                "Hint fields are not options.")

            extract = testCase.inferAndRead(testCase.Structs.Extract, "extract");
            testCase.verifyEqual(extract.getOptionSchema("Fov.movie_mask").UI.widget, 'hidden')
            testCase.verifyEqual(extract.getOptionSchema("Main.verbose").Enum, {0, 1, 2})

            slider = testCase.inferAndRead(struct("size", 4, "size_", ...
                struct('type', 'slider', 'args', {{'Min', 1, 'Max', 20, 'TooltipUnits', 'pixels'}})), "slider");
            sizeSchema = slider.getOptionSchema("size");
            testCase.verifyEqual([sizeSchema.Minimum, sizeSchema.Maximum], [1, 20])
            testCase.verifyEqual(sizeSchema.UI, struct("widget", 'slider', "units", 'pixels'))
        end

        function testFieldEndingInUnderscoreWithoutBaseIsAnOption(testCase)
            definition = testCase.inferAndRead(struct("value_", 1), "underscore");
            testCase.verifyEqual(definition.defaults(), struct("value_", 1))
        end

        function testDeclarations(testCase)
            % Each row: value, declaration, expected type, nullable, items
            % type ("" for none), minItems, maxItems, minimum, exclusive
            % minimum, maximum, non-finite values
            cases = {
                4, '(1,1) double {mustBeInteger}', "integer", false, "", [], [], [], [], [], strings(1, 0)
                4, '(1,1) double', "number", false, "", [], [], [], [], [], ["Inf", "-Inf", "NaN"]
                4, '(1,1) double {mustBeFinite, mustBePositive}', "number", false, "", [], [], [], 0, [], strings(1, 0)
                4, '(1,1) double {mustBeInRange(x, 1, 10)}', "number", false, "", [], [], 1, [], 10, ["Inf", "-Inf", "NaN"]
                4, '(1,1) double {mustBeNonnegative, mustBeLessThanOrEqual(x, 8), mustBeFinite}', "number", false, "", [], [], 0, [], 8, strings(1, 0)
                [], '(1,1) double {mustBeInteger}', "integer", true, "", [], [], [], [], [], strings(1, 0)
                [1, 2], '(1,2) double {mustBeInteger, mustBePositive}', "array", false, "integer", 2, 2, [], 0, [], strings(1, 0)
                [], '(1,2) double {mustBeInteger}', "array", true, "integer", 2, 2, [], [], [], strings(1, 0)
                [], '(1,:) double {mustBeFinite}', "array", false, "number", [], [], [], [], [], strings(1, 0)
                [1; 2; 3], '(3,1) double {mustBeFinite}', "array", false, "number", 3, 3, [], [], [], strings(1, 0)
                [1, 0; 0, 1], '(2,2) double {mustBeFinite}', "array", false, "array", 2, 2, [], [], [], strings(1, 0)
                'soma', '(1,:) char', "string", false, "", [], [], [], [], [], strings(1, 0)
                "a", '(1,:) string', "array", false, "string", [], [], [], [], [], strings(1, 0)
                true, '(1,1) logical', "boolean", false, "", [], [], [], [], [], strings(1, 0)
                int8(2), '(1,1) int8', "integer", false, "", [], [], [], [], [], strings(1, 0)
                };
            for i = 1:height(cases)
                diagnostic = sprintf("Case %d: %s", i, cases{i, 2});
                options = struct("x", cases{i, 1}, "x_", cases{i, 2});
                definition = testCase.inferAndRead(options, sprintf("declaration%d", i));
                node = definition.getOptionSchema("x");
                testCase.verifyEqual(node.Type, cases{i, 3}, diagnostic)
                testCase.verifyEqual(node.Nullable, cases{i, 4}, diagnostic)
                elementNode = node;
                if cases{i, 5} ~= ""
                    testCase.verifyEqual(node.Items.Type, cases{i, 5}, diagnostic)
                    elementNode = node.Items;
                    if elementNode.Type == "array"
                        elementNode = elementNode.Items;
                    end
                end
                testCase.verifyEqual(node.MinItems, cases{i, 6}, diagnostic)
                testCase.verifyEqual(node.MaxItems, cases{i, 7}, diagnostic)
                testCase.verifyEqual(elementNode.Minimum, cases{i, 8}, diagnostic)
                testCase.verifyEqual(elementNode.ExclusiveMinimum, cases{i, 9}, diagnostic)
                testCase.verifyEqual(elementNode.Maximum, cases{i, 10}, diagnostic)
                testCase.verifyEqual(elementNode.NonFinite, cases{i, 11}, diagnostic)
            end
        end

        function testDeclaredMembers(testCase)
            definition = testCase.inferAndRead(struct( ...
                "mode", 'serial', "mode_", '(1,:) char {mustBeMember(x, ["serial", "batch"])}', ...
                "level", 1, "level_", '(1,1) double {mustBeMember(x, [0 1 2])}', ...
                "kind", 'a', "kind_", "(1,:) char {mustBeMember(x, {'a', 'b'})}"), "members");
            testCase.verifyEqual(definition.getOptionSchema("mode").Enum, {'serial', 'batch'})
            testCase.verifyEqual(definition.getOptionSchema("level").Enum, {0, 1, 2})
            testCase.verifyEqual(definition.getOptionSchema("kind").Enum, {'a', 'b'})
        end

        function testDescriptionsAndHeader(testCase)
            jsonText = optionspec.inferDefinition(testCase.Structs.Backup, Id="nansen.backup", ...
                Version="2.1.0", Title="Back up", Description="Copies session data.", ...
                Descriptions=struct("BackupLocation", "Folder to copy the data to"));
            definition = testCase.readText(jsonText, "described");
            testCase.verifyEqual([definition.Id, definition.Version, definition.Title, definition.Description], ...
                ["nansen.backup", "2.1.0", "Back up", "Copies session data."])
            testCase.verifyEqual(definition.getOptionSchema("BackupLocation").Description, ...
                "Folder to copy the data to")
        end

        function testInvalidStructs(testCase)
            % Each row: options struct, text the message must contain
            cases = {
                struct("callback", @disp), "callback: cannot infer an option from"
                struct("mixed", {{1, 'a'}}), "mixed: cannot infer"
                struct("volume", ones(2, 2, 2)), "more than two dimensions"
                struct("choice", 'a', "choice_", {{'a', 1}}), "mixes text and numbers"
                struct("choice", 'c', "choice_", {{'a', 'b'}}), "choice default: ""c"" is not one of"
                struct("count", 1.5, "count_", '(1,1) double {mustBeInteger}'), "expected an integer"
                struct("count", 1, "count_", '(1,1) table'), "class ""table"" is not supported"
                struct("count", 1, "count_", '(1,1) double {mustBeEven}'), "validator ""mustBeEven"" is not supported"
                struct("count", 1, "count_", '(1 double)'), "must have the form"
                struct("count", 1, "count_", '(1,1) double {mustBeGreaterThan(x)}'), "needs one numeric bound"
                struct("name", 'a', "name_", '(1,:) {mustBeInteger}'), "mustBeInteger needs a numeric option"
                struct("zzOptionspecKeyword_x", 1), "cannot start with"
                };
            for i = 1:height(cases)
                diagnostic = sprintf("Case %d", i);
                try
                    optionspec.inferDefinition(cases{i, 1}, Id="test.invalid");
                    testCase.verifyFail(diagnostic + ": expected an error.")
                catch exception
                    testCase.verifySubstring(exception.message, char(cases{i, 2}), diagnostic)
                end
            end
        end

        function testAllProblemsAreListed(testCase)
            options = struct("a", @disp, "b", {{1, 'x'}}, "c", 1);
            testCase.verifyError(@() optionspec.inferDefinition(options, Id="test.many"), ...
                "OPTIONSPEC:CannotInferDefinition")
            try
                optionspec.inferDefinition(options, Id="test.many");
            catch exception
                testCase.verifyEqual(count(string(exception.message), newline + "  - "), 2)
            end
        end

        function testIdIsRequired(testCase)
            testCase.verifyError(@() optionspec.inferDefinition(struct("a", 1)), ?MException)
        end
    end

    methods
        function definition = inferAndRead(testCase, options, name)
            definition = testCase.readText(optionspec.inferDefinition(options, Id="test." + lower(name)), name);
        end

        function definition = readText(testCase, jsonText, name)
            filePath = fullfile(testCase.TemporaryFolder, name + ".json");
            fileId = fopen(filePath, "w", "n", "UTF-8");
            fwrite(fileId, jsonText, "char");
            fclose(fileId);
            definition = optionspec.Definition(filePath);
        end
    end
end

function values = expectedDefaults(options)
% The struct without hint fields, with text arrays as string arrays
    values = struct();
    names = string(fieldnames(options))';
    for name = names
        if endsWith(name, "_") && any(extractBefore(name, strlength(name)) == names)
            continue
        end
        value = options.(name);
        if isstruct(value)
            value = expectedDefaults(value);
        elseif iscellstr(value) %#ok<ISCLSTR> The structs hold cellstr, as NANSEN option structs do
            value = string(value);
        end
        values.(name) = value;
    end
end
