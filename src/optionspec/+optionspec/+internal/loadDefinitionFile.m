function [rootNode, header] = loadDefinitionFile(filePath, includingFiles)
%loadDefinitionFile Read a definition file and check it against the optionspec profile.
%
%   [rootNode, header] = optionspec.internal.loadDefinitionFile(filePath)
%   returns the finalized root node of the definition, a group whose
%   properties are the options, and a struct header with the fields Id,
%   Version, Title, Description and Includes. Every problem found is
%   listed in one OPTIONSPEC:InvalidDefinition error.
%
%   A definition includes other definitions with
%   "allOf": [{"$ref": "<file>"}, ...], where each file is resolved
%   relative to the folder of the including file. The included options
%   are added after the options of the including definition. The
%   including definition may redeclare an included option to change its
%   default, title, description or "x-ui", or to narrow it: a subset of
%   "enum" and "x-nonfinite", a higher minimum, a lower maximum, a higher
%   "minItems" and a lower "maxItems". Changing its type is an error, as
%   is an option declared by two included definitions. header.Includes
%   lists every included definition as "<id>@<version>".
%
%   loadDefinitionFile(filePath, includingFiles) is the recursive call for
%   an included file; includingFiles lists the files that include it, to
%   detect circular references.

    arguments
        filePath (1,1) string
        includingFiles (1,:) string = strings(1, 0)
    end

    rawDefinition = optionspec.internal.readJsonFile(filePath);
    [rawRoot, header, includeFiles, issues] = readTopLevel(rawDefinition, filePath);

    rootNode = optionspec.internal.emptyNode();
    if isempty(issues)
        [rootNode, issues] = optionspec.internal.canonicalizeNode(rawRoot, "");
    end

    includedNodes = {};
    for includeFile = includeFiles
        if any(includeFile == [includingFiles, filePath])
            issues(end+1) = sprintf("""$ref"" to ""%s"" is circular.", includeFile); %#ok<AGROW>
        elseif ~isfile(includeFile)
            issues(end+1) = sprintf("""$ref"" file ""%s"" does not exist.", includeFile); %#ok<AGROW>
        else
            [includedNodes{end+1}, includedHeader] = optionspec.internal.loadDefinitionFile( ...
                includeFile, [includingFiles, filePath]); %#ok<AGROW>
            header.Includes = [header.Includes, ...
                includedHeader.Id + "@" + includedHeader.Version, includedHeader.Includes];
        end
    end

    if isempty(issues) && ~isempty(includedNodes)
        [rootNode, issues] = composeNodes(rootNode, includedNodes, includeFiles);
    end
    if isempty(issues)
        [rootNode, issues] = optionspec.internal.finalizeNode(rootNode, "");
    end
    if isempty(issues) && ~isempty(includedNodes)
        for i = 1:numel(includedNodes)
            issues = [issues, checkNarrowing(rootNode, includedNodes{i}, "")]; %#ok<AGROW>
        end
    end
    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:InvalidDefinition", ...
            sprintf("Definition file ""%s"" is not valid:", filePath), issues)
    end
end

function [rootNode, issues] = composeNodes(ownNode, includedNodes, includeFiles)
% Combine the included definitions, then lay the own options over them.
    issues = strings(1, 0);
    baseNode = includedNodes{1};
    for i = 2:numel(includedNodes)
        for name = string(fieldnames(includedNodes{i}.Properties))'
            if isfield(baseNode.Properties, name)
                issues(end+1) = sprintf("%s: declared by more than one included definition (%s).", ...
                    name, strjoin(includeFiles, ", ")); %#ok<AGROW>
            else
                baseNode.Properties.(name) = includedNodes{i}.Properties.(name);
            end
        end
    end
    [rootNode, mergeIssues] = mergeNode(baseNode, ownNode, "");
    issues = [issues, mergeIssues];
end

