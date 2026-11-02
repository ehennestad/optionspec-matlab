function [node, issues] = inferNode(options, descriptions, path)
%inferNode Infer a canonical schema node from an options struct.
%
%   [node, issues] = optionspec.internal.inferNode(options, descriptions,
%   path) returns the canonical group node of the struct options, before
%   finalizing (see optionspec.internal.finalizeNode), and a string array
%   of problems. descriptions is a struct of the same shape whose fields
%   hold the description text of options, or struct() for none.
%
%   A field named <name>_ next to a field <name> is a hint for <name>, as
%   in NANSEN option structs, and not an option. See
%   optionspec.inferDefinition for the hints and the inference rules.

    arguments
        options (1,1) struct
        descriptions (1,1) struct
        path (1,1) string
    end

    node = optionspec.internal.emptyNode();
    node.Type = "object";
    node.Properties = struct();
    issues = strings(1, 0);

    fieldNames = string(fieldnames(options))';
    isHint = endsWith(fieldNames, "_") & ismember(extractBefore(fieldNames, strlength(fieldNames)), fieldNames);
    for name = fieldNames(~isHint)
        optionPath = optionspec.internal.joinPath(path, name);
        value = options.(name);
        hint = [];
        if isfield(options, name + "_")
            hint = options.(name + "_");
        end
        description = "";
        childDescriptions = struct();
        if isfield(descriptions, name)
            if isstruct(descriptions.(name))
                childDescriptions = descriptions.(name);
            elseif isTextScalar(descriptions.(name))
                description = string(descriptions.(name));
            end
        end

        if isstruct(value) && isscalar(value)
            [childNode, childIssues] = optionspec.internal.inferNode(value, childDescriptions, optionPath);
            childNode.Description = description;
        else
            [childNode, childIssues] = inferOption(value, hint, optionPath);
            childNode.Description = description;
        end
        node.Properties.(name) = childNode;
        issues = [issues, childIssues]; %#ok<AGROW>
    end
end

function [node, issues] = inferOption(value, hint, path)
    [node, issues] = inferFromValue(value, path);
    if ~isempty(issues)
        return
    end
    [node, issues] = applyHint(node, hint, value, path);
end

function [node, issues] = inferFromValue(value, path)
% Infer type and default from the value alone
    node = optionspec.internal.emptyNode();
    node.HasDefault = true;
    issues = strings(1, 0);

    if isa(value, "double") && isequal(size(value), [0, 0])
        % [] says nothing about the type; a vector of numbers or null
        % accepts what such options usually hold
        node.Type = "array";
        node.Nullable = true;
        node.Items = scalarNode("number");
        node.Items.NonFinite = ["Inf", "-Inf", "NaN"];
        node.Default = [];
    elseif islogical(value) && isscalar(value)
        node.Type = "boolean";
        node.Default = value;
    elseif (isnumeric(value) && isreal(value)) && isscalar(value)
        node.Type = numberType(value);
        node.NonFinite = allowedNonFinite(value);
        node.Default = double(value);
    elseif (isnumeric(value) && isreal(value)) || islogical(value)
        elementNode = scalarNode(numberType(value));
        if islogical(value)
            elementNode = scalarNode("boolean");
        else
            elementNode.NonFinite = allowedNonFinite(value);
        end
        if isvector(value) || isempty(value)
            node.Type = "array";
            node.Items = elementNode;
            node.Default = reshape(double(value), 1, []);
            if islogical(value)
                node.Default = reshape(value, 1, []);
            end
        elseif ismatrix(value)
            node.Type = "array";
            node.Items = scalarNode("array");
            node.Items.Items = elementNode;
            node.Default = double(value);
            if islogical(value)
                node.Default = value;
            end
        else
            issues(end+1) = path + ": cannot infer an option from an array with more than two dimensions.";
        end
    elseif ischar(value) && (isrow(value) || isempty(value))
        node.Type = "string";
        node.Default = value;
    elseif isstring(value) && isscalar(value) && ~ismissing(value)
        node.Type = "string";
        node.Default = char(value);
    elseif (isstring(value) || iscellstr(value)) && (isvector(value) || isempty(value))
        node.Type = "array";
        node.Items = scalarNode("string");
        node.Default = reshape(string(value), 1, []);
        if isempty(value)
            node.Default = strings(1, 0);
        end
    else
        issues(end+1) = sprintf("%s: cannot infer an option from %s. Options hold logical, numeric or text values, or structs.", ...
            path, optionspec.internal.describeValue(value));
    end
