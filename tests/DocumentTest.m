classdef DocumentTest < matlab.unittest.TestCase
% DocumentTest - Tests for writing and reading value documents.

    properties
        TemporaryFolder (1,1) string
        ValueTypes optionspec.Definition
    end

    properties (TestParameter)
        DefinitionFile = {"normcorre.json", "suite2p.json", "extract.json", "backup.json", ...
            "fov-manager.json", "value-types.json", fullfile("composition", "normcorre-processor.json")}
    end

    methods (TestClassSetup)
        function readDefinition(testCase)
            testCase.ValueTypes = optionspec.Definition( ...
                optionspectest.fixtureFile("definitions", "value-types.json"));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
        end
    end

    methods (Test)
        function testDefaultsRoundTrip(testCase, DefinitionFile)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", DefinitionFile));
            [values, header] = definition.decode(definition.encode(definition.defaults()));
            testCase.verifyEqual(values, definition.defaults())
            testCase.verifyEqual(header, struct("Definition", definition.Id, "Version", definition.Version))
        end

        function testChangedValuesRoundTrip(testCase)
            values = testCase.ValueTypes.defaults();
            values.flag = false;
            values.emptyLabel = 'now set';
            values.optionalCount = 7;
            values.optionalLabel = 'µm';
            values.optionalVector = 2.5;
            values.optionalRange = [];
            values.upperBound = 12.5;
            values.lowerBound = Inf;
            values.chunkLength = 64;
            values.interval = [Inf, Inf];
            values.indices = 4;
            values.flags = false;
            values.names = strings(1, 0);
            values.noNames = "z";
            values.kernel = [0.1, 0.2, 0.3];
            values.mask = false(2, 2);
            values.emptyMatrix = [1; 2];
            values.Outer.Inner.depth = -1;

            decoded = testCase.ValueTypes.decode(testCase.ValueTypes.encode(values));
            testCase.verifyEqual(decoded, testCase.ValueTypes.validate(values))
        end

        function testJsonOfEachValueType(testCase)
            jsonText = testCase.ValueTypes.encode(testCase.ValueTypes.defaults());
            % Each row: the JSON an option is written as, with the
            % whitespace jsonencode writes removed
            expectedMembers = [
                """flag"":true"
                """emptyLabel"":"""""
                """optionalCount"":null"
                """optionalLabel"":null"
                """optionalVector"":null"
                """optionalRange"":[1,2]"
                """upperBound"":""Inf"""
                """lowerBound"":""-Inf"""
                """chunkLength"":""NaN"""
                """interval"":[1,""Inf""]"
                """indices"":[]"
                """flags"":[true,false]"
                """singleName"":[""only""]"
                """noNames"":[]"
                """kernel"":[[1,0],[0,1]]"
                """mask"":[[true,false,true]]"
                """emptyMatrix"":[]"
                """Outer"":{""Inner"":{""depth"":3}}"
                ];
            compactText = regexprep(jsonText, '\s', '');
            for member = expectedMembers'
                testCase.verifySubstring(char(compactText), char(member))
            end
        end

        function testDocumentHeader(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "backup.json"));
            document = jsondecode(definition.encode(definition.defaults()));
            testCase.verifyEqual(string(fieldnames(document))', ...
                ["optionspec", "definition", "version", "values"])
            testCase.verifyEqual(document.optionspec, '1')
            testCase.verifyEqual(document.definition, 'fixtures.backup')
            testCase.verifyEqual(document.version, '1.0.0')
        end

        function testEncodingIsStable(testCase)
            % The same values give the same text, whatever their field order,
            % so documents only differ in git where values differ
            values = testCase.ValueTypes.defaults();
            reordered = orderfields(values);
            testCase.verifyEqual(testCase.ValueTypes.encode(reordered), ...
                testCase.ValueTypes.encode(values))
            testCase.verifyTrue(endsWith(testCase.ValueTypes.encode(values), newline))
        end

        function testEncodeValidates(testCase)
            values = testCase.ValueTypes.defaults();
            values.count = 'three';
            testCase.verifyError(@() testCase.ValueTypes.encode(values), "OPTIONSPEC:InvalidValues")
            testCase.verifyError(@() testCase.ValueTypes.encode(struct("flag", true)), ...
                "OPTIONSPEC:InvalidValues")
        end

        function testWriteAndReadFile(testCase)
            filePath = fullfile(testCase.TemporaryFolder, "options.json");
            values = testCase.ValueTypes.defaults();
            values.label = 'dendrite';
            testCase.ValueTypes.writeDocument(filePath, values);
            testCase.verifyEqual(testCase.ValueTypes.readDocument(filePath), values)
        end

        function testWriteDoesNotOverwrite(testCase)
            filePath = fullfile(testCase.TemporaryFolder, "options.json");
            values = testCase.ValueTypes.defaults();
            testCase.ValueTypes.writeDocument(filePath, values);
            values.count = 9;
            testCase.verifyError(@() testCase.ValueTypes.writeDocument(filePath, values), ...
                "OPTIONSPEC:FileExists")
            testCase.ValueTypes.writeDocument(filePath, values, Overwrite=true);
            testCase.verifyEqual(testCase.ValueTypes.readDocument(filePath).count, 9)
        end

        function testFileErrors(testCase)
            missingFolderFile = fullfile(testCase.TemporaryFolder, "missing", "options.json");
            testCase.verifyError(@() testCase.ValueTypes.writeDocument(missingFolderFile, ...
                testCase.ValueTypes.defaults()), "OPTIONSPEC:CannotWriteFile")
            testCase.verifyError(@() testCase.ValueTypes.readDocument(missingFolderFile), ...
                "OPTIONSPEC:FileNotFound")
        end

        function testPartialDocumentIsFilledWithDefaults(testCase)
            % A hand-written document, such as a preset, may set only some options
            jsonText = '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {"count": 8, "interval": [5, "Inf"]}}';
            values = testCase.ValueTypes.decode(jsonText);
            expected = testCase.ValueTypes.defaults();
            expected.count = 8;
            expected.interval = [5, Inf];
            testCase.verifyEqual(values, expected)
        end

        function testInvalidDocuments(testCase)
            % Each row: document text, error identifier, text the message must contain
            cases = {
                '[1]', "OPTIONSPEC:InvalidDocument", "must be a JSON object"
                '{"optionspec": "1", "definition": "fixtures.value-types", "values": {}}', "OPTIONSPEC:InvalidDocument", "Key ""version"" is missing"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {}, "date": "today"}', "OPTIONSPEC:InvalidDocument", "Key ""date"" is not part"
                '{"optionspec": "2", "definition": "fixtures.value-types", "version": "1.0.0", "values": {}}', "OPTIONSPEC:InvalidDocument", """optionspec"" must be ""1"""
                '{"optionspec": 1, "definition": "fixtures.value-types", "version": "1.0.0", "values": {}}', "OPTIONSPEC:InvalidDocument", """optionspec"" must be ""1"""
                '{"optionspec": "1", "definition": 3, "version": "1.0.0", "values": {}}', "OPTIONSPEC:InvalidDocument", """definition"" must be a string"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1", "values": {}}', "OPTIONSPEC:InvalidDocument", """version"" must be"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": [1]}', "OPTIONSPEC:InvalidDocument", """values"" must be a JSON object"
                '{"optionspec": "1", "definition": "fixtures.normcorre", "version": "1.0.0", "values": {}}', "OPTIONSPEC:DefinitionMismatch", "written for definition ""fixtures.normcorre"""
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "2.0.0", "values": {}}', "OPTIONSPEC:NewerVersion", "version 2.0.0"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.1.0", "values": {}}', "OPTIONSPEC:NewerVersion", "newer than version 1.0.0"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "0.9.0", "values": {}}', "OPTIONSPEC:MissingMigration", "no migration from major version 0 to 1"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {"count": "Inf"}}', "OPTIONSPEC:InvalidValues", "count: Inf is not allowed"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {"cuont": 1}}', "OPTIONSPEC:InvalidValues", "cuont: unknown option"
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {"Outer": {"Inner": {"dep-th": 1}}}}', "OPTIONSPEC:InvalidKey", """dep-th"""
                '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.0", "values": {"upperBound": Infinity}}', "OPTIONSPEC:InvalidJson", "not valid JSON"
                };
            for i = 1:height(cases)
                diagnostic = sprintf("Case %d", i);
                try
                    testCase.ValueTypes.decode(cases{i, 1});
                    testCase.verifyFail(diagnostic + ": expected an error.")
                catch exception
                    testCase.verifyEqual(string(exception.identifier), cases{i, 2}, diagnostic)
                    testCase.verifySubstring(exception.message, char(cases{i, 3}), diagnostic)
                end
            end
        end

        function testNewerPatchVersionIsRead(testCase)
            jsonText = '{"optionspec": "1", "definition": "fixtures.value-types", "version": "1.0.7", "values": {}}';
            testCase.verifyEqual(testCase.ValueTypes.decode(jsonText), testCase.ValueTypes.defaults())
        end

        function testOlderMinorVersionGetsNewDefaults(testCase)
            % Version 1.2.0 added "smoothing"; a 1.0.0 document lacks it
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, "minor.json", ...
                '{"size": {"type": "integer", "default": 4}, "smoothing": {"type": "number", "default": 0.5}}', ...
                '{"$id": "test.minor", "x-version": "1.2.0", "type": "object", "properties": {"size": {"type": "integer", "default": 4}, "smoothing": {"type": "number", "default": 0.5}}}');
            definition = optionspec.Definition(filePath);
            jsonText = '{"optionspec": "1", "definition": "test.minor", "version": "1.0.0", "values": {"size": 9}}';
            [values, header] = definition.decode(jsonText);
            testCase.verifyEqual(values, struct("size", 9, "smoothing", 0.5))
            testCase.verifyEqual(header.Version, "1.0.0")
        end
    end
end