function [node, issues] = mergeNode(baseNode, ownNode, path)
% Lay the keywords set in ownNode over baseNode. Groups merge option by
% option, with the own options first.
    issues = strings(1, 0);
    node = baseNode;
    if ownNode.Type ~= "" && (ownNode.Type ~= baseNode.Type || ownNode.Nullable ~= baseNode.Nullable)
        issues(end+1) = sprintf("%s: an included option cannot change its type.", displayPath(path));
        return
    end

    for field = ["Title", "Description", "Format"]
        if ownNode.(field) ~= ""
            node.(field) = ownNode.(field);
        end
    end
    if ownNode.HasDefault
        node.HasDefault = true;
        node.Default = ownNode.Default;
    end
    for field = ["Enum", "Minimum", "Maximum", "ExclusiveMinimum", "ExclusiveMaximum", ...
            "MinItems", "MaxItems", "UI", "NonFinite"]
        if ~isempty(ownNode.(field))
            node.(field) = ownNode.(field);
        end
    end
    if ~isempty(ownNode.Items)
        [node.Items, itemIssues] = mergeNode(baseNode.Items, ownNode.Items, path + "(:)");
        issues = [issues, itemIssues];
    end

    if ~isempty(ownNode.Properties)
        mergedProperties = struct();
        for name = string(fieldnames(ownNode.Properties))'
            optionPath = optionspec.internal.joinPath(path, name);
            if isfield(baseNode.Properties, name)
                [mergedProperties.(name), optionIssues] = mergeNode( ...
                    baseNode.Properties.(name), ownNode.Properties.(name), optionPath);
                issues = [issues, optionIssues]; %#ok<AGROW>
            else
                mergedProperties.(name) = ownNode.Properties.(name);
            end
        end
        for name = string(fieldnames(baseNode.Properties))'
            if ~isfield(mergedProperties, name)
                mergedProperties.(name) = baseNode.Properties.(name);
            end
        end
        node.Properties = mergedProperties;
    end
end

function issues = checkNarrowing(node, baseNode, path)
% Check that a composed node accepts no value that the included node rejects.
    issues = strings(1, 0);
    label = displayPath(path);
    if ~isempty(baseNode.Enum)
        isIncluded = cellfun(@(value) any(cellfun(@(baseValue) isequal(baseValue, value), ...
            baseNode.Enum)), node.Enum);
        if ~all(isIncluded)
            issues(end+1) = label + ": ""enum"" can only remove values of the included option.";
        end
    end
    lowerBounds = ["Minimum", "ExclusiveMinimum", "MinItems"];
    upperBounds = ["Maximum", "ExclusiveMaximum", "MaxItems"];
    for field = [lowerBounds, upperBounds]
        if ~isempty(baseNode.(field))
            isLowerBound = any(field == lowerBounds);
            isWider = node.(field) < baseNode.(field);
            if ~isLowerBound
                isWider = node.(field) > baseNode.(field);
            end
            if isWider
                issues(end+1) = sprintf("%s: ""%s"" cannot widen the range of the included option.", ...
                    label, lowerFirst(field)); %#ok<AGROW>
            end
        end
    end
    if ~all(ismember(node.NonFinite, baseNode.NonFinite))
        issues(end+1) = label + ": ""x-nonfinite"" can only remove values of the included option.";
    end
    if node.Format ~= baseNode.Format
        issues(end+1) = label + ": ""format"" of an included option cannot change.";
    end
    if ~isempty(baseNode.Items)
        issues = [issues, checkNarrowing(node.Items, baseNode.Items, path + "(:)")];
    end
    if ~isempty(baseNode.Properties)
        for name = string(fieldnames(baseNode.Properties))'
            issues = [issues, checkNarrowing(node.Properties.(name), baseNode.Properties.(name), ...
                optionspec.internal.joinPath(path, name))]; %#ok<AGROW>
        end
    end
end

function text = lowerFirst(text)
    text = lower(extractBefore(text, 2)) + extractAfter(text, 1);
end

function path = displayPath(path)
    if path == ""
        path = "(definition)";
    end
end

