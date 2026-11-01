function [node, issues] = canonicalizeNode(rawNode, path)
%canonicalizeNode Convert a decoded option schema into a canonical node.
%
%   [node, issues] = optionspec.internal.canonicalizeNode(rawNode, path)
%   checks that rawNode, an option schema decoded by jsondecode, uses only
%   keywords of the optionspec profile and that each keyword holds a value
%   of the right JSON type. It returns a node with the fields listed in
%   optionspec.internal.emptyNode, and a string array of problems, each
%   prefixed with path.
%
%   This function checks each keyword on its own. Whether keywords fit the
%   option type, and whether the default is valid, is checked by
%   optionspec.internal.finalizeNode after definitions are composed,
%   because a definition may redeclare an included option partially.

    arguments
        rawNode
        path (1,1) string
    end

    node = optionspec.internal.emptyNode();
    issues = strings(1, 0);

    if ~(isstruct(rawNode) && isscalar(rawNode))
        issues(end+1) = path + ": the schema of an option must be a JSON object.";
        return
    end

    allowedKeywords = ["type", "title", "description", "default", "enum", ...
        "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", ...
        "minItems", "maxItems", "items", "properties", "additionalProperties", ...
        "format", "x_ui", "x_nonfinite", "x_comment"];
    keywords = string(fieldnames(rawNode))';
    unknownKeywords = setdiff(keywords, allowedKeywords, "stable");
    for keyword = unknownKeywords
        issues(end+1) = sprintf("%s: keyword ""%s"" is not part of the optionspec profile.", ...
            path, optionspec.internal.displayKeyword(keyword)); %#ok<AGROW>
    end

    if isfield(rawNode, "type")
        [node, issues] = readType(node, issues, rawNode.type, path);
    end
    for keyword = ["title", "description"]
        if isfield(rawNode, keyword)
            if isTextScalar(rawNode.(keyword))
                node.(capitalize(keyword)) = string(rawNode.(keyword));
            else
                issues(end+1) = sprintf("%s: ""%s"" must be a string.", path, keyword); %#ok<AGROW>
            end
        end
    end
    if isfield(rawNode, "default")
        node.HasDefault = true;
        node.Default = rawNode.default;
    end
    if isfield(rawNode, "enum")
        [node, issues] = readEnum(node, issues, rawNode.enum, path);
    end
    for keyword = ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"]
        if isfield(rawNode, keyword)
            value = rawNode.(keyword);
            if isnumeric(value) && isscalar(value)
                node.(capitalize(keyword)) = value;
            else
                issues(end+1) = sprintf("%s: ""%s"" must be a number.", path, keyword); %#ok<AGROW>
            end
        end
    end
    for keyword = ["minItems", "maxItems"]
        if isfield(rawNode, keyword)
            value = rawNode.(keyword);
            if isnumeric(value) && isscalar(value) && value >= 0 && value == round(value)
                node.(capitalize(keyword)) = value;
            else
                issues(end+1) = sprintf("%s: ""%s"" must be a non-negative integer.", ...
                    path, keyword); %#ok<AGROW>
            end
        end
    end
    if isfield(rawNode, "items")
        [node.Items, itemIssues] = optionspec.internal.canonicalizeNode(rawNode.items, path + "(:)");
        issues = [issues, itemIssues];
    end
    if isfield(rawNode, "properties")
        [node, issues] = readProperties(node, issues, rawNode.properties, path);
    end
    if isfield(rawNode, "additionalProperties") && ~isequal(rawNode.additionalProperties, false)
        issues(end+1) = path + ": ""additionalProperties"" can only be false; unknown options are always rejected.";
    end
    if isfield(rawNode, "format")
        allowedFormats = ["folder-path", "file-path"];
        if isTextScalar(rawNode.format) && any(string(rawNode.format) == allowedFormats)
            node.Format = string(rawNode.format);
        else
            issues(end+1) = sprintf("%s: ""format"" must be one of %s.", ...
                path, strjoin("""" + allowedFormats + """", ", "));
        end
    end
    if isfield(rawNode, "x_ui")
        [node, issues] = readUserInterfaceHints(node, issues, rawNode.x_ui, path);
    end
    if isfield(rawNode, "x_nonfinite")
        [node, issues] = readNonFinite(node, issues, rawNode.x_nonfinite, path);
    end
end

function [node, issues] = readType(node, issues, rawType, path)
    allowedTypes = ["boolean", "integer", "number", "string", "array", "object"];
    if isTextScalar(rawType)
        typeNames = string(rawType);
    elseif iscellstr(rawType) %#ok<ISCLSTR> jsondecode returns string arrays as cellstr
        typeNames = string(rawType(:)');
    else
        issues(end+1) = path + ": ""type"" must be a string or an array of strings.";
        return
    end

    isNull = typeNames == "null";
    baseTypes = typeNames(~isNull);
    if numel(baseTypes) ~= 1 || sum(isNull) > 1 || ~any(baseTypes == allowedTypes)
        issues(end+1) = sprintf("%s: ""type"" must name one of %s, optionally together with ""null"".", ...
            path, strjoin("""" + allowedTypes + """", ", "));
        return
    end
    node.Type = baseTypes;
    node.Nullable = any(isNull);
end

function [node, issues] = readEnum(node, issues, rawEnum, path)
    if iscell(rawEnum)
        enumValues = rawEnum(:)';
    elseif (isnumeric(rawEnum) || islogical(rawEnum)) && ~isempty(rawEnum)
        enumValues = num2cell(rawEnum(:)');
    else
        enumValues = {};
    end
    if isempty(enumValues)
        issues(end+1) = path + ": ""enum"" must be a non-empty array.";
    else
        node.Enum = enumValues;
    end
end

function [node, issues] = readProperties(node, issues, rawProperties, path)
    if ~(isstruct(rawProperties) && isscalar(rawProperties))
        issues(end+1) = path + ": ""properties"" must be a JSON object.";
        return
    end
    node.Properties = struct();
    for name = string(fieldnames(rawProperties))'
        [node.Properties.(name), childIssues] = optionspec.internal.canonicalizeNode( ...
            rawProperties.(name), optionspec.internal.joinPath(path, name));
        issues = [issues, childIssues]; %#ok<AGROW>
    end
end

function [node, issues] = readUserInterfaceHints(node, issues, rawHints, path)
    widgets = ["edit", "dropdown", "slider", "checkbox", "button", "togglebutton", ...
        "multilinetext", "folder", "file", "hidden"];
    if ~(isstruct(rawHints) && isscalar(rawHints))
        issues(end+1) = path + ": ""x-ui"" must be a JSON object.";
        return
    end
    unknownKeys = setdiff(string(fieldnames(rawHints))', ["widget", "label", "units", "step"], "stable");
    for key = unknownKeys
        issues(end+1) = sprintf("%s: ""x-ui"" has unknown key ""%s"".", path, key); %#ok<AGROW>
    end
    if ~isfield(rawHints, "widget") || ~isTextScalar(rawHints.widget) ...
            || ~any(string(rawHints.widget) == widgets)
        issues(end+1) = sprintf("%s: ""x-ui"" needs a ""widget"", one of %s.", ...
            path, strjoin("""" + widgets + """", ", "));
    end
    for key = ["label", "units"]
        if isfield(rawHints, key) && ~isTextScalar(rawHints.(key))
            issues(end+1) = sprintf("%s: ""x-ui"" ""%s"" must be a string.", path, key); %#ok<AGROW>
        end
    end
    if isfield(rawHints, "step") && ~(isnumeric(rawHints.step) && isscalar(rawHints.step) ...
            && rawHints.step > 0)
        issues(end+1) = path + ": ""x-ui"" ""step"" must be a positive number.";
    end
    node.UI = rawHints;
end

function [node, issues] = readNonFinite(node, issues, rawNonFinite, path)
    allowedValues = ["Inf", "-Inf", "NaN"];
    isTextArray = iscellstr(rawNonFinite); %#ok<ISCLSTR> jsondecode returns string arrays as cellstr
    if isTextArray && ~isempty(rawNonFinite) && all(ismember(string(rawNonFinite), allowedValues))
        node.NonFinite = unique(string(rawNonFinite(:)'), "stable");
    else
        issues(end+1) = sprintf("%s: ""x-nonfinite"" must be a non-empty array of %s.", ...
            path, strjoin("""" + allowedValues + """", ", "));
    end
end

function tf = isTextScalar(value)
    tf = (ischar(value) && (isrow(value) || isempty(value))) ...
        || (isstring(value) && isscalar(value));
end

function name = capitalize(keyword)
    name = upper(extractBefore(keyword, 2)) + extractAfter(keyword, 1);
end
