function [declared, issues] = parseDeclaration(declaration)
%parseDeclaration Parse a property declaration in the syntax of an arguments block.
%
%   [declared, issues] = optionspec.internal.parseDeclaration(declaration)
%   parses text such as '(1,3) double {mustBeInteger, mustBePositive}'
%   and returns a struct with the fields Shape ("scalar", "vector" or
%   "matrix"), Count (elements of a vector or columns of a matrix, 0 if
%   any), RowCount (rows of a matrix, 0 if any), ElementType ("number",
%   "integer", "boolean", "string" or "" if no class is given), IsInteger,
%   IsFinite, Minimum, Maximum, ExclusiveMinimum, ExclusiveMaximum and
%   Enum. issues lists what could not be parsed.
%
%   Sizes: (1,1) is a scalar, (1,N), (N,1), (1,:) and (:,1) a vector and
%   (M,N) or (:,:) a matrix. Classes: double, single, the integer classes,
%   logical, char and string; char (1,:) is one text value. Validators:
%   mustBeInteger, mustBeFinite, mustBePositive, mustBeNonnegative,
%   mustBeNegative, mustBeNonpositive, mustBeGreaterThan,
%   mustBeGreaterThanOrEqual, mustBeLessThan, mustBeLessThanOrEqual,
%   mustBeInRange (inclusive bounds) and mustBeMember.

    arguments
        declaration {mustBeTextScalar}
    end

    declared = struct("Shape", "scalar", "Count", 0, "RowCount", 0, "ElementType", "", ...
        "IsInteger", false, "IsFinite", false, "Minimum", [], "Maximum", [], ...
        "ExclusiveMinimum", [], "ExclusiveMaximum", [], "Enum", {{}});
    issues = strings(1, 0);

    % Named tokens, because an optional group that does not match leaves no
    % unnamed token. A named token inside another group is not returned, so
    % the validators token includes its braces.
    tokens = regexp(char(declaration), ['^\s*\(\s*(?<rows>\d+|:)\s*,\s*(?<columns>\d+|:)\s*\)' ...
        '\s*(?<className>[A-Za-z]\w*)?\s*(?<validators>\{.*\})?\s*$'], "names", "once");
    if isempty(tokens)
        issues(end+1) = sprintf("declaration ""%s"" must have the form ""(rows,columns) class {validators}"".", ...
            declaration);
        return
    end
    rowText = tokens.rows;
    columnText = tokens.columns;
    className = tokens.className;
    validatorText = regexprep(tokens.validators, '^\{|\}$', '');

    rows = sizeValue(rowText);
    columns = sizeValue(columnText);
    isTextClass = any(strcmp(className, {'char'}));
    if (rows == 1 && columns == 1) || (isTextClass && rows == 1)
        declared.Shape = "scalar";
    elseif rows == 1 || columns == 1
        declared.Shape = "vector";
        if rows == 1
            declared.Count = columns;
        else
            declared.Count = rows;
        end
    else
        declared.Shape = "matrix";
        declared.RowCount = rows;
        declared.Count = columns;
    end

    switch className
        case ""
            declared.ElementType = "";
        case {'double', 'single'}
            declared.ElementType = "number";
        case {'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
            declared.ElementType = "integer";
            declared.IsInteger = true;
        case 'logical'
            declared.ElementType = "boolean";
        case {'char', 'string'}
            declared.ElementType = "string";
        otherwise
            issues(end+1) = sprintf("class ""%s"" is not supported; use double, single, an integer class, logical, char or string.", ...
                className);
    end

    for validator = splitTopLevel(validatorText)
        [declared, validatorIssues] = applyValidator(declared, validator);
        issues = [issues, validatorIssues]; %#ok<AGROW>
    end
end

function value = sizeValue(text)
% 0 stands for any size
    if strcmp(text, ':')
        value = 0;
    else
        value = str2double(text);
    end
end

function [declared, issues] = applyValidator(declared, validator)
    issues = strings(1, 0);
    tokens = regexp(validator, '^(?<name>\w+)\s*(?<arguments>\(.*\))?$', "names", "once");
    if isempty(tokens)
        issues(end+1) = sprintf("validator ""%s"" cannot be parsed.", validator);
        return
    end
    name = tokens.name;
    argumentText = regexprep(tokens.arguments, '^\(|\)$', '');
    validatorArguments = splitTopLevel(argumentText);
    % The first argument is the property name and is not needed
    bounds = str2double(validatorArguments(2:end));

    switch name
        case "mustBeInteger"
            declared.IsInteger = true;
        case "mustBeFinite"
            declared.IsFinite = true;
        case "mustBePositive"
            declared.ExclusiveMinimum = 0;
        case "mustBeNonnegative"
            declared.Minimum = 0;
        case "mustBeNegative"
            declared.ExclusiveMaximum = 0;
        case "mustBeNonpositive"
            declared.Maximum = 0;
        case "mustBeGreaterThan"
            [declared.ExclusiveMinimum, issues] = oneBound(bounds, validator);
        case "mustBeGreaterThanOrEqual"
            [declared.Minimum, issues] = oneBound(bounds, validator);
        case "mustBeLessThan"
            [declared.ExclusiveMaximum, issues] = oneBound(bounds, validator);
        case "mustBeLessThanOrEqual"
            [declared.Maximum, issues] = oneBound(bounds, validator);
        case "mustBeInRange"
            if numel(bounds) ~= 2 || any(isnan(bounds))
                issues(end+1) = sprintf("validator ""%s"" needs two numeric bounds; only inclusive bounds are supported.", ...
                    validator);
            else
                declared.Minimum = bounds(1);
                declared.Maximum = bounds(2);
            end
        case "mustBeMember"
            [declared.Enum, issues] = memberList(strjoin(validatorArguments(2:end), ","), validator);
        otherwise
            issues(end+1) = sprintf("validator ""%s"" is not supported.", name);
    end
end

function [bound, issues] = oneBound(bounds, validator)
    issues = strings(1, 0);
    bound = [];
    if isscalar(bounds) && ~isnan(bounds)
        bound = bounds;
    else
        issues(end+1) = sprintf("validator ""%s"" needs one numeric bound.", validator);
    end
end

function [enumValues, issues] = memberList(text, validator)
% A list of text in [] or {} with single or double quotes, or of numbers in []
    issues = strings(1, 0);
    enumValues = {};
    text = strtrim(text);
    quoted = regexp(text, '"([^"]*)"|''([^'']*)''', "tokens");
    if ~isempty(quoted)
        enumValues = cellfun(@(token) token{1}, quoted, "UniformOutput", false);
    else
        numbers = str2double(split(strtrim(regexprep(text, '[\[\]{},]', ' ')))');
        if isempty(numbers) || any(isnan(numbers))
            issues(end+1) = sprintf("validator ""%s"" needs a list of text or numbers.", validator);
        else
            enumValues = num2cell(numbers);
        end
    end
end

function parts = splitTopLevel(text)
% Split at commas that are not inside (), [] or {}
    parts = strings(1, 0);
    depth = 0;
    current = "";
    for character = char(text)
        if any(character == '([{')
            depth = depth + 1;
        elseif any(character == ')]}')
            depth = depth - 1;
        end
        if character == ',' && depth == 0
            parts(end+1) = strtrim(current); %#ok<AGROW>
            current = "";
        else
            current = current + character;
        end
    end
    if strtrim(current) ~= ""
        parts(end+1) = strtrim(current);
    end
end
