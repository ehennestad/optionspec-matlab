function [definition, changes, level] = updateDefinition(options, definitionFile, nameValues)
%updateDefinition Bring a definition file in step with an options struct.
%
%   [definition, changes, level] = optionspec.updateDefinition(options,
%   definitionFile) compares the struct options with the definition in
%   definitionFile, as optionspec.checkDefinition does, and if they differ
%   rewrites the file from the struct with a new version:
%
%     patch  1.2.3 -> 1.2.4   titles, descriptions or hints changed
%     minor  1.2.3 -> 1.3.0   options added, enum values added, ranges
%                             widened, defaults changed
%     major  1.2.3 -> 2.0.0   options removed or retyped, enum values
%                             removed, ranges narrowed
%
%   For a major change it adds a migration from the old major version to
%   <name>.migrations.json next to the definition: a "rename" operation for
%   each confirmed rename and a "remove" operation for each removed or
%   retyped option, so that old values of those options give way to the
%   new defaults. Old values of a narrowed option are kept; if they are no
%   longer valid, reading them is an OPTIONSPEC:InvalidValues error.
%
%   It returns the definition as read after the update, the changes found,
%   and the level of the version change ("none" if the file already
%   matched, "created" if the file did not exist).
%
%   If definitionFile does not exist, it is written from the struct with
%   version 1.0.0; Id is then required.
%
%   The function writes no file when the struct matches the definition.
%   The new files are written to a temporary folder and read back before
%   they replace the old ones.
%
%   Name-value arguments:
%     Id           - "$id" for a new definition file
%     Title        - "title". Default: the title of the existing file
%     Description  - "description". Default: the description of the
%                    existing file
%     Descriptions - Descriptions of the options, as for
%                    optionspec.inferDefinition. Default: struct()
%     Renames      - N-by-2 string array of confirmed renames,
%                    [oldPath, newPath], such as ["Correction.maxShift",
%                    "Correction.maximumShift"]. Each pair must be a
%                    removed and an added option. Default: none
%
%   See also optionspec.checkDefinition, optionspec.inferDefinition

    arguments
        options (1,1) struct
        definitionFile (1,1) string
        nameValues.Id (1,1) string = ""
        nameValues.Title string {mustBeScalarOrEmpty} = string.empty
        nameValues.Description string {mustBeScalarOrEmpty} = string.empty
        nameValues.Descriptions (1,1) struct = struct()
        nameValues.Renames (:,2) string = strings(0, 2)
    end

    if ~isfile(definitionFile)
        if nameValues.Id == ""
            error("OPTIONSPEC:IdRequired", ...
                "Definition file ""%s"" does not exist. Pass Id to create it.", definitionFile)
        end
        jsonText = optionspec.inferDefinition(options, Id=nameValues.Id, ...
            Title=firstOrDefault(nameValues.Title, ""), ...
            Description=firstOrDefault(nameValues.Description, ""), ...
            Descriptions=nameValues.Descriptions);
        writeText(definitionFile, jsonText);
        definition = optionspec.Definition(definitionFile);
        changes = struct("Path", {}, "Kind", {}, "Detail", {}, "Level", {});
        level = "created";
        return
    end

    oldDefinition = optionspec.Definition(definitionFile);
    [changes, level] = optionspec.checkDefinition(options, oldDefinition, ...
        Descriptions=nameValues.Descriptions);
    changes = applyRenames(changes, nameValues.Renames);
    if level == "none"
        definition = oldDefinition;
        return
    end

    newVersion = bumpVersion(oldDefinition.Version, level);
    header = struct( ...
        "Id", oldDefinition.Id, ...
        "Version", newVersion, ...
        "Title", firstOrDefault(nameValues.Title, oldDefinition.Title), ...
        "Description", firstOrDefault(nameValues.Description, oldDefinition.Description));
    newRoot = optionspec.internal.inferRootNode(options, nameValues.Descriptions);
    definitionText = optionspec.internal.renderDefinition(header, newRoot);

    [folder, name] = fileparts(definitionFile);
    migrationFile = fullfile(folder, name + ".migrations.json");
    migrationText = "";
    if level == "major"
        oldMajor = optionspec.internal.parseVersion(oldDefinition.Version);
        step = migrationStep(changes, oldMajor(1), oldDefinition.Version, newVersion);
        migrationText = addMigrationStep(migrationFile, oldDefinition.Id, step);
    end

    % Write to a temporary folder and read the result back first, so that
    % a definition that fails to load never replaces a working one
    temporaryFolder = tempname();
    mkdir(temporaryFolder)
    removeFolder = onCleanup(@() rmdir(temporaryFolder, "s"));
    writeText(fullfile(temporaryFolder, name + ".json"), definitionText);
    if migrationText ~= ""
        writeText(fullfile(temporaryFolder, name + ".migrations.json"), migrationText);
    elseif isfile(migrationFile)
        copyfile(migrationFile, fullfile(temporaryFolder, name + ".migrations.json"));
    end
    optionspec.Definition(fullfile(temporaryFolder, name + ".json"));

    writeText(definitionFile, definitionText);
    if migrationText ~= ""
        writeText(migrationFile, migrationText);
    end
    definition = optionspec.Definition(definitionFile);
