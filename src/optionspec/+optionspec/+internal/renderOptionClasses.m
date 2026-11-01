function classFiles = renderOptionClasses(definition, namespace, baseName)
%renderOptionClasses Write the text of the option classes of a definition.
%
%   classFiles = optionspec.internal.renderOptionClasses(definition,
%   namespace, baseName) returns a struct array with the fields ClassName
%   (qualified by namespace), RelativePath (from the output folder, with
%   +namespace folders) and Text. The first element is the class of the
%   definition, named <baseName>Options; each group of options gets a class
%   named <baseName><GroupPath>Options, for example
%   RigidRegistrationStackOptions for the group Stack.
%
%   The classes depend only on MATLAB, not on optionspec, so a toolbox that
%   vendors optionspec under another namespace can keep them as they are.

    arguments
        definition (1,1) optionspec.Definition
        namespace (1,1) string
        baseName (1,1) string
    end

    classFiles = struct("ClassName", {}, "RelativePath", {}, "Text", {});
    [~, definitionFileName, extension] = fileparts(definition.FilePath);
    context = struct( ...
        "Definition", definition, ...
        "DefinitionFile", definitionFileName + extension, ...
        "Namespace", namespace, ...
        "BaseName", baseName);
    classFiles = renderGroup(classFiles, context, definition.Schema, strings(1, 0));

    shortNames = arrayfun(@(file) lastSegment(file.ClassName), classFiles);
    if numel(unique(shortNames)) < numel(shortNames)
        error("OPTIONSPEC:ClassNameConflict", ...
            "Groups of definition ""%s"" give the same class name twice. Rename a group.", definition.Id)
    end
end

