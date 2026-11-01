function [value, issues] = normalizeValue(value, node, path)
%normalizeValue Check a value against a schema node and convert it to its canonical form.
%
%   [value, issues] = optionspec.internal.normalizeValue(value, node, path)
%   returns value in the form optionspec uses in MATLAB, and a string array
%   of problems, each prefixed with path. The value is valid if issues is
%   empty.
%
%   Canonical forms, by schema type:
%     null      [] (a 0x0 double). Accepted only when "null" is in the type.
%     boolean   logical scalar.
%     integer   double scalar with an integer value.
%     number    double scalar. Numeric scalars of other classes are
%               converted. The text "Inf", "-Inf" and "NaN" becomes the
%               double if the node lists it in x-nonfinite.
%     string    char row vector ('' when empty). String scalars are converted.
%     array     row vector: double for integer and number items, logical
%               for boolean items, string array for string items. Column
%               vectors and cell arrays (as jsondecode returns) are
%               converted. With array items, a matrix whose rows are the
%               inner arrays.
%     object    scalar struct whose fields are the options of the group,
%               in the order of the schema.

    arguments
        value
        node (1,1) struct
        path (1,1) string
    end

    if node.Nullable && isNull(value)
        value = [];
        issues = strings(1, 0);
        return
    end

    switch node.Type
        case "object"
            [value, issues] = normalizeGroup(value, node, path);
        case "array"
            if node.Items.Type == "array"
                [value, issues] = normalizeMatrix(value, node, path);
            else
                [value, issues] = normalizeVector(value, node, path);
            end
        case {"boolean", "integer", "number", "string"}
            [value, issues] = normalizeScalar(value, node, path);
        otherwise
            error("OPTIONSPEC:InvalidNode", "Schema node at %s has no valid type.", path)
    end
end

function [value, issues] = normalizeGroup(value, node, path)
    issues = strings(1, 0);
    if ~(isstruct(value) && isscalar(value))
        issues(end+1) = sprintf("%s: expected a group of options (a scalar struct), found %s.", ...
            displayPath(path), optionspec.internal.describeValue(value));
        return
    end

    optionNames = string(fieldnames(node.Properties))';
    givenNames = string(fieldnames(value))';
    for name = setdiff(givenNames, optionNames, "stable")
        issues(end+1) = sprintf("%s: unknown option.", optionspec.internal.joinPath(path, name)); %#ok<AGROW>
    end

    normalizedGroup = struct();
    for name = optionNames
        optionPath = optionspec.internal.joinPath(path, name);
        if isfield(value, name)
            [normalizedGroup.(name), optionIssues] = optionspec.internal.normalizeValue( ...
                value.(name), node.Properties.(name), optionPath);
            issues = [issues, optionIssues]; %#ok<AGROW>
        else
            issues(end+1) = optionPath + ": missing option."; %#ok<AGROW>
        end
    end
    value = normalizedGroup;
end

function [value, issues] = normalizeVector(value, node, path)
    issues = strings(1, 0);
    [elements, isVector] = toElementCell(value);
    if ~isVector
        issues(end+1) = sprintf("%s: expected a vector, found %s.", ...
            path, optionspec.internal.describeValue(value));
        return
    end

    for i = 1:numel(elements)
        [elements{i}, elementIssues] = optionspec.internal.normalizeValue( ...
            elements{i}, node.Items, sprintf("%s(%d)", path, i));
        issues = [issues, elementIssues]; %#ok<AGROW>
    end
    if ~isempty(issues)
        return
    end

    switch node.Items.Type
        case "string"
            value = string(elements);
            if isempty(elements)
                value = strings(1, 0);
            end
        case "boolean"
            value = [false(1, 0), elements{:}];
        otherwise
            value = [zeros(1, 0), elements{:}];
    end
    issues = checkItemCount(numel(elements), node, path, "elements");
end

function [value, issues] = normalizeMatrix(value, node, path)
    issues = strings(1, 0);
    if (isnumeric(value) || islogical(value)) && ismatrix(value)
        rows = num2cell(value, 2)';
        if isempty(value)
            rows = {};
        end
    elseif iscell(value) && (isvector(value) || isempty(value))
        rows = value(:)';
    else
        issues(end+1) = sprintf("%s: expected a matrix, found %s.", ...
            path, optionspec.internal.describeValue(value));
        return
    end

    for i = 1:numel(rows)
        [rows{i}, rowIssues] = optionspec.internal.normalizeValue( ...
            rows{i}, node.Items, sprintf("%s(%d,:)", path, i));
        issues = [issues, rowIssues]; %#ok<AGROW>
    end
    if ~isempty(issues)
        return
    end

    rowLengths = cellfun(@numel, rows);
    if ~isempty(rows) && any(rowLengths ~= rowLengths(1))
        issues(end+1) = path + ": rows have different numbers of elements.";
        return
    end
    if isempty(rows)
        if node.Items.Items.Type == "boolean"
            value = false(0, 0);
        else
            value = zeros(0, 0);
        end
    else
        value = vertcat(rows{:});
    end
    issues = checkItemCount(numel(rows), node, path, "rows");
end