end

function [node, issues] = applyHint(node, hint, value, path)
    issues = strings(1, 0);
    if iscell(hint) && ~isempty(hint) && ~isstruct(hint{1})
        [node, issues] = applyDropdown(node, hint, path);
    elseif isstruct(hint) && isscalar(hint)
        [node, issues] = applyStructHint(node, hint, value, path);
    elseif isstring(hint) && isscalar(hint) && startsWith(hint, "(")
        % NANSEN's struct editor reads char hints only; a string
        % declaration is accepted here too
        [node, issues] = applyDeclaration(node, char(hint), value, path);
    elseif ischar(hint) && isrow(hint)
        switch hint
            case "uigetdir"
                node.Format = "folder-path";
                node.UI = struct("widget", 'folder');
            case {"uigetfile", "uiputfile"}
                node.Format = "file-path";
                node.UI = struct("widget", 'file');
            case {"internal", "ignore"}
                node.UI = struct("widget", 'hidden');
            otherwise
                if startsWith(hint, "(")
                    [node, issues] = applyDeclaration(node, hint, value, path);
                end
                % Other hints ("vector", "transient", "uisetcolor") only
                % affect how NANSEN shows the option
        end
    end
end

function [node, issues] = applyDropdown(node, items, path)
    issues = strings(1, 0);
    if all(cellfun(@(item) ischar(item) || (isstring(item) && isscalar(item)), items))
        enumValues = cellfun(@char, items, "UniformOutput", false);
    elseif all(cellfun(@(item) isnumeric(item) && isscalar(item), items))
        enumValues = cellfun(@double, items, "UniformOutput", false);
    else
        issues(end+1) = path + ": the dropdown hint mixes text and numbers.";
        return
    end
    enumTarget = node;
    if node.Type == "array"
        enumTarget = node.Items;
    end
    enumTarget.Enum = enumValues(:)';
    if node.Type == "array"
        node.Items = enumTarget;
    else
        node = enumTarget;
        node.UI = struct("widget", 'dropdown');
    end
end

function [node, issues] = applyStructHint(node, hint, value, path)
    issues = strings(1, 0);
    if isfield(hint, "type")
        switch string(hint.type)
            case "slider"
                sliderArguments = {};
                if isfield(hint, "args") && iscell(hint.args)
                    sliderArguments = hint.args;
                end
                minimum = nameValue(sliderArguments, "Min");
                maximum = nameValue(sliderArguments, "Max");
                if ~isempty(minimum)
                    node.Minimum = double(minimum);
                end
                if ~isempty(maximum)
                    node.Maximum = double(maximum);
                end
                node.UI = struct("widget", 'slider');
                units = nameValue(sliderArguments, "TooltipUnits");
                if ~isempty(units)
                    node.UI.units = char(units);
                end
            case {"button", "togglebutton"}
                node.UI = struct("widget", char(hint.type));
            case "multilinechar"
                node.UI = struct("widget", 'multilinetext');
        end
    end
    if isfield(hint, "declaration")
        [node, issues] = applyDeclaration(node, hint.declaration, value, path);
    end
end