function classFiles = renderGroup(classFiles, context, node, groupPath)
% Append the class of a group, followed by the classes of its groups
    insertIndex = numel(classFiles) + 1;
    className = context.BaseName + groupSuffix(groupPath) + "Options";
    if strlength(className) > namelengthmax
        error("OPTIONSPEC:ClassNameTooLong", ...
            "Class name %s is longer than %d characters. Pass a shorter BaseName.", className, namelengthmax)
    end
    qualifiedName = qualify(context.Namespace, className);
    optionNames = string(fieldnames(node.Properties))';
    reservedNames = ["toStruct", "setOptions", "DefinitionId", "DefinitionVersion", className];
    conflicts = intersect(optionNames, reservedNames);
    if ~isempty(conflicts)
        error("OPTIONSPEC:ReservedOptionName", ...
            "Option name ""%s"" is used by the generated class. Rename the option.", conflicts(1))
    end

    isTopLevel = isempty(groupPath);
    lines = classHeader(context, node, className, qualifiedName, groupPath);
    if isTopLevel
        lines = [lines
            "    properties (Constant)"
            "        % DefinitionId - Identifier of the definition this class was generated from"
            "        DefinitionId = """ + context.Definition.Id + """"
            ""
            "        % DefinitionVersion - Version of the definition this class was generated from"
            "        DefinitionVersion = """ + context.Definition.Version + """"
            "    end"
            ""];
    end

    helpers = strings(1, 0);
    propertyLines = strings(0, 1);
    toStructLines = strings(0, 1);
    for name = optionNames
        optionNode = node.Properties.(name);
        if optionNode.Type == "object"
            childGroupPath = [groupPath, name];
            classFiles = renderGroup(classFiles, context, optionNode, childGroupPath);
            groupClassName = qualify(context.Namespace, context.BaseName ...
                + groupSuffix(childGroupPath) + "Options");
            declaration = sprintf("        %s (1,1) %s", name, groupClassName);
            conversion = sprintf("            values.%s = obj.%s.toStruct();", name, name);
            optionHelpers = strings(1, 0);
        else
            [declaration, conversion, optionHelpers] = renderOption(name, optionNode);
        end
        propertyLines = [propertyLines; propertyHelp(name, optionNode); declaration; ""]; %#ok<AGROW>
        toStructLines = [toStructLines; conversion]; %#ok<AGROW>
        helpers = [helpers, optionHelpers]; %#ok<AGROW>
    end
    propertyLines(end) = [];

    if isscalar(optionNames)
        optionList = "            optionNames = """ + optionNames + """;";
    else
        optionList = wrapList("""" + optionNames + """", "            optionNames = [", "];");
    end
    lines = [lines
        "    properties"
        propertyLines
        "    end"
        ""
        "    methods"
        "        function obj = " + className + "(values, nameValues)"
        "            arguments"
        "                values (1,1) struct = struct()"
        "                nameValues.?" + qualifiedName
        "            end"
        ""
        "            obj = obj.setOptions(values);"
        "            obj = obj.setOptions(nameValues);"
        "        end"
        ""
        "        function values = toStruct(obj)"
        "        %toStruct Return the options as a struct in the form optionspec.Definition uses."
        "        %"
        "        %   values = options.toStruct() returns a struct with one field per"
        "        %   option and a nested struct per group, which"
        "        %   optionspec.Definition/writeDocument can save."
        ""
        "            values = struct();"
        toStructLines
        "        end"
        "    end"
        ""
        "    methods (Access = private)"
        "        function obj = setOptions(obj, values)"
        optionList
        "            for name = string(fieldnames(values))'"
        "                if ~any(name == optionNames)"
        "                    error(""OPTIONSPEC:UnknownOption"", ""%s has no option """"%s"""". Options: %s."", ..."
        "                        mfilename(""class""), name, strjoin(optionNames, "", ""))"
        "                end"
        "                obj.(name) = values.(name);"
        "            end"
        "        end"
        "    end"
        "end"];

    lines = [lines; renderHelpers(unique(helpers, "stable"))];
    text = strjoin(lines, newline) + newline;

    namespaceFolders = "";
    if context.Namespace ~= ""
        namespaceFolders = strjoin("+" + split(context.Namespace, ".")', filesep) + filesep;
    end
    classFile = struct("ClassName", qualifiedName, ...
        "RelativePath", namespaceFolders + className + ".m", "Text", text);
    classFiles = [classFiles(1:insertIndex-1), classFile, classFiles(insertIndex:end)];
end

function lines = classHeader(context, node, className, qualifiedName, groupPath)
    if isempty(groupPath)
        summary = node.Title;
        if summary == ""
            summary = context.Definition.Title;
        end
        if summary == ""
            summary = "Options of definition " + context.Definition.Id;
        end
        description = context.Definition.Description;
    else
        summary = node.Title;
        description = node.Description;
        if summary == ""
            [summary, description] = splitFirstSentence(description);
        end
        if summary == ""
            summary = "Options of group " + strjoin(groupPath, ".") + " of definition " + context.Definition.Id;
        end
    end

    lines = [
        "classdef (Sealed) " + className
        "%" + className + " " + summary];
    if description ~= ""
        lines = [lines; "%"; wrapText(description, "%   ")];
    end
    lines = [lines
        "%"
        wrapText("options = " + qualifiedName + "() holds the default value of every option.", "%   ")
        wrapText("options = " + qualifiedName + "(values) sets the options in the struct values. " + ...
            "Options that values does not set keep their defaults.", "%   ")
        wrapText("options = " + qualifiedName + "(Name=Value) sets options by name.", "%   ")
        "%"
        "%   Setting an option checks its value. options.toStruct() returns the values"
        "%   for optionspec.Definition."
        "%"
        "%   Generated by optionspec.generateClasses from definition """ + context.Definition.Id + ""","
        "%   version " + context.Definition.Version + ", file " + context.DefinitionFile ...
            + ". Do not edit this file; change the"
        "%   definition and generate the classes again."
        ""];
end

function lines = propertyHelp(name, node)
    summary = node.Title;
    description = node.Description;
    if summary == ""
        [summary, description] = splitFirstSentence(description);
    end
    if summary == "" && node.Type == "object"
        summary = "Group of options";
    elseif summary == ""
        summary = "Option " + name;
    end
    lines = "        % " + name + " - " + summary;
    if description ~= ""
        lines = [lines; wrapText(description, "        %   ")];
    end
    if node.Type ~= "object"
        lines = [lines; wrapText(describeConstraints(node), "        %   ")];
    end
end

function text = describeConstraints(node)
    parts = "Default: " + literal(node.Default, node) + ".";
    if ~isempty(node.Enum)
        parts(end+1) = "Allowed values: " + strjoin(cellfun(@(value) literal(value, node), node.Enum), ", ") + ".";
    end
    itemNode = node;
    if node.Type == "array"
        itemNode = node.Items;
        if itemNode.Type == "array"
            itemNode = itemNode.Items;
        end
        if ~isempty(itemNode.Enum)
            parts(end+1) = "Allowed elements: " ...
                + strjoin(cellfun(@(value) literal(value, itemNode), itemNode.Enum), ", ") + ".";
        end
        countText = describeCount(node.MinItems, node.MaxItems);
        if countText ~= ""
            parts(end+1) = "Number of " + pluralItem(node) + ": " + countText + ".";
        end
    end
    rangeText = describeRange(itemNode);
    if rangeText ~= ""
        parts(end+1) = "Range: " + rangeText + ".";
    end
    if ~isempty(itemNode.NonFinite)
        parts(end+1) = "Allows " + strjoin(itemNode.NonFinite, ", ") + ".";
    end
    if node.Nullable
        parts(end+1) = "[] means not set.";
    end
    if ~isempty(node.UI) && isfield(node.UI, "units")
        parts(end+1) = "Units: " + string(node.UI.units) + ".";
    end
    text = strjoin(parts, " ");
end

function text = pluralItem(node)
    if node.Items.Type == "array"
        text = "rows";
    else
        text = "elements";
    end
end

function text = describeCount(minimum, maximum)
    if ~isempty(minimum) && ~isempty(maximum) && minimum == maximum
        text = string(minimum);
    elseif ~isempty(minimum) && ~isempty(maximum)
        text = minimum + " to " + maximum;
    elseif ~isempty(minimum)
        text = "at least " + minimum;
    elseif ~isempty(maximum)
        text = "at most " + maximum;
    else
        text = "";
    end
end

function text = describeRange(node)
    parts = strings(1, 0);
    if ~isempty(node.Minimum)
        parts(end+1) = ">= " + numberLiteral(node.Minimum);
    end
    if ~isempty(node.ExclusiveMinimum)
        parts(end+1) = "> " + numberLiteral(node.ExclusiveMinimum);
    end
    if ~isempty(node.Maximum)
        parts(end+1) = "<= " + numberLiteral(node.Maximum);
    end
    if ~isempty(node.ExclusiveMaximum)
        parts(end+1) = "< " + numberLiteral(node.ExclusiveMaximum);
    end
    text = strjoin(parts, " and ");
end

function [declaration, conversion, helpers] = renderOption(name, node)
% Return the property declaration, the line of toStruct and the names of
% the local validation functions the declaration calls.
    helpers = strings(1, 0);
    validators = strings(1, 0);
    conversion = sprintf("            values.%s = obj.%s;", name, name);

    switch node.Type
        case "boolean"
            typeText = "logical";
            sizeText = "(1,1)";
        case {"integer", "number"}
            typeText = "double";
            sizeText = "(1,1)";
            [validators, helpers] = numberValidators(name, node);
        case "string"
            typeText = "char";
            sizeText = "(1,:)";
            if ~isempty(node.Enum)
                validators(end+1) = sprintf("mustBeMember(%s, %s)", name, cellLiteral(node.Enum));
            end
            conversion = sprintf("            values.%s = canonicalText(obj.%s);", name, name);
            helpers(end+1) = "canonicalText";
        case "array"
            [typeText, sizeText, validators, helpers, conversion] = arrayDeclaration(name, node);
    end

    if node.Nullable
        % Size and class validation would turn [] into an empty value of the
        % class, so a nullable option declares neither and a local function
        % checks the value
        [typeText, sizeText, validators, helpers, conversion] = ...
            nullableDeclaration(name, node, typeText, validators, helpers);
    end

    declaration = "        " + strjoin([name, sizeText, typeText], " ");
    declaration = strtrim(regexprep(declaration, " +", " "));
    declaration = "        " + declaration;
    if ~isempty(validators)
        declaration = declaration + " {" + strjoin(validators, ", ") + "}";
    end
    declaration = declaration + " = " + literal(node.Default, node);
    declaration = wrapDeclaration(declaration);
end

function [validators, helpers] = numberValidators(name, node)
    validators = strings(1, 0);
    helpers = strings(1, 0);
    allNonFinite = ["Inf", "-Inf", "NaN"];
    if isempty(node.NonFinite)
        validators(end+1) = sprintf("mustBeFinite(%s)", name);
        if node.Type == "integer"
            validators(end+1) = sprintf("mustBeInteger(%s)", name);
        end
    else
        if ~all(ismember(allNonFinite, node.NonFinite))
            validators(end+1) = sprintf("mustBeFiniteOr(%s, %s)", name, stringArrayLiteral(node.NonFinite));
            helpers(end+1) = "mustBeFiniteOr";
        end
        if node.Type == "integer"
            validators(end+1) = sprintf("mustBeIntegerOrNonFinite(%s)", name);
            helpers(end+1) = "mustBeIntegerOrNonFinite";
        end
    end

    if any(node.NonFinite == "NaN")
        % The built-in range validators reject NaN, which is outside every range
        bounds = [optionalNumber(node.Minimum), optionalNumber(node.Maximum), ...
            optionalNumber(node.ExclusiveMinimum), optionalNumber(node.ExclusiveMaximum)];
        if any(bounds ~= "[]")
            validators(end+1) = sprintf("mustBeInRangeOrNaN(%s, %s)", name, strjoin(bounds, ", "));
            helpers(end+1) = "mustBeInRangeOrNaN";
        end
    else
        rangeValidators = ["mustBeGreaterThanOrEqual", "mustBeLessThanOrEqual", ...
            "mustBeGreaterThan", "mustBeLessThan"];
        bounds = {node.Minimum, node.Maximum, node.ExclusiveMinimum, node.ExclusiveMaximum};
        for i = 1:numel(bounds)
            if ~isempty(bounds{i})
                validators(end+1) = sprintf("%s(%s, %s)", rangeValidators(i), name, numberLiteral(bounds{i})); %#ok<AGROW>
            end
        end
    end

    if ~isempty(node.Enum)
        validators(end+1) = sprintf("mustBeMember(%s, %s)", name, numericRowLiteral(cell2mat(node.Enum)));
    end
end

function [typeText, sizeText, validators, helpers, conversion] = arrayDeclaration(name, node)
    items = node.Items;
    validators = strings(1, 0);
    helpers = strings(1, 0);
    conversion = sprintf("            values.%s = obj.%s;", name, name);

    if items.Type == "array"
        elementNode = items.Items;
        sizeText = "(:,:)";
        countBounds = [optionalNumber(node.MinItems), optionalNumber(node.MaxItems), ...
            optionalNumber(items.MinItems), optionalNumber(items.MaxItems)];
        if any(countBounds ~= "[]")
            validators(end+1) = sprintf("mustHaveMatrixSize(%s, %s)", name, strjoin(countBounds, ", "));
            helpers(end+1) = "mustHaveMatrixSize";
        end
        conversion = sprintf("            values.%s = canonicalMatrix(obj.%s);", name, name);
        helpers(end+1) = "canonicalMatrix";
    else
        elementNode = items;
        isFixedLength = ~isempty(node.MinItems) && ~isempty(node.MaxItems) && node.MinItems == node.MaxItems;
        if isFixedLength
            sizeText = sprintf("(1,%d)", node.MinItems);
        else
            sizeText = "(1,:)";
            if ~isempty(node.MinItems) || ~isempty(node.MaxItems)
                validators(end+1) = sprintf("mustHaveElementCount(%s, %s, %s)", name, ...
                    optionalNumber(node.MinItems), optionalNumber(node.MaxItems));
                helpers(end+1) = "mustHaveElementCount";
            end
        end
    end

    switch elementNode.Type
        case "boolean"
            typeText = "logical";
        case "string"
            typeText = "string";
            if ~isempty(elementNode.Enum)
                validators(end+1) = sprintf("mustBeMember(%s, %s)", name, ...
                    stringArrayLiteral(string(elementNode.Enum)));
            end
        otherwise
            typeText = "double";
            [elementValidators, elementHelpers] = numberValidators(name, elementNode);
            validators = [validators, elementValidators];
            helpers = [helpers, elementHelpers];
    end
end

function [typeText, sizeText, validators, helpers, conversion] = ...
        nullableDeclaration(name, node, typeText, validators, helpers)
    sizeText = "";
    switch node.Type
        case "string"
            typeText = "";
            validators = [sprintf("mustBeTextOrNull(%s)", name), validators];
            helpers = [helpers, "mustBeTextOrNull"];
            conversion = sprintf("            values.%s = canonicalNullableText(obj.%s);", name, name);
            helpers = [setdiff(helpers, "canonicalText", "stable"), "canonicalNullableText"];
            % mustBeMember needs text, so it is checked by mustBeTextOrNull
            validators = validators(~startsWith(validators, "mustBeMember"));
            if ~isempty(node.Enum)
                validators(1) = sprintf("mustBeTextOrNull(%s, %s)", name, cellLiteral(node.Enum));
            end
        case "array"
            if node.Items.Type ~= "array"
                validators = [sprintf("mustBeVectorOrNull(%s, %s, %s)", name, ...
                    optionalNumber(node.MinItems), optionalNumber(node.MaxItems)), ...
                    validators(~startsWith(validators, "mustHaveElementCount"))];
                helpers = [setdiff(helpers, "mustHaveElementCount", "stable"), "mustBeVectorOrNull"];
                conversion = sprintf("            values.%s = canonicalNullableVector(obj.%s);", name, name);
                helpers(end+1) = "canonicalNullableVector";
            else
                conversion = sprintf("            values.%s = canonicalNullableMatrix(obj.%s);", name, name);
                helpers = [setdiff(helpers, "canonicalMatrix", "stable"), "canonicalNullableMatrix"];
            end
        otherwise
            validators = [sprintf("mustBeScalarOrEmpty(%s)", name), validators];
            conversion = sprintf("            values.%s = canonicalNullableScalar(obj.%s);", name, name);
            helpers(end+1) = "canonicalNullableScalar";
    end
end

function lines = renderHelpers(helperNames)
    lines = strings(0, 1);
    for helperName = helperNames
        lines = [lines; ""; helperCode(helperName)]; %#ok<AGROW>
    end
end

function lines = helperCode(helperName)
    switch helperName
        case "canonicalText"
            lines = [
                "function value = canonicalText(value)"
                "% Empty text is '' (0x0), as optionspec.Definition returns it"
                "    if isempty(value)"
                "        value = '';"
                "    end"
                "end"];
        case "canonicalNullableText"
            lines = [
                "function value = canonicalNullableText(value)"
                "% [] means not set; other values are char"
                "    if isa(value, ""double"") && isempty(value)"
                "        value = [];"
                "    else"
                "        value = char(value);"
                "    end"
                "end"];
        case "canonicalNullableScalar"
            lines = [
                "function value = canonicalNullableScalar(value)"
                "% [] means not set"
                "    if isempty(value)"
                "        value = [];"
                "    end"
                "end"];
        case "canonicalNullableVector"
            lines = [
                "function value = canonicalNullableVector(value)"
                "% [] (0x0) means not set; other values are row vectors"
                "    if isequal(size(value), [0, 0])"
                "        value = [];"
                "    else"
                "        value = reshape(value, 1, []);"
                "    end"
                "end"];
        case "canonicalMatrix"
            lines = [
                "function value = canonicalMatrix(value)"
                "% An empty matrix is 0x0, as optionspec.Definition returns it"
                "    if isempty(value)"
                "        value = reshape(value, 0, 0);"
                "    end"
                "end"];
        case "canonicalNullableMatrix"
            lines = [
                "function value = canonicalNullableMatrix(value)"
                "% An empty matrix means not set"
                "    if isempty(value)"
                "        value = [];"
                "    end"
                "end"];
        case "mustBeFiniteOr"
            lines = [
                "function mustBeFiniteOr(value, allowedValues)"
                "% Values must be finite or one of the non-finite values listed"
                "    labels = strings(1, 0);"
                "    if any(isnan(value), ""all"")"
                "        labels(end+1) = ""NaN"";"
                "    end"
                "    if any(value == Inf, ""all"")"
                "        labels(end+1) = ""Inf"";"
                "    end"
                "    if any(value == -Inf, ""all"")"
                "        labels(end+1) = ""-Inf"";"
                "    end"
                "    if ~all(ismember(labels, allowedValues))"
                "        error(""OPTIONSPEC:NonFiniteNotAllowed"", ""Value must be finite or one of %s."", ..."
                "            strjoin(allowedValues, "", ""))"
                "    end"
                "end"];
        case "mustBeIntegerOrNonFinite"
            lines = [
                "function mustBeIntegerOrNonFinite(value)"
                "    finiteValues = value(isfinite(value));"
                "    if any(finiteValues ~= round(finiteValues))"
                "        error(""OPTIONSPEC:NotInteger"", ""Value must be an integer."")"
                "    end"
                "end"];
        case "mustBeInRangeOrNaN"
            lines = [
                "function mustBeInRangeOrNaN(value, minimum, maximum, exclusiveMinimum, exclusiveMaximum)"
                "% NaN is allowed and outside every range, so only other values are checked"
                "    value = value(~isnan(value));"
                "    isInRange = all(value >= minimum) && all(value <= maximum) ..."
                "        && all(value > exclusiveMinimum) && all(value < exclusiveMaximum);"
                "    if ~isInRange"
                "        error(""OPTIONSPEC:OutOfRange"", ""Value is outside the allowed range."")"
                "    end"
                "end"];
        case "mustHaveElementCount"
            lines = [
                "function mustHaveElementCount(value, minimum, maximum)"
                "    count = numel(value);"
                "    if any(count < minimum) || any(count > maximum)"
                "        error(""OPTIONSPEC:WrongElementCount"", ""Value has %d elements; allowed: %s to %s."", ..."
                "            count, mat2str(minimum), mat2str(maximum))"
                "    end"
                "end"];
        case "mustHaveMatrixSize"
            lines = [
                "function mustHaveMatrixSize(value, minRows, maxRows, minColumns, maxColumns)"
                "    [rowCount, columnCount] = size(value);"
                "    if isempty(value)"
                "        rowCount = 0;"
                "    end"
                "    isValid = ~any(rowCount < minRows) && ~any(rowCount > maxRows);"
                "    if rowCount > 0"
                "        isValid = isValid && ~any(columnCount < minColumns) && ~any(columnCount > maxColumns);"
                "    end"
                "    if ~isValid"
                "        error(""OPTIONSPEC:WrongMatrixSize"", ""Value has a size outside the allowed size."")"
                "    end"
                "end"];
        case "mustBeTextOrNull"
            lines = [
                "function mustBeTextOrNull(value, allowedValues)"
                "% [] means not set; otherwise the value is text, from allowedValues if given"
                "    if isa(value, ""double"") && isequal(size(value), [0, 0])"
                "        return"
                "    end"
                "    if ~((ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value)))"
                "        error(""OPTIONSPEC:NotText"", ""Value must be text or []."")"
                "    end"
                "    if nargin > 1 && ~any(strcmp(char(value), allowedValues))"
                "        error(""OPTIONSPEC:NotAllowed"", ""Value must be [] or one of: %s."", strjoin(allowedValues, "", ""))"
                "    end"
                "end"];
        case "mustBeVectorOrNull"
            lines = [
                "function mustBeVectorOrNull(value, minimum, maximum)"
                "% [] (0x0) means not set; otherwise the value is a vector"
                "    if isequal(size(value), [0, 0])"
                "        return"
                "    end"
                "    if ~(isvector(value) || isempty(value))"
                "        error(""OPTIONSPEC:NotVector"", ""Value must be a vector or []."")"
                "    end"
                "    count = numel(value);"
                "    if any(count < minimum) || any(count > maximum)"
                "        error(""OPTIONSPEC:WrongElementCount"", ""Value has %d elements; allowed: %s to %s."", ..."
                "            count, mat2str(minimum), mat2str(maximum))"
                "    end"
                "end"];
    end
end

function text = literal(value, node)
% MATLAB expression for a canonical value of node
    if node.Nullable && isa(value, "double") && isequal(size(value), [0, 0])
        text = "[]";
        return
    end
    switch node.Type
        case "boolean"
            text = string(mat2str(value));
        case {"integer", "number"}
            text = numberLiteral(value);
        case "string"
            text = charLiteral(value);
        case "array"
            if node.Items.Type == "array"
                text = matrixLiteral(value, node.Items.Items.Type);
            else
                switch node.Items.Type
                    case "string"
                        text = stringArrayLiteral(value);
                    case "boolean"
                        text = logicalRowLiteral(value);
                    otherwise
                        text = numericRowLiteral(value);
                end
            end
        otherwise
            text = "";
    end
end

function text = numberLiteral(value)
    if isnan(value)
        text = "NaN";
    elseif isinf(value)
        text = "Inf";
        if value < 0
            text = "-Inf";
        end
    elseif value == round(value) && abs(value) < 1e15
        text = string(sprintf("%d", value));
    else
        % The shortest text that reads back as the same double
        for precision = 1:17
            text = string(sprintf("%.*g", precision, value));
            if str2double(text) == value
                break
            end
        end
    end
end

function text = numericRowLiteral(values)
    if isempty(values)
        text = "zeros(1, 0)";
    elseif isscalar(values)
        text = numberLiteral(values);
    else
        text = "[" + strjoin(arrayfun(@numberLiteral, values), ", ") + "]";
    end
end

function text = logicalRowLiteral(values)
    if isempty(values)
        text = "false(1, 0)";
    elseif isscalar(values)
        text = string(mat2str(values));
    else
        text = "[" + strjoin(arrayfun(@(value) string(mat2str(value)), values), ", ") + "]";
    end
end

function text = matrixLiteral(values, elementType)
    if isempty(values)
        if elementType == "boolean"
            text = "false(0, 0)";
        else
            text = "zeros(0, 0)";
        end
        return
    end
    rows = strings(1, size(values, 1));
    for i = 1:size(values, 1)
        if elementType == "boolean"
            rows(i) = strjoin(arrayfun(@(value) string(mat2str(value)), values(i, :)), ", ");
        else
            rows(i) = strjoin(arrayfun(@numberLiteral, values(i, :)), ", ");
        end
    end
    text = "[" + strjoin(rows, "; ") + "]";
end

function text = charLiteral(value)
    text = "'" + strrep(string(value), "'", "''") + "'";
end

function text = stringArrayLiteral(values)
    values = string(values);
    quoted = """" + strrep(values, """", """""") + """";
    if isempty(values)
        text = "strings(1, 0)";
    elseif isscalar(values)
        text = quoted;
    else
        text = "[" + strjoin(quoted, ", ") + "]";
    end
end

function text = cellLiteral(values)
    text = "{" + strjoin(cellfun(@charLiteral, values), ", ") + "}";
end

function text = optionalNumber(value)
    if isempty(value)
        text = "[]";
    else
        text = numberLiteral(value);
    end
end

function lines = wrapText(text, prefix)
% Wrap text into comment lines of at most 100 characters
    maximumLength = 100 - strlength(prefix);
    words = split(strtrim(text))';
    lines = strings(0, 1);
    currentLine = "";
    for word = words
        if currentLine == ""
            candidate = word;
        else
            candidate = currentLine + " " + word;
        end
        if strlength(candidate) > maximumLength && currentLine ~= ""
            lines(end+1, 1) = prefix + currentLine; %#ok<AGROW>
            currentLine = word;
        else
            currentLine = candidate;
        end
    end
    if currentLine ~= ""
        lines(end+1, 1) = prefix + currentLine;
    end
end

function text = wrapDeclaration(text)
% Break a long property declaration after the commas between validators
    maximumLength = 120;
    if strlength(text) <= maximumLength
        return
    end
    parts = split(text, ", mustBe")';
    parts(2:end) = "mustBe" + parts(2:end);
    text = strjoin(parts, ", ..." + newline + "            ");
end

function lines = wrapList(items, opening, closing)
% Write items separated by commas, continued on new lines past 100 characters
    indent = "    " + regexp(opening, '^\s*', "match", "once");
    lines = strings(0, 1);
    currentLine = opening;
    for i = 1:numel(items)
        item = items(i);
        if i < numel(items)
            item = item + ",";
        end
        if strlength(currentLine + item) > 100 && i > 1
            lines(end+1, 1) = currentLine + " ..."; %#ok<AGROW>
            currentLine = indent + item;
        elseif i == 1
            currentLine = currentLine + item;
        else
            currentLine = currentLine + " " + item;
        end
    end
    lines(end+1, 1) = currentLine + closing;
end

function [firstSentence, rest] = splitFirstSentence(text)
    tokens = regexp(text, '^(.*?\.)\s+(.*)$', "tokens", "once");
    if isempty(tokens)
        firstSentence = strip(text, "right", ".");
        rest = "";
    else
        firstSentence = strip(string(tokens{1}), "right", ".");
        rest = string(tokens{2});
    end
end

function suffix = groupSuffix(groupPath)
% "Stack" for the group Stack, "OuterInner" for Outer.Inner
    suffix = strjoin(["", capitalize(groupPath)], "");
end

function text = capitalize(name)
    text = upper(extractBefore(name, 2)) + extractAfter(name, 1);
end

function name = qualify(namespace, className)
    if namespace == ""
        name = className;
    else
        name = namespace + "." + className;
    end
end

function name = lastSegment(qualifiedName)
    parts = split(qualifiedName, ".");
    name = parts(end);
end