end

function changes = applyRenames(changes, renames)
    for i = 1:height(renames)
        paths = string({changes.Path});
        kinds = string({changes.Kind});
        removedIndex = find(paths == renames(i, 1) & kinds == "removed", 1);
        addedIndex = find(paths == renames(i, 2) & kinds == "added", 1);
        if isempty(removedIndex) || isempty(addedIndex)
            error("OPTIONSPEC:InvalidRename", ...
                "Rename from ""%s"" to ""%s"" does not match a removed and an added option.", ...
                renames(i, 1), renames(i, 2))
        end
        changes(removedIndex).Kind = "renamed";
        changes(removedIndex).Detail = "renamed to " + renames(i, 2);
        changes(addedIndex) = [];
    end
end

function version = bumpVersion(version, level)
    numbers = optionspec.internal.parseVersion(version);
    switch level
        case "major"
            numbers = [numbers(1) + 1, 0, 0];
        case "minor"
            numbers = [numbers(1), numbers(2) + 1, 0];
        otherwise
            numbers(3) = numbers(3) + 1;
    end
    version = strjoin(string(numbers), ".");
end

function step = migrationStep(changes, oldMajor, oldVersion, newVersion)
    operations = {};
    narrowedPaths = strings(1, 0);
    for change = changes
        switch change.Kind
            case "renamed"
                operations{end+1} = struct("op", 'rename', "from", char(change.Path), ...
                    "to", char(extractAfter(change.Detail, "renamed to "))); %#ok<AGROW>
            case "removed"
                operations{end+1} = struct("op", 'remove', "path", char(change.Path)); %#ok<AGROW>
            case "type"
                if change.Level == "major" && ~contains(change.Path, "(:)")
                    operations{end+1} = struct("op", 'remove', "path", char(change.Path)); %#ok<AGROW>
                else
                    narrowedPaths(end+1) = change.Path; %#ok<AGROW>
                end
            otherwise
                if change.Level == "major"
                    narrowedPaths(end+1) = change.Path; %#ok<AGROW>
                end
        end
    end
    description = sprintf("Written by optionspec.updateDefinition for the change from %s to %s.", ...
        oldVersion, newVersion);
    narrowedPaths = unique(narrowedPaths, "stable");
    if ~isempty(narrowedPaths)
        description = description + " Values of " + strjoin(narrowedPaths, ", ") ...
            + " are kept and may be invalid under the new version.";
    end
    step = struct("from", oldMajor, "to", oldMajor + 1, "description", char(description), ...
        "operations", {operations});
end

function jsonText = addMigrationStep(migrationFile, definitionId, step)
% Add a step as text, so that the existing steps keep their formatting and
% the shape of their values
    stepText = string(jsonencode(step, PrettyPrint=true));
    if ~isfile(migrationFile)
        document = struct("definition", char(definitionId), "migrations", {{step}});
        jsonText = string(jsonencode(document, PrettyPrint=true)) + newline;
        return
    end

    jsonText = string(fileread(migrationFile));
    indentedStep = "    " + replace(stepText, newline, newline + "    ");
    [emptyStart, emptyEnd] = regexp(jsonText, '\[\s*\]', "start", "end", "once");
    isEmptyArray = ~isempty(emptyStart) ...
        && ~isempty(regexp(extractBefore(jsonText, emptyStart), '"migrations"\s*:\s*$', "once"));
    if isEmptyArray
        jsonText = extractBefore(jsonText, emptyStart) + "[" + newline + indentedStep + newline + "  ]" ...
            + extractAfter(jsonText, emptyEnd);
    else
        closingIndex = regexp(jsonText, '\]\s*\}\s*$', "once");
        if isempty(closingIndex)
            error("OPTIONSPEC:CannotUpdateMigrations", ...
                "Cannot find the end of the ""migrations"" array in ""%s"". Add the migration by hand.", ...
                migrationFile)
        end
        before = strip(extractBefore(jsonText, closingIndex), "right");
        jsonText = before + "," + newline + indentedStep + newline + "  " + extractAfter(jsonText, closingIndex - 1);
    end
end

function value = firstOrDefault(value, defaultValue)
    if isempty(value)
        value = defaultValue;
    end
end

function writeText(filePath, text)
    [fileId, message] = fopen(filePath, "w", "n", "UTF-8");
    if fileId == -1
        error("OPTIONSPEC:CannotWriteFile", "Cannot write file ""%s"": %s", filePath, message)
    end
    closeFile = onCleanup(@() fclose(fileId));
    fwrite(fileId, text, "char");
end
