classdef UpdateDefinitionTest < matlab.unittest.TestCase
% UpdateDefinitionTest - Tests for checkDefinition and updateDefinition.
%
%   Each test edits an option struct the way a NANSEN user edits the
%   options of a session method, and checks the version change and the
%   migration that follow.

    properties
        TemporaryFolder (1,1) string
        DefinitionFile (1,1) string
        Options struct
    end

    methods (TestMethodSetup)
        function createDefinition(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TemporaryFolder = fixture.Folder;
            testCase.DefinitionFile = fullfile(testCase.TemporaryFolder, "motion.options.json");
            testCase.Options = optionspectest.nansenOptionStructs().MotionCorrection;
            testCase.Options.Run.numFramesPerPart = 1000;
            testCase.Options.Run.numFramesPerPart_ = '(1,1) double {mustBeInteger, mustBeInRange(x, 1, 10000)}';
            testCase.Options.Run.frameInterval = [];
            testCase.Options.Run.frameInterval_ = '(1,2) double {mustBeInteger, mustBePositive}';
            testCase.Options.Run.radius = 5;
            optionspec.updateDefinition(testCase.Options, testCase.DefinitionFile, Id="nansen.motion");
        end
    end

    methods (Test)
        function testCreatedDefinition(testCase)
            definition = optionspec.Definition(testCase.DefinitionFile);
            testCase.verifyEqual(definition.Version, "1.0.0")
            testCase.verifyEqual(definition.Id, "nansen.motion")
            testCase.verifyEqual(definition.MigrationFile, "")
        end

        function testEditsAndLevels(testCase)
            % Each row: edit of the options struct, expected kind and level
            cases = {
                @(S) setPath(S, "Run.newOption", true), "added", "minor"
                @(S) removePath(S, "Run.radius"), "removed", "major"
                @(S) setPath(S, "Run.radius", 10), "default", "minor"
                @(S) setPath(S, "Export.OutputFormat_", {'Binary', 'Tiff', 'Zarr'}), "enum", "minor"
                @(S) setPath(S, "Export.OutputFormat_", {'Tiff'}), "enum", "major"
                @(S) setPath(S, "Preprocessing.NumFlybackLines_", {0, 1, 2}), "enum", "major"
                @(S) setPath(S, "Run.numFramesPerPart_", '(1,1) double {mustBeInteger, mustBeInRange(x, 1, 20000)}'), "range", "minor"
                @(S) setPath(S, "Run.numFramesPerPart_", '(1,1) double {mustBeInteger, mustBeInRange(x, 10, 10000)}'), "range", "major"
                @(S) setPath(S, "Run.numFramesPerPart_", '(1,1) double {mustBeFinite, mustBeInRange(x, 1, 10000)}'), "type", "minor"
                @(S) setPath(S, "Run.radius_", '(1,1) double {mustBeInteger}'), "type", "major"
                @(S) setPath(S, "Run.radius_", '(1,1) double {mustBeFinite}'), "nonfinite", "major"
                @(S) setPath(S, "Run.radius", 'five'), "type", "major"
                @(S) setPath(S, "Run.frameInterval_", '(1,:) double {mustBeInteger, mustBePositive}'), "null", "major"
                @(S) setPath(S, "Run.frameInterval_", '(1,3) double {mustBeInteger, mustBePositive}'), "count", "major"
                @(S) setPath(S, "Export.SaveDirectory_", 'internal'), "annotation", "patch"
                @(S) setPath(S, "Preview", struct('run', false, 'stop', false)), "added", "minor"
                @(S) setPath(S, "Preview", true), "type", "major"
                };
            for i = 1:height(cases)
                diagnostic = sprintf("Case %d", i);
                edited = cases{i, 1}(testCase.Options);
                [changes, level] = optionspec.checkDefinition(edited, testCase.DefinitionFile);
                testCase.verifyEqual(level, cases{i, 3}, diagnostic)
                testCase.verifyTrue(any(string({changes.Kind}) == cases{i, 2}), ...
                    diagnostic + ": kinds found: " + strjoin(string({changes.Kind}), ", "))
            end
        end

        function testUnchangedStructWritesNothing(testCase)
            before = dir(testCase.DefinitionFile);
            textBefore = fileread(testCase.DefinitionFile);
            [definition, changes, level] = optionspec.updateDefinition(testCase.Options, testCase.DefinitionFile);
            testCase.verifyEqual(level, "none")
            testCase.verifyEmpty(changes)
            testCase.verifyEqual(definition.Version, "1.0.0")
            testCase.verifyEqual(fileread(testCase.DefinitionFile), textBefore)
            testCase.verifyEqual(dir(testCase.DefinitionFile).datenum, before.datenum)
        end

        function testVersionBumps(testCase)
            options = setPath(testCase.Options, "Export.SaveDirectory_", 'internal');
            [definition, ~, level] = optionspec.updateDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual([level, definition.Version], ["patch", "1.0.1"])

            options = setPath(options, "Run.radius", 7);
            [definition, ~, level] = optionspec.updateDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual([level, definition.Version], ["minor", "1.1.0"])
            testCase.verifyEqual(definition.defaults().Run.radius, 7)
            testCase.verifyEqual(definition.MigrationFile, "", "A minor change writes no migration.")

            options = removePath(options, "Run.radius");
            [definition, ~, level] = optionspec.updateDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual([level, definition.Version], ["major", "2.0.0"])
        end

        function testMajorChangeWritesMigration(testCase)
            options = removePath(testCase.Options, "Run.radius");
            options = setPath(options, "Preview", true);
            definition = optionspec.updateDefinition(options, testCase.DefinitionFile);
            migrations = jsondecode(fileread(definition.MigrationFile));
            testCase.verifyEqual(migrations.definition, 'nansen.motion')
            step = migrations.migrations;
            testCase.verifyEqual([step.from, step.to], [1, 2])
            operations = step.operations;
            testCase.verifyEqual(string({operations.op}), ["remove", "remove"])
            testCase.verifyEqual(string({operations.path}), ["Preview", "Run.radius"])

            old = struct("Run", struct("radius", 3, "numFramesPerPart", 50), "Preview", struct("run", true));
            values = definition.upgrade(old, "1.0.0");
            testCase.verifyEqual(values.Run.numFramesPerPart, 50)
            testCase.verifyTrue(values.Preview)
            testCase.verifyFalse(isfield(values.Run, "radius"))
        end

        function testRenames(testCase)
            options = removePath(testCase.Options, "Run.radius");
            options = setPath(options, "Run.outerRadius", 5);
            [~, level, candidates] = optionspec.checkDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual(level, "major")
            testCase.verifyEqual(candidates, ["Run.radius", "Run.outerRadius"])

            [definition, changes] = optionspec.updateDefinition(options, testCase.DefinitionFile, ...
                Renames=candidates);
            testCase.verifyEqual(string({changes.Kind}), "renamed")
            values = definition.upgrade(struct("Run", struct("radius", 12)), "1.0.0");
            testCase.verifyEqual(values.Run.outerRadius, 12)
        end

        function testRenameCandidatesNeedSameGroupAndType(testCase)
            options = removePath(testCase.Options, "Run.radius");
            options = setPath(options, "Export.radius", 5);
            options = setPath(options, "Run.label", 'x');
            [~, ~, candidates] = optionspec.checkDefinition(options, testCase.DefinitionFile);
            testCase.verifyEmpty(candidates)
        end

        function testInvalidRename(testCase)
            options = setPath(testCase.Options, "Run.extra", 1);
            testCase.verifyError(@() optionspec.updateDefinition(options, testCase.DefinitionFile, ...
                Renames=["Run.radius", "Run.extra"]), "OPTIONSPEC:InvalidRename")
        end

        function testMigrationStepsAccumulate(testCase)
            options = removePath(testCase.Options, "Run.radius");
            optionspec.updateDefinition(options, testCase.DefinitionFile);
            options = removePath(options, "Preview");
            definition = optionspec.updateDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual(definition.Version, "3.0.0")

            old = struct("Run", struct("radius", 1), "Preview", struct("run", true), ...
                "Export", struct("OutputFormat", 'Binary'));
            values = definition.upgrade(old, "1.0.0");
            testCase.verifyFalse(isfield(values, "Preview"))
            testCase.verifyEqual(values.Export.OutputFormat, 'Binary')
        end

        function testExistingEmptyMigrationsFile(testCase)
            migrationFile = fullfile(testCase.TemporaryFolder, "motion.options.migrations.json");
            fileId = fopen(migrationFile, "w");
            fwrite(fileId, '{"definition": "nansen.motion", "migrations": []}', "char");
            fclose(fileId);
            definition = optionspec.updateDefinition(removePath(testCase.Options, "Run.radius"), ...
                testCase.DefinitionFile);
            testCase.verifyEqual(definition.Version, "2.0.0")
            testCase.verifyEqual(definition.upgrade(struct("Run", struct("radius", 2)), "1.0.0"), ...
                definition.defaults())
        end

        function testNarrowedValuesAreKept(testCase)
            options = setPath(testCase.Options, "Export.OutputFormat_", {'Tiff'});
            definition = optionspec.updateDefinition(options, testCase.DefinitionFile);
            migrations = jsondecode(fileread(definition.MigrationFile));
            testCase.verifySubstring(migrations.migrations.description, 'Export.OutputFormat')
            testCase.verifyError(@() definition.upgrade(struct("Export", struct("OutputFormat", 'Binary')), ...
                "1.0.0"), "OPTIONSPEC:InvalidValues")
        end

        function testHeaderIsKeptOrReplaced(testCase)
            options = setPath(testCase.Options, "Run.radius", 8);
            definition = optionspec.updateDefinition(options, testCase.DefinitionFile, Title="Motion");
            testCase.verifyEqual(definition.Title, "Motion")
            options = setPath(options, "Run.radius", 9);
            definition = optionspec.updateDefinition(options, testCase.DefinitionFile);
            testCase.verifyEqual(definition.Title, "Motion")
        end

        function testCreateNeedsId(testCase)
            testCase.verifyError(@() optionspec.updateDefinition(testCase.Options, ...
                fullfile(testCase.TemporaryFolder, "new.json")), "OPTIONSPEC:IdRequired")
        end

        function testComposedDefinitionIsNotSupported(testCase)
            definitionFile = optionspectest.fixtureFile("definitions", "composition", "normcorre-processor.json");
            testCase.verifyError(@() optionspec.checkDefinition(struct("a", 1), definitionFile), ...
                "OPTIONSPEC:IncludesNotSupported")
        end
    end
end

function options = setPath(options, path, value)
    options = optionspec.internal.optionPath("set", options, path, value);
end

function options = removePath(options, path)
    options = optionspec.internal.optionPath("remove", options, path);
end
