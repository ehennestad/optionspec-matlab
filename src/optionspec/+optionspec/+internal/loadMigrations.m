function steps = loadMigrations(filePath, definitionId, currentMajor)
%loadMigrations Read and check a migrations file.
%
%   steps = optionspec.internal.loadMigrations(filePath, definitionId,
%   currentMajor) reads a migrations file and returns a struct array with
%   one element per step and the fields From, To, Description and
%   Operations. Every problem is listed in one OPTIONSPEC:InvalidMigration
%   error.
%
%   A migrations file holds the steps that upgrade values from one major
%   version of a definition to the next:
%
%     {
%       "definition": "<id>",
%       "migrations": [
%         {"from": 1, "to": 2, "description": "...", "operations": [...]},
%         ...
%       ]
%     }
%
%   Each operation is an object whose "op" is one of:
%     {"op": "rename", "from": "<path>", "to": "<path>"}
%         Move an option or group to another path, creating groups as needed.
%     {"op": "remove", "path": "<path>"}
%         Remove an option or group.
%     {"op": "add", "path": "<path>", "value": <value>}
%         Set an option that the values do not have yet.
%     {"op": "mapValues", "path": "<path>", "map": [{"from": <old>, "to": <new>}, ...]}
%         Replace a value that equals an old value with the new value.
%     {"op": "scale", "path": "<path>", "factor": <number>}
%         Multiply a number, or each number of an array, by factor.
%     {"op": "function", "matlab": "<function name>"}
%         Call a MATLAB function that takes and returns the values struct.
%   A path is a dotted option path such as "Correction.maximumShift".

    arguments
        filePath (1,1) string
        definitionId (1,1) string
        currentMajor (1,1) double
    end

    rawFile = optionspec.internal.readJsonFile(filePath);
    steps = struct("From", {}, "To", {}, "Description", {}, "Operations", {});
    issues = strings(1, 0);

    if ~(isstruct(rawFile) && isscalar(rawFile))
        issues(end+1) = "A migrations file must be a JSON object.";
    else
        for key = setdiff(string(fieldnames(rawFile))', ["definition", "migrations", "x_comment"], "stable")
            issues(end+1) = sprintf("Key ""%s"" is not part of a migrations file.", ...
                optionspec.internal.displayKeyword(key)); %#ok<AGROW>
        end
        if ~isfield(rawFile, "definition") || ~isequal(string(rawFile.definition), definitionId)
            issues(end+1) = sprintf("""definition"" must be ""%s"".", definitionId);
        end
        if isfield(rawFile, "migrations")
            [steps, stepIssues] = readSteps(rawFile.migrations, currentMajor);
            issues = [issues, stepIssues];
        else
            issues(end+1) = """migrations"" is missing.";
        end
    end

    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:InvalidMigration", ...
            sprintf("Migrations file ""%s"" is not valid:", filePath), issues)
    end
end

function [steps, issues] = readSteps(rawSteps, currentMajor)
    steps = struct("From", {}, "To", {}, "Description", {}, "Operations", {});
    issues = strings(1, 0);
    entries = toCellRow(rawSteps);
    if isempty(entries) && ~(isnumeric(rawSteps) && isempty(rawSteps))
        issues(end+1) = """migrations"" must be an array of objects.";
        return
    end

    for i = 1:numel(entries)
        label = sprintf("Migration %d", i);
        entry = entries{i};
        if ~(isstruct(entry) && isscalar(entry))
            issues(end+1) = label + ": must be a JSON object."; %#ok<AGROW>
            continue
        end
        for key = setdiff(string(fieldnames(entry))', ["from", "to", "description", "operations"], "stable")
            issues(end+1) = sprintf("%s: key ""%s"" is not part of a migration.", label, key); %#ok<AGROW>
        end
        if ~(isfield(entry, "from") && isMajorVersion(entry.from) ...
                && isfield(entry, "to") && isMajorVersion(entry.to) && entry.to == entry.from + 1)
            issues(end+1) = label + ": ""from"" and ""to"" must be consecutive major versions, such as 1 and 2."; %#ok<AGROW>
            continue
        end
        if entry.to > currentMajor
            issues(end+1) = sprintf("%s: ""to"" is %d, beyond the definition's major version %d.", ...
                label, entry.to, currentMajor); %#ok<AGROW>
        end
        if any([steps.From] == entry.from)
            issues(end+1) = sprintf("%s: more than one migration from version %d.", label, entry.from); %#ok<AGROW>
        end
        description = "";
        if isfield(entry, "description")
            description = string(entry.description);
        end
        operations = {};
        if isfield(entry, "operations")
            [operations, operationIssues] = readOperations(entry.operations, label);
            issues = [issues, operationIssues]; %#ok<AGROW>
        else
            issues(end+1) = label + ": ""operations"" is missing."; %#ok<AGROW>
        end
        steps(end+1) = struct("From", entry.from, "To", entry.to, ...
            "Description", description, "Operations", {operations}); %#ok<AGROW>
    end
end

function [operations, issues] = readOperations(rawOperations, stepLabel)
    operations = toCellRow(rawOperations);
    issues = strings(1, 0);
    requiredKeys = struct( ...
        "rename", ["from", "to"], ...
        "remove", "path", ...
        "add", ["path", "value"], ...
        "mapValues", ["path", "map"], ...
        "scale", ["path", "factor"], ...
        "function", "matlab");

    for i = 1:numel(operations)
        label = sprintf("%s, operation %d", stepLabel, i);
        operation = operations{i};
        if ~(isstruct(operation) && isscalar(operation) && isfield(operation, "op") ...
                && isfield(requiredKeys, string(operation.op)))
            issues(end+1) = sprintf("%s: ""op"" must be one of %s.", label, ...
                strjoin("""" + string(fieldnames(requiredKeys))' + """", ", ")); %#ok<AGROW>
            continue
        end
        keys = string(fieldnames(operation))';
        expectedKeys = ["op", requiredKeys.(operation.op)];
        for key = setdiff(expectedKeys, keys, "stable")
            issues(end+1) = sprintf("%s: ""%s"" is missing.", label, key); %#ok<AGROW>
        end
        for key = setdiff(keys, expectedKeys, "stable")
            issues(end+1) = sprintf("%s: key ""%s"" is not part of a ""%s"" operation.", ...
                label, key, operation.op); %#ok<AGROW>
        end
        if ~isempty(setdiff(expectedKeys, keys))
            continue
        end
        for key = intersect(["path", "from", "to"], keys, "stable")
            if ~isOptionPath(operation.(key))
                issues(end+1) = sprintf("%s: ""%s"" must be a dotted option path.", label, key); %#ok<AGROW>
            end
        end
        [operations{i}, operationIssues] = checkOperationValues(operation, label);
        issues = [issues, operationIssues]; %#ok<AGROW>
    end
end

function [operation, issues] = checkOperationValues(operation, label)
    issues = strings(1, 0);
    switch operation.op
        case "mapValues"
            pairs = toCellRow(operation.map);
            isPair = @(pair) isstruct(pair) && isscalar(pair) ...
                && isequal(sort(string(fieldnames(pair)))', ["from", "to"]);
            if isempty(pairs) || ~all(cellfun(isPair, pairs))
                issues(end+1) = label + ": ""map"" must be a non-empty array of {""from"": ..., ""to"": ...}.";
            else
                operation.map = pairs;
            end
        case "scale"
            if ~(isnumeric(operation.factor) && isscalar(operation.factor) && isfinite(operation.factor))
                issues(end+1) = label + ": ""factor"" must be a finite number.";
            end
        case "function"
            if ~(ischar(operation.matlab) && isvarname(strrep(operation.matlab, ".", "_")))
                issues(end+1) = label + ": ""matlab"" must be the name of a MATLAB function.";
            end
    end
end

function entries = toCellRow(rawArray)
% jsondecode returns an array of objects as a struct array when the
% objects have the same keys, and as a cell array otherwise
    if isstruct(rawArray)
        entries = num2cell(rawArray(:)');
    elseif iscell(rawArray)
        entries = rawArray(:)';
    else
        entries = {};
    end
end

function tf = isMajorVersion(value)
    tf = isnumeric(value) && isscalar(value) && value >= 0 && value == round(value);
end

function tf = isOptionPath(value)
    tf = ischar(value) && ~isempty(regexp(value, '^[A-Za-z]\w*(\.[A-Za-z]\w*)*$', "once"));
end
