classdef MigrationTest < matlab.unittest.TestCase
% MigrationTest - Tests for upgrading values written under older definition versions.
%
%   The normcorre fixture has two migrations. Version 1 to 2 renames
%   options, fixes a misspelled name (NANSEN's NoRMCorre options spell
%   UseParallell) and maps an enum value. Version 2 to 3 renames a group,
%   calls a MATLAB function, removes an option and adds one. The suite2p
%   fixture converts milliseconds to seconds with "scale".

    properties
        TemporaryFolder (1,1) string
        Normcorre optionspec.Definition
    end

    methods (TestClassSetup)
        function readDefinition(testCase)
            testCase.Normcorre = optionspec.Definition( ...
                optionspectest.fixtureFile("definitions", "normcorre.json"));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
        end
    end

    methods (Test)
        function testMigrationFileIsFound(testCase)
            testCase.verifyEqual(testCase.Normcorre.MigrationFile, ...
                optionspectest.fixtureFile("definitions", "normcorre.migrations.json"))
            backup = optionspec.Definition(optionspectest.fixtureFile("definitions", "backup.json"));
            testCase.verifyEqual(backup.MigrationFile, "")
        end

        function testUpgradeTwoMajorVersions(testCase)
            [values, header] = testCase.Normcorre.readDocument( ...
                optionspectest.fixtureFile("documents", "normcorre-1.2.0.json"));
            testCase.verifyEqual(header.Version, "1.2.0")

            expected = struct();
            expected.Configuration = struct("numRows", 2, "numCols", 3, ...
                "patchOverlap", [16, 16, 8], "gridUpsampling", [2, 2, 1]);
            expected.Template = struct("initialBatchSize", 200, "updateTemplate", false, "binWidth", 25);
            expected.Correction = struct("maximumShift", [20, 20, 2], "maximumDeviation", [10, 10, 1], ...
                "subpixelUpsampling", 20, "numIterations", 2, "shiftsMethod", 'FFT', ...
                "boundary", 'zero', "phaseFlag", true);
            expected.Misc = struct("Verbose", true, "UseParallel", false);
            testCase.verifyEqual(values, expected)
        end

        function testUpgradePartialDocumentOneMajorVersion(testCase)
            values = testCase.Normcorre.readDocument( ...
                optionspectest.fixtureFile("documents", "normcorre-2.0.0.json"));

            expected = testCase.Normcorre.defaults();
            expected.Configuration.numRows = 1;
            expected.Configuration.numCols = 1;
            expected.Configuration.gridUpsampling = [4, 4, 1];
            expected.Correction.shiftsMethod = 'cubic';
            expected.Correction.phaseFlag = true;
            testCase.verifyEqual(values, expected)
        end

        function testScaleConvertsUnits(testCase)
            definition = optionspec.Definition(optionspectest.fixtureFile("definitions", "suite2p.json"));
            values = definition.readDocument(optionspectest.fixtureFile("documents", "suite2p-1.0.0.json"));
            testCase.verifyEqual(values.Deconvolution.sensorTimeConstant, 1.5, AbsTol=1e-12)
            testCase.verifyEqual(values.Deconvolution.imagingRate, 31)
            testCase.verifyEqual(values.Neuropil.radius, Inf)
        end

        function testUpgradeStructInMemory(testCase)
            % Values saved as a struct, such as a NANSEN preset, upgrade the same way
            saved = struct("Correction", struct("maxShift", [5, 5, 1], "shiftsMethod", 'fft'));
            values = testCase.Normcorre.upgrade(saved, "1.0.0");
            testCase.verifyEqual(values.Correction.maximumShift, [5, 5, 1])
            testCase.verifyEqual(values.Correction.shiftsMethod, 'FFT')
        end

        function testCurrentVersionSkipsMigrations(testCase)
            % A version 3 document that uses a version 1 name is invalid
            saved = struct("Correction", struct("maxShift", [5, 5, 1]));
            testCase.verifyError(@() testCase.Normcorre.upgrade(saved, "3.0.0"), "OPTIONSPEC:InvalidValues")
        end

        function testRoundTripAfterUpgrade(testCase)
            values = testCase.Normcorre.readDocument( ...
                optionspectest.fixtureFile("documents", "normcorre-1.2.0.json"));
            [decoded, header] = testCase.Normcorre.decode(testCase.Normcorre.encode(values));
            testCase.verifyEqual(decoded, values)
            testCase.verifyEqual(header.Version, "3.0.0")
        end

        function testOperations(testCase)
            % Each row: operations of a 1 to 2 migration, values of version
            % 1 and expected values of version 2 (before validation). The
            % definition has a "Run" group with "mode", "size" and "range"
            % and a top-level "label".
            cases = {
                '{"op": "rename", "from": "Run.count", "to": "Run.size"}', struct("Run", struct("count", 4)), struct("Run", struct("size", 4))
                '{"op": "rename", "from": "Run.count", "to": "Run.size"}', struct("label", 'x'), struct("label", 'x')
                '{"op": "rename", "from": "name", "to": "Run.mode"}', struct("name", 'batch'), struct("Run", struct("mode", 'batch'))
                '{"op": "rename", "from": "Old", "to": "Run"}', struct("Old", struct("size", 2)), struct("Run", struct("size", 2))
                '{"op": "remove", "path": "Run.legacy"}', struct("Run", struct("legacy", 1, "size", 2)), struct("Run", struct("size", 2))
                '{"op": "remove", "path": "Old.only"}', struct("Old", struct("only", 1), "label", 'x'), struct("label", 'x')
                '{"op": "remove", "path": "Run.legacy"}', struct("label", 'x'), struct("label", 'x')
                '{"op": "add", "path": "Run.mode", "value": "batch"}', struct("label", 'x'), struct("label", 'x', "Run", struct("mode", 'batch'))
                '{"op": "add", "path": "Run.mode", "value": "batch"}', struct("Run", struct("mode", 'serial')), struct("Run", struct("mode", 'serial'))
                '{"op": "add", "path": "Run.range", "value": [1, "Inf"]}', struct(), struct("Run", struct("range", {{1; 'Inf'}}))
                '{"op": "mapValues", "path": "Run.mode", "map": [{"from": "seq", "to": "serial"}, {"from": "par", "to": "batch"}]}', struct("Run", struct("mode", 'par')), struct("Run", struct("mode", 'batch'))
                '{"op": "mapValues", "path": "Run.mode", "map": [{"from": "seq", "to": "serial"}]}', struct("Run", struct("mode", 'batch')), struct("Run", struct("mode", 'batch'))
                '{"op": "mapValues", "path": "Run.size", "map": [{"from": 0, "to": 1}]}', struct("Run", struct("size", 0)), struct("Run", struct("size", 1))
                '{"op": "scale", "path": "Run.size", "factor": 2}', struct("Run", struct("size", 3)), struct("Run", struct("size", 6))
                '{"op": "scale", "path": "Run.range", "factor": 10}', struct("Run", struct("range", [1; 2])), struct("Run", struct("range", [10; 20]))
                '{"op": "scale", "path": "Run.range", "factor": 10}', struct("Run", struct("range", {{1; 'Inf'}})), struct("Run", struct("range", {{10; 'Inf'}}))
                };
            for i = 1:height(cases)
                definition = testCase.writeVersionedDefinition(sprintf("ops%d", i), cases{i, 1});
                migrated = optionspec.internal.applyMigrations(cases{i, 2}, ...
                    loadSteps(definition), 1, 2, definition.Id);
                testCase.verifyEqual(migrated, cases{i, 3}, sprintf("Case %d", i))
            end
        end

        function testMigratedValuesAreValidated(testCase)
            definition = testCase.writeVersionedDefinition("validated", ...
                '{"op": "rename", "from": "Run.count", "to": "Run.size"}');
            values = definition.upgrade(struct("Run", struct("count", 7)), "1.4.2");
            testCase.verifyEqual(values.Run.size, 7)
            testCase.verifyEqual(values.Run.mode, 'serial')
            testCase.verifyError(@() definition.upgrade(struct("Run", struct("count", 0)), "1.0.0"), ...
                "OPTIONSPEC:InvalidValues")
        end

        function testMigrationFailures(testCase)
            definition = testCase.writeVersionedDefinition("conflict", ...
                '{"op": "rename", "from": "Run.count", "to": "Run.size"}');
            testCase.verifyError(@() definition.upgrade( ...
                struct("Run", struct("count", 1, "size", 2)), "1.0.0"), "OPTIONSPEC:MigrationFailed")

            definition = testCase.writeVersionedDefinition("nongroup", ...
                '{"op": "add", "path": "label.part", "value": 1}');
            testCase.verifyError(@() definition.upgrade(struct("label", 'x'), "1.0.0"), ...
                "OPTIONSPEC:MigrationFailed")

            definition = testCase.writeVersionedDefinition("nofunction", ...
                '{"op": "function", "matlab": "optionspectest.doesNotExist"}');
            testCase.verifyError(@() definition.upgrade(struct(), "1.0.0"), "OPTIONSPEC:MigrationFailed")

            % numel returns a number, not a values struct
            definition = testCase.writeVersionedDefinition("badoutput", ...
                '{"op": "function", "matlab": "numel"}');
            testCase.verifyError(@() definition.upgrade(struct(), "1.0.0"), "OPTIONSPEC:MigrationFailed")

            % fixtureFile throws an error when it is given a struct
            definition = testCase.writeVersionedDefinition("throws", ...
                '{"op": "function", "matlab": "optionspectest.fixtureFile"}');
            testCase.verifyError(@() definition.upgrade(struct(), "1.0.0"), "OPTIONSPEC:MigrationFailed")
        end

        function testMissingMigrations(testCase)
            % Version 3 with a migration from 2 to 3 only
            filePath = testCase.writeDefinitionFile("gap", "3.0.0");
            writeText(fullfile(testCase.TemporaryFolder, "gap.migrations.json"), ...
                '{"definition": "test.gap", "migrations": [{"from": 2, "to": 3, "operations": []}]}');
            definition = optionspec.Definition(filePath);
            testCase.verifyEqual(definition.upgrade(struct(), "2.5.0"), definition.defaults())
            testCase.verifyError(@() definition.upgrade(struct(), "1.0.0"), "OPTIONSPEC:MissingMigration")

            % No migrations file
            definition = optionspec.Definition(testCase.writeDefinitionFile("none", "2.0.0"));
            testCase.verifyError(@() definition.upgrade(struct(), "1.0.0"), "OPTIONSPEC:MissingMigration")
        end

        function testInvalidMigrationFiles(testCase)
            % Each row: the "migrations" array, and text the error must contain
            cases = {
                '[{"from": 1, "to": 3, "operations": []}]', "consecutive major versions"
                '[{"from": "1", "to": "2", "operations": []}]', "consecutive major versions"
                '[{"from": 2, "to": 3, "operations": []}]', "beyond the definition's major version 2"
                '[{"from": 1, "to": 2, "operations": []}, {"from": 1, "to": 2, "operations": []}]', "more than one migration from version 1"
                '[{"from": 1, "to": 2}]', """operations"" is missing"
                '[{"from": 1, "to": 2, "operations": [], "author": "x"}]', "key ""author"" is not part of a migration"
                '[{"from": 1, "to": 2, "operations": [{"op": "move", "path": "a"}]}]', """op"" must be one of"
                '[{"from": 1, "to": 2, "operations": [{"path": "a"}]}]', """op"" must be one of"
                '[{"from": 1, "to": 2, "operations": [{"op": "rename", "from": "a"}]}]', """to"" is missing"
                '[{"from": 1, "to": 2, "operations": [{"op": "remove", "path": "a", "value": 1}]}]', "key ""value"" is not part of a ""remove"" operation"
                '[{"from": 1, "to": 2, "operations": [{"op": "remove", "path": "a..b"}]}]', """path"" must be a dotted option path"
                '[{"from": 1, "to": 2, "operations": [{"op": "remove", "path": 3}]}]', """path"" must be a dotted option path"
                '[{"from": 1, "to": 2, "operations": [{"op": "mapValues", "path": "a", "map": []}]}]', """map"" must be a non-empty array"
                '[{"from": 1, "to": 2, "operations": [{"op": "mapValues", "path": "a", "map": [{"old": 1, "new": 2}]}]}]', """map"" must be a non-empty array"
                '[{"from": 1, "to": 2, "operations": [{"op": "scale", "path": "a", "factor": "2"}]}]', """factor"" must be a finite number"
                '[{"from": 1, "to": 2, "operations": [{"op": "function", "matlab": "not a name"}]}]', """matlab"" must be the name"
                '{"from": 1}', "consecutive major versions"
                '3', """migrations"" must be an array"
                };
            for i = 1:height(cases)
                name = sprintf("invalid%d", i);
                filePath = testCase.writeDefinitionFile(name, "2.0.0");
                writeText(fullfile(testCase.TemporaryFolder, name + ".migrations.json"), ...
                    sprintf('{"definition": "test.%s", "migrations": %s}', name, cases{i, 1}));
                testCase.verifyMigrationError(filePath, cases{i, 2}, i)
            end

            filePath = testCase.writeDefinitionFile("wrongid", "2.0.0");
            writeText(fullfile(testCase.TemporaryFolder, "wrongid.migrations.json"), ...
                '{"definition": "test.other", "migrations": []}');
            testCase.verifyMigrationError(filePath, """definition"" must be ""test.wrongid""", 0)

            filePath = testCase.writeDefinitionFile("extrakey", "2.0.0");
            writeText(fullfile(testCase.TemporaryFolder, "extrakey.migrations.json"), ...
                '{"definition": "test.extrakey", "migrations": [], "version": 2}');
            testCase.verifyMigrationError(filePath, "Key ""version"" is not part", 0)
        end
    end

    methods
        function filePath = writeDefinitionFile(testCase, name, version)
            properties = ['{"Run": {"type": "object", "properties": {' ...
                '"mode": {"type": "string", "enum": ["serial", "batch"], "default": "serial"}, ' ...
                '"size": {"type": "integer", "minimum": 1, "default": 1}, ' ...
                '"range": {"type": "array", "items": {"type": "number", "x-nonfinite": ["Inf"]}, "default": []}}}, ' ...
                '"label": {"type": "string", "default": ""}}'];
            filePath = optionspectest.writeDefinition(testCase.TemporaryFolder, name + ".json", "", ...
                sprintf('{"$id": "test.%s", "x-version": "%s", "type": "object", "properties": %s}', ...
                name, version, properties));
        end

        function definition = writeVersionedDefinition(testCase, name, operationsText)
            filePath = testCase.writeDefinitionFile(name, "2.0.0");
            writeText(fullfile(testCase.TemporaryFolder, name + ".migrations.json"), sprintf( ...
                '{"definition": "test.%s", "migrations": [{"from": 1, "to": 2, "operations": [%s]}]}', ...
                name, operationsText));
            definition = optionspec.Definition(filePath);
        end

        function verifyMigrationError(testCase, filePath, expectedText, caseNumber)
            diagnostic = sprintf("Case %d", caseNumber);
            try
                optionspec.Definition(filePath);
                testCase.verifyFail(diagnostic + ": expected an error.")
            catch exception
                testCase.verifyEqual(exception.identifier, 'OPTIONSPEC:InvalidMigration', diagnostic)
                testCase.verifySubstring(exception.message, char(expectedText), diagnostic)
            end
        end
    end
end

function steps = loadSteps(definition)
    version = optionspec.internal.parseVersion(definition.Version);
    steps = optionspec.internal.loadMigrations(definition.MigrationFile, definition.Id, version(1));
end

function writeText(filePath, text)
    fileId = fopen(filePath, "w", "n", "UTF-8");
    fwrite(fileId, text, "char");
    fclose(fileId);
end
