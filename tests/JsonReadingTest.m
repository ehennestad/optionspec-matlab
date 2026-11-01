classdef JsonReadingTest < matlab.unittest.TestCase
% JsonReadingTest - Tests for decoding JSON text and parsing versions.

    methods (Test)
        function testKeywordsDecodeToFields(testCase)
            jsonText = '{"$schema": "s", "$id": "i", "x-version": "1.0.0", "x-ui": {"widget": "edit"}}';
            data = optionspec.internal.decodeJson(jsonText);
            testCase.verifyEqual(sort(string(fieldnames(data)))', ...
                ["x_id", "x_schema", "x_ui", "x_version"])
        end

        function testInvalidKeyIsAnError(testCase)
            % jsondecode would rename "my-option" to my_option without notice
            jsonText = '{"values": {"my-option": 1, "valid": 2}}';
            testCase.verifyError(@() optionspec.internal.decodeJson(jsonText), ...
                "OPTIONSPEC:InvalidKey")
        end

        function testStringValuesAreNotTreatedAsKeys(testCase)
            % Colons and quotes inside string values are not keys
            jsonText = '{"a": ["b: c", "\"d\": e", "f"], "g": "h:"}';
            data = optionspec.internal.decodeJson(jsonText);
            testCase.verifyEqual(data.g, 'h:')
            testCase.verifyEqual(data.a{2}, '"d": e')
        end

        function testInvalidJsonIsAnError(testCase)
            testCase.verifyError(@() optionspec.internal.decodeJson('{"a": }'), ...
                "OPTIONSPEC:InvalidJson")
        end

        function testNonFiniteTokensAreAnError(testCase)
            % jsondecode reads these tokens, but they are not JSON
            for jsonText = ["[NaN]", "{""a"": Infinity}", "[1, -Infinity]"]
                testCase.verifyError(@() optionspec.internal.decodeJson(jsonText), ...
                    "OPTIONSPEC:InvalidJson", jsonText)
            end
            data = optionspec.internal.decodeJson('{"a": ["NaN", "Infinity", "-Inf"]}');
            testCase.verifyEqual(data.a, {'NaN'; 'Infinity'; '-Inf'})
        end

        function testMissingFileIsAnError(testCase)
            testCase.verifyError(@() optionspec.internal.readJsonFile("does-not-exist.json"), ...
                "OPTIONSPEC:FileNotFound")
        end

        function testReadFileAsUtf8(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            filePath = fullfile(folder, "text.json");
            fileId = fopen(filePath, "w", "n", "UTF-8");
            fwrite(fileId, '{"label": "µm"}', "char");
            fclose(fileId);
            data = optionspec.internal.readJsonFile(filePath);
            testCase.verifyEqual(data.label, 'µm')
        end

        function testParseVersion(testCase)
            testCase.verifyEqual(optionspec.internal.parseVersion("2.10.0"), [2, 10, 0])
        end

        function testInvalidVersions(testCase)
            invalidVersions = {"1.0", "1.0.0-beta", "01.0.0", "v1.0.0", 1, ["1.0.0", "2.0.0"]};
            for i = 1:numel(invalidVersions)
                testCase.verifyError(@() optionspec.internal.parseVersion(invalidVersions{i}), ...
                    "OPTIONSPEC:InvalidVersion")
            end
        end

        function testCompareVersions(testCase)
            testCase.verifyEqual(optionspec.internal.compareVersions("1.2.0", "1.10.0"), -1)
            testCase.verifyEqual(optionspec.internal.compareVersions("2.0.0", "1.9.9"), 1)
            testCase.verifyEqual(optionspec.internal.compareVersions("1.0.3", "1.0.3"), 0)
        end
    end
end
