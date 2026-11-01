function [node, issues] = finalizeNode(node, path, isItemsNode)
%finalizeNode Check that a composed schema node is complete and consistent.
%
%   [node, issues] = optionspec.internal.finalizeNode(node, path) checks
%   that each keyword of node fits its type, that every option has a
%   default and that the default is valid. It returns the node with its
%   enum values and default in canonical form (see
%   optionspec.internal.normalizeValue), and a string array of problems.
%
%   [node, issues] = optionspec.internal.finalizeNode(node, path, true)
%   checks the items of an array option, which have no default.

    arguments
        node (1,1) struct
        path (1,1) string
        isItemsNode (1,1) logical = false
    end

    issues = strings(1, 0);
    if node.Type == ""
        issues(end+1) = path + ": ""type"" is missing.";
        return
    end

    isNumber = any(node.Type == ["integer", "number"]);
    if ~isempty(node.Enum) && ~any(node.Type == ["string", "integer", "number"])
        issues(end+1) = path + ": ""enum"" applies only to string, integer and number options.";
    end
    hasRange = ~isempty(node.Minimum) || ~isempty(node.Maximum) ...
        || ~isempty(node.ExclusiveMinimum) || ~isempty(node.ExclusiveMaximum);
    if hasRange && ~isNumber
        issues(end+1) = path + ": ""minimum"" and ""maximum"" apply only to integer and number options.";
    end
    if ~isempty(node.NonFinite) && ~isNumber
        issues(end+1) = path + ": ""x-nonfinite"" applies only to integer and number options.";
    end
    hasArrayKeyword = ~isempty(node.Items) || ~isempty(node.MinItems) || ~isempty(node.MaxItems);
    if hasArrayKeyword && node.Type ~= "array"
        issues(end+1) = path + ": ""items"", ""minItems"" and ""maxItems"" apply only to array options.";
    end
    if ~isempty(node.Properties) && node.Type ~= "object"
        issues(end+1) = path + ": ""properties"" applies only to groups (type ""object"").";
    end
    if node.Format ~= "" && node.Type ~= "string"
        issues(end+1) = path + ": ""format"" applies only to string options.";
    end
    if ~isempty(node.Minimum) && ~isempty(node.Maximum) && node.Minimum > node.Maximum
        issues(end+1) = path + ": ""minimum"" is greater than ""maximum"".";
    end
    if ~isempty(node.MinItems) && ~isempty(node.MaxItems) && node.MinItems > node.MaxItems
        issues(end+1) = path + ": ""minItems"" is greater than ""maxItems"".";
    end
    issues = [issues, checkUserInterfaceHints(node, path)];

    if isItemsNode
        if node.Nullable
            issues(end+1) = path + ": array items cannot be null.";
        end
        if node.HasDefault || ~isempty(node.UI)
            issues(end+1) = path + ": array items cannot have ""default"" or ""x-ui"".";
        end
    end

    switch node.Type
        case "object"
            [node, issues] = finalizeGroup(node, path, isItemsNode, issues);
            return
        case "array"
            [node, issues] = finalizeArrayItems(node, path, issues);
    end

    if ~isempty(issues)
        return
    end

    if ~isempty(node.Enum)
        nodeWithoutEnum = node;
        nodeWithoutEnum.Enum = {};
        for i = 1:numel(node.Enum)
            [node.Enum{i}, enumIssues] = optionspec.internal.normalizeValue( ...
                node.Enum{i}, nodeWithoutEnum, path + " enum value");
            issues = [issues, enumIssues]; %#ok<AGROW>
        end
    end

    if ~isItemsNode && isempty(issues)
        if node.HasDefault
            [node.Default, issues] = optionspec.internal.normalizeValue( ...
                node.Default, node, path + " default");
        else
            issues(end+1) = path + ": ""default"" is missing; every option needs a default.";
        end
    end
end

function [node, issues] = finalizeGroup(node, path, isItemsNode, issues)
    if isItemsNode
        issues(end+1) = path + ": array items cannot be groups.";
        return
    end
    if isempty(node.Properties)
        issues(end+1) = path + ": a group (type ""object"") needs ""properties"".";
        return
    end
    if node.Nullable
        issues(end+1) = path + ": a group cannot be null.";
    end
    if node.HasDefault
        issues(end+1) = path + ": a group takes its default from its options; remove ""default"".";
    end
    if ~isempty(node.UI)
        issues(end+1) = path + ": a group cannot have ""x-ui"".";
    end
    for name = string(fieldnames(node.Properties))'
        [node.Properties.(name), childIssues] = optionspec.internal.finalizeNode( ...
            node.Properties.(name), optionspec.internal.joinPath(path, name));
        issues = [issues, childIssues]; %#ok<AGROW>
    end
end

function [node, issues] = finalizeArrayItems(node, path, issues)
    if isempty(node.Items)
        issues(end+1) = path + ": an array option needs ""items"".";
        return
    end
    [node.Items, itemIssues] = optionspec.internal.finalizeNode(node.Items, path + "(:)", true);
    issues = [issues, itemIssues];
    if ~isempty(itemIssues)
        return
    end
    if node.Items.Type == "array"
        % A matrix: the inner arrays are its rows and hold scalars
        innerType = node.Items.Items.Type;
        if ~any(innerType == ["boolean", "integer", "number"])
            issues(end+1) = path + ": the rows of a matrix option must hold boolean, integer or number items.";
        end
    end
end

function issues = checkUserInterfaceHints(node, path)
    issues = strings(1, 0);
    if isempty(node.UI) || ~isfield(node.UI, "widget")
        return
    end
    widget = string(node.UI.widget);
    isNumber = any(node.Type == ["integer", "number"]);
    switch widget
        case "dropdown"
            isValid = ~isempty(node.Enum);
            requirement = "an option with ""enum""";
        case "slider"
            isValid = isNumber && ~isempty(node.Minimum) && ~isempty(node.Maximum);
            requirement = "an integer or number option with ""minimum"" and ""maximum""";
        case {"checkbox", "button", "togglebutton"}
            isValid = node.Type == "boolean";
            requirement = "a boolean option";
        case {"multilinetext", "folder", "file"}
            isValid = node.Type == "string";
            requirement = "a string option";
        otherwise
            % "edit" and "hidden" fit every option type
            isValid = true;
            requirement = "";
    end
    if ~isValid
        issues(end+1) = sprintf("%s: widget ""%s"" needs %s.", path, widget, requirement);
    end
end
