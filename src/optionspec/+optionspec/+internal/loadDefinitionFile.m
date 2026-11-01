function [rootNode, header] = loadDefinitionFile(filePath)
%loadDefinitionFile Read a definition file and check it against the optionspec profile.
%
%   [rootNode, header] = optionspec.internal.loadDefinitionFile(filePath)
%   returns the finalized root node of the definition, a group whose
%   properties are the options, and a struct header with the fields Id,
%   Version, Title and Description. Every problem found is listed in one
%   OPTIONSPEC:InvalidDefinition error.

    arguments
        filePath (1,1) string
    end

    rawDefinition = optionspec.internal.readJsonFile(filePath);
    [rawRoot, header, issues] = readTopLevel(rawDefinition);

    rootNode = optionspec.internal.emptyNode();
    if isempty(issues)
        [rootNode, issues] = optionspec.internal.canonicalizeNode(rawRoot, "");
    end
    if isempty(issues)
        [rootNode, issues] = optionspec.internal.finalizeNode(rootNode, "");
    end
    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:InvalidDefinition", ...
            sprintf("Definition file ""%s"" is not valid:", filePath), issues)
    end
end

function [rawRoot, header, issues] = readTopLevel(rawDefinition)
    issues = strings(1, 0);
    header = struct("Id", "", "Version", "", "Title", "", "Description", "");
    rawRoot = struct("type", "object", "properties", struct());

    if ~(isstruct(rawDefinition) && isscalar(rawDefinition))
        issues(end+1) = "A definition must be a JSON object.";
        return
    end

    allowedKeywords = ["x_schema", "x_id", "x_version", "x_comment", "title", ...
        "description", "type", "properties", "additionalProperties", "unevaluatedProperties"];
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

    if isfield(rawDefinition, "properties")
        rawRoot.properties = rawDefinition.properties;
    else
        issues(end+1) = """properties"" is missing.";
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