function [rawRoot, header, includeFiles, issues] = readTopLevel(rawDefinition, filePath)
    issues = strings(1, 0);
    header = struct("Id", "", "Version", "", "Title", "", "Description", "", ...
        "Includes", strings(1, 0));
    includeFiles = strings(1, 0);
    rawRoot = struct("type", "object", "properties", struct());

    if ~(isstruct(rawDefinition) && isscalar(rawDefinition))
        issues(end+1) = "A definition must be a JSON object.";
        return
    end

    allowedKeywords = ["x_schema", "x_id", "x_version", "x_comment", "title", ...
        "description", "type", "properties", "allOf", "additionalProperties", "unevaluatedProperties"];
    for keyword = setdiff(string(fieldnames(rawDefinition))', allowedKeywords, "stable")
        issues(end+1) = sprintf("Top-level keyword ""%s"" is not part of the optionspec profile.", ...
            optionspec.internal.displayKeyword(keyword)); %#ok<AGROW>
    end

    schemaUri = "https://json-schema.org/draft/2020-12/schema";
    if isfield(rawDefinition, "x_schema") && ~isequal(string(rawDefinition.x_schema), schemaUri)
        issues(end+1) = sprintf("""$schema"" must be ""%s"".", schemaUri);
    end

    if isfield(rawDefinition, "x_id") && isTextScalar(rawDefinition.x_id) ...
            && ~isempty(regexp(rawDefinition.x_id, '^\S+$', "once"))
        header.Id = string(rawDefinition.x_id);
    else
        issues(end+1) = """$id"" is missing or not a string without spaces.";
    end

    if isfield(rawDefinition, "x_version") && isVersion(rawDefinition.x_version)
        header.Version = string(rawDefinition.x_version);
    else
        issues(end+1) = """x-version"" is missing or not of the form MAJOR.MINOR.PATCH.";
    end

    for keyword = ["title", "description"]
        if isfield(rawDefinition, keyword)
            if isTextScalar(rawDefinition.(keyword))
                header.(upper(extractBefore(keyword, 2)) + extractAfter(keyword, 1)) = ...
                    string(rawDefinition.(keyword));
            else
                issues(end+1) = sprintf("""%s"" must be a string.", keyword); %#ok<AGROW>
            end
        end
    end

    if ~isfield(rawDefinition, "type") || ~isequal(rawDefinition.type, 'object')
        issues(end+1) = """type"" must be ""object"".";
    end
    for keyword = ["additionalProperties", "unevaluatedProperties"]
        if isfield(rawDefinition, keyword) && ~isequal(rawDefinition.(keyword), false)
            issues(end+1) = sprintf("""%s"" can only be false; unknown options are always rejected.", ...
                keyword); %#ok<AGROW>
        end
    end

    if isfield(rawDefinition, "allOf")
        [includeFiles, includeIssues] = readIncludes(rawDefinition.allOf, filePath);
        issues = [issues, includeIssues];
    end

    if isfield(rawDefinition, "properties")
        rawRoot.properties = rawDefinition.properties;
    elseif ~isfield(rawDefinition, "allOf")
        issues(end+1) = """properties"" is missing.";
    end
end

function [includeFiles, issues] = readIncludes(rawAllOf, filePath)
% "allOf" holds only references: [{"$ref": "<file>"}, ...]. jsondecode
% returns an array of objects as a struct array, or as a cell array when
% the objects have different keys.
    includeFiles = strings(1, 0);
    issues = strings(1, 0);
    if isstruct(rawAllOf)
        entries = num2cell(rawAllOf(:)');
    elseif iscell(rawAllOf)
        entries = rawAllOf(:)';
    else
        entries = {};
    end
    isReference = @(entry) isstruct(entry) && isscalar(entry) ...
        && isequal(fieldnames(entry), {'x_ref'}) && isTextScalar(entry.x_ref);
    if isempty(entries) || ~all(cellfun(isReference, entries))
        issues(end+1) = """allOf"" must be a non-empty array of objects of the form {""$ref"": ""<file>""}.";
        return
    end

    definitionFolder = fileparts(filePath);
    for i = 1:numel(entries)
        reference = string(entries{i}.x_ref);
        if isAbsolutePath(reference)
            includeFile = reference;
        else
            includeFile = string(fullfile(definitionFolder, reference));
        end
        includeFiles(end+1) = getCanonicalPath(includeFile); %#ok<AGROW>
    end
end

function tf = isAbsolutePath(path)
    tf = startsWith(path, ["/", "\\"]) || ~isempty(regexp(path, '^[A-Za-z]:[\\/]', "once"));
end

function path = getCanonicalPath(path)
% Resolve "." and ".." so that circular references are detected
    if isfile(path)
        fileInfo = dir(path);
        path = string(fullfile(fileInfo.folder, fileInfo.name));
    end
end

function tf = isTextScalar(value)
    tf = (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value));
end

function tf = isVersion(value)
    try
        optionspec.internal.parseVersion(value);
        tf = true;
    catch exception
        if exception.identifier ~= "OPTIONSPEC:InvalidVersion"
            rethrow(exception)
        end
        tf = false;
    end
end