function [value, issues] = normalizeScalar(value, node, path)
    issues = strings(1, 0);
    switch node.Type
        case "boolean"
            if ~(islogical(value) && isscalar(value))
                issues(end+1) = sprintf("%s: expected true or false, found %s.", ...
                    path, optionspec.internal.describeValue(value));
            end

        case {"integer", "number"}
            [value, issues] = normalizeNumber(value, node, path);

        case "string"
            if isstring(value) && isscalar(value) && ~ismissing(value)
                value = char(value);
            elseif ~(ischar(value) && (isrow(value) || isequal(size(value), [0, 0])))
                issues(end+1) = sprintf("%s: expected text, found %s.", ...
                    path, optionspec.internal.describeValue(value));
            end
    end

    if isempty(issues) && ~isempty(node.Enum) && ~isInEnum(value, node.Enum)
        enumText = strjoin(cellfun(@optionspec.internal.describeValue, node.Enum), ", ");
        issues(end+1) = sprintf("%s: %s is not one of %s.", ...
            path, optionspec.internal.describeValue(value), enumText);
    end
end

function [value, issues] = normalizeNumber(value, node, path)
    issues = strings(1, 0);
    nonFiniteText = ["Inf", "-Inf", "NaN"];
    if (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value))
        if ~any(string(value) == nonFiniteText)
            issues(end+1) = sprintf("%s: expected a number, found %s.", ...
                path, optionspec.internal.describeValue(value));
            return
        end
        value = str2double(value);
    elseif isnumeric(value) && isscalar(value) && isreal(value)
        value = double(value);
    else
        issues(end+1) = sprintf("%s: expected a number, found %s.", ...
            path, optionspec.internal.describeValue(value));
        return
    end

    if ~isfinite(value)
        valueText = optionspec.internal.describeValue(value);
        if ~any(valueText == node.NonFinite)
            issues(end+1) = sprintf("%s: %s is not allowed. List it in ""x-nonfinite"" to allow it.", ...
                path, valueText);
        end
        if isnan(value)
            % NaN is outside every range, so range checks do not apply
            return
        end
    elseif node.Type == "integer" && value ~= round(value)
        issues(end+1) = sprintf("%s: expected an integer, found %s.", path, optionspec.internal.describeValue(value));
    end

    if ~isempty(node.Minimum) && value < node.Minimum
        issues(end+1) = sprintf("%s: %s is less than the minimum %s.", ...
            path, optionspec.internal.describeValue(value), optionspec.internal.describeValue(node.Minimum));
    end
    if ~isempty(node.Maximum) && value > node.Maximum
        issues(end+1) = sprintf("%s: %s is greater than the maximum %s.", ...
            path, optionspec.internal.describeValue(value), optionspec.internal.describeValue(node.Maximum));
    end
    if ~isempty(node.ExclusiveMinimum) && value <= node.ExclusiveMinimum
        issues(end+1) = sprintf("%s: %s must be greater than %s.", ...
            path, optionspec.internal.describeValue(value), optionspec.internal.describeValue(node.ExclusiveMinimum));
    end
    if ~isempty(node.ExclusiveMaximum) && value >= node.ExclusiveMaximum
        issues(end+1) = sprintf("%s: %s must be less than %s.", ...
            path, optionspec.internal.describeValue(value), optionspec.internal.describeValue(node.ExclusiveMaximum));
    end
end

function [elements, isVector] = toElementCell(value)
% Return the elements of a vector as a cell row. Text (a char row or a
% string scalar) is one value, not a vector of elements.
    elements = {};
    isVector = true;
    if isNull(value) || (iscell(value) && isempty(value)) ...
            || ((isnumeric(value) || islogical(value) || isstring(value)) && isempty(value))
        return
    elseif iscell(value) && isvector(value)
        elements = value(:)';
    elseif (isnumeric(value) || islogical(value)) && isvector(value)
        elements = num2cell(value(:)');
    elseif isstring(value) && isvector(value) && ~isscalar(value)
        elements = cellstr(value(:)');
    elseif isstring(value) && isscalar(value)
        % A string scalar is accepted as a one-element string array
        elements = {char(value)};
    else
        isVector = false;
    end
end

function issues = checkItemCount(count, node, path, itemName)
    issues = strings(1, 0);
    if ~isempty(node.MinItems) && count < node.MinItems
        issues(end+1) = sprintf("%s: expected at least %d %s, found %d.", ...
            path, node.MinItems, itemName, count);
    end
    if ~isempty(node.MaxItems) && count > node.MaxItems
        issues(end+1) = sprintf("%s: expected at most %d %s, found %d.", ...
            path, node.MaxItems, itemName, count);
    end
end

function tf = isInEnum(value, enumValues)
    if ischar(value)
        tf = any(cellfun(@(enumValue) ischar(enumValue) && strcmp(enumValue, value), enumValues));
    else
        tf = any(cellfun(@(enumValue) isequal(enumValue, value), enumValues));
    end
end

function tf = isNull(value)
% jsondecode returns null and [] as a 0x0 double
    tf = isa(value, "double") && isequal(size(value), [0, 0]);
end

function path = displayPath(path)
    if path == ""
        path = "(values)";
    end
end