function [node, issues] = applyDeclaration(node, declaration, value, path)
% Apply a declaration in the syntax of an arguments block, such as
% '(1,3) double {mustBeInteger, mustBePositive}'
    issues = strings(1, 0);
    [declared, parseIssues] = optionspec.internal.parseDeclaration(declaration);
    if ~isempty(parseIssues)
        issues = path + ": " + parseIssues;
        return
    end

    elementType = declared.ElementType;
    if elementType == ""
        elementType = baseElementType(node);
    end
    if declared.IsInteger
        if ~any(elementType == ["number", "integer"])
            issues(end+1) = path + ": mustBeInteger needs a numeric option.";
            return
        end
        elementType = "integer";
    end

    isNull = isa(value, "double") && isequal(size(value), [0, 0]);
    defaultValue = node.Default;
    enumValues = baseEnum(node);
    switch declared.Shape
        case "scalar"
            newNode = scalarNode(elementType);
            newNode.Nullable = isNull;
            if elementType == "string" && ~isNull
                defaultValue = char(value);
            end
        case "vector"
            newNode = scalarNode("array");
            newNode.Items = scalarNode(elementType);
            if declared.Count > 0
                newNode.MinItems = declared.Count;
                newNode.MaxItems = declared.Count;
            end
            % [] for a vector of fixed length means "not set"
            newNode.Nullable = isNull && declared.Count > 0;
            if isNull && ~newNode.Nullable
                defaultValue = emptyVector(elementType);
            elseif ~isNull && elementType == "string"
                defaultValue = reshape(string(value), 1, []);
            end
        case "matrix"
            newNode = scalarNode("array");
            newNode.Items = scalarNode("array");
            newNode.Items.Items = scalarNode(elementType);
            if declared.RowCount > 0
                newNode.MinItems = declared.RowCount;
                newNode.MaxItems = declared.RowCount;
            end
            if declared.Count > 0
                newNode.Items.MinItems = declared.Count;
                newNode.Items.MaxItems = declared.Count;
            end
            newNode.Nullable = isNull && (declared.RowCount > 0 || declared.Count > 0);
            if isNull && ~newNode.Nullable
                defaultValue = zeros(0, 0);
            end
    end
    newNode.HasDefault = true;
    newNode.Default = defaultValue;
    newNode.UI = node.UI;
    newNode.Format = node.Format;

    elementNode = newNode;
    if newNode.Type == "array"
        elementNode = newNode.Items;
        if elementNode.Type == "array"
            elementNode = elementNode.Items;
        end
    end
    elementNode.Enum = enumValues;
    if ~isempty(declared.Enum)
        elementNode.Enum = declared.Enum;
    end
    if any(elementType == ["number", "integer"])
        elementNode.Minimum = firstNonEmpty(declared.Minimum, baseField(node, "Minimum"));
        elementNode.Maximum = firstNonEmpty(declared.Maximum, baseField(node, "Maximum"));
        elementNode.ExclusiveMinimum = declared.ExclusiveMinimum;
        elementNode.ExclusiveMaximum = declared.ExclusiveMaximum;
        % As in an arguments block, a number may be Inf or NaN unless a
        % validator rules it out
        if ~(declared.IsFinite || declared.IsInteger)
            elementNode.NonFinite = ["Inf", "-Inf", "NaN"];
        end
    end
    newNode = setElementNode(newNode, elementNode);
    node = newNode;
end

function node = setElementNode(node, elementNode)
    if node.Type ~= "array"
        elementNode.HasDefault = node.HasDefault;
        elementNode.Default = node.Default;
        elementNode.Nullable = node.Nullable;
        elementNode.UI = node.UI;
        elementNode.Format = node.Format;
        node = elementNode;
    elseif node.Items.Type == "array"
        node.Items.Items = elementNode;
    else
        node.Items = elementNode;
    end
end

function elementType = baseElementType(node)
    if node.Type == "array" && node.Items.Type == "array"
        elementType = node.Items.Items.Type;
    elseif node.Type == "array"
        elementType = node.Items.Type;
    else
        elementType = node.Type;
    end
end

function enumValues = baseEnum(node)
    if node.Type == "array" && node.Items.Type == "array"
        enumValues = node.Items.Items.Enum;
    elseif node.Type == "array"
        enumValues = node.Items.Enum;
    else
        enumValues = node.Enum;
    end
end

function value = baseField(node, field)
    if node.Type == "array"
        value = [];
    else
        value = node.(field);
    end
end

function value = firstNonEmpty(first, second)
    value = first;
    if isempty(value)
        value = second;
    end
end

function value = emptyVector(elementType)
    switch elementType
        case "string"
            value = strings(1, 0);
        case "boolean"
            value = false(1, 0);
        otherwise
            value = zeros(1, 0);
    end
end

function node = scalarNode(type)
    node = optionspec.internal.emptyNode();
    node.Type = type;
end

function type = numberType(value)
    if isinteger(value)
        type = "integer";
    else
        type = "number";
    end
end

function labels = allowedNonFinite(value)
% A double field of a struct holds Inf and NaN as well as other numbers, so
% an inferred number allows them, as a declared double does unless
% mustBeFinite rules them out. Inferring them from the default would make
% a change of the default from Inf to a number a major version change.
    if isinteger(value)
        labels = strings(1, 0);
    else
        labels = ["Inf", "-Inf", "NaN"];
    end
end

function value = nameValue(nameValuePairs, name)
    value = [];
    for i = 1:2:numel(nameValuePairs)-1
        if (ischar(nameValuePairs{i}) || isstring(nameValuePairs{i})) && strcmpi(nameValuePairs{i}, name)
            value = nameValuePairs{i+1};
        end
    end
end

function tf = isTextScalar(value)
    tf = (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value));
end
