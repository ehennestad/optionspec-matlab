function changes = compareNodes(oldNode, newNode, path)
%compareNodes List the differences between two canonical schema nodes.
%
%   changes = optionspec.internal.compareNodes(oldNode, newNode, path)
%   returns a struct array with the fields Path, Kind, Detail and Level.
%   Level is the version change the difference needs:
%     "major" - values valid under oldNode can be invalid under newNode:
%               an option removed or retyped, an enum value or non-finite
%               value removed, a range or element count narrowed, null no
%               longer allowed.
%     "minor" - every valid value stays valid: an option added, an enum
%               value added, a range widened, a default changed.
%     "patch" - only a title, description, format or "x-ui" hint changed.
%   Kind is one of "added", "removed", "type", "enum", "range", "count",
%   "nonfinite", "null", "default" and "annotation".

    arguments
        oldNode (1,1) struct
        newNode (1,1) struct
        path (1,1) string
    end

    changes = emptyChanges();
    isOldGroup = oldNode.Type == "object";
    isNewGroup = newNode.Type == "object";
    if isOldGroup ~= isNewGroup
        changes = addChange(changes, path, "type", sprintf("changed from %s to %s", ...
            describeType(oldNode), describeType(newNode)), "major");
        return
    end
    changes = [changes, compareAnnotations(oldNode, newNode, path)];

    if isOldGroup
        oldNames = string(fieldnames(oldNode.Properties))';
        newNames = string(fieldnames(newNode.Properties))';
        for name = oldNames
            optionPath = optionspec.internal.joinPath(path, name);
            if isfield(newNode.Properties, name)
                changes = [changes, optionspec.internal.compareNodes( ...
                    oldNode.Properties.(name), newNode.Properties.(name), optionPath)]; %#ok<AGROW>
            else
                changes = addChange(changes, optionPath, "removed", "option removed", "major");
            end
        end
        for name = setdiff(newNames, oldNames, "stable")
            changes = addChange(changes, optionspec.internal.joinPath(path, name), "added", ...
                "option added", "minor");
        end
        return
    end

    [typeChanges, isComparable] = compareTypes(oldNode, newNode, path);
    changes = [changes, typeChanges];
    if ~isComparable
        return
    end
    changes = [changes, compareConstraints(oldNode, newNode, path)];
    if oldNode.Type == "array"
        changes = [changes, compareItems(oldNode.Items, newNode.Items, path + "(:)")];
    end
    if oldNode.HasDefault && newNode.HasDefault && ~isequaln(oldNode.Default, newNode.Default)
        changes = addChange(changes, path, "default", sprintf("default changed from %s to %s", ...
            optionspec.internal.describeValue(oldNode.Default), ...
            optionspec.internal.describeValue(newNode.Default)), "minor");
    end
end

function changes = compareItems(oldItems, newItems, path)
    [changes, isComparable] = compareTypes(oldItems, newItems, path);
    if ~isComparable
        return
    end
    changes = [changes, compareConstraints(oldItems, newItems, path)];
    if oldItems.Type == "array"
        changes = [changes, compareItems(oldItems.Items, newItems.Items, path + "(:)")];
    end
end

function [changes, isComparable] = compareTypes(oldNode, newNode, path)
    changes = emptyChanges();
    isComparable = true;
    if oldNode.Type ~= newNode.Type
        isWidening = oldNode.Type == "integer" && newNode.Type == "number";
        level = "major";
        if isWidening
            level = "minor";
        else
            isComparable = false;
        end
        changes = addChange(changes, path, "type", sprintf("type changed from %s to %s", ...
            describeType(oldNode), describeType(newNode)), level);
    end
    if oldNode.Nullable && ~newNode.Nullable
        changes = addChange(changes, path, "null", "null no longer allowed", "major");
    elseif ~oldNode.Nullable && newNode.Nullable
        changes = addChange(changes, path, "null", "null now allowed", "minor");
    end
end

function changes = compareConstraints(oldNode, newNode, path)
    changes = emptyChanges();

    if ~isequal(oldNode.Enum, newNode.Enum)
        if isempty(oldNode.Enum)
            changes = addChange(changes, path, "enum", "enum added", "major");
        elseif isempty(newNode.Enum)
            changes = addChange(changes, path, "enum", "enum removed", "minor");
        else
            removedValues = oldNode.Enum(~isMember(oldNode.Enum, newNode.Enum));
            addedValues = newNode.Enum(~isMember(newNode.Enum, oldNode.Enum));
            if ~isempty(removedValues)
                changes = addChange(changes, path, "enum", "enum values removed: " ...
                    + describeList(removedValues), "major");
            end
            if ~isempty(addedValues)
                changes = addChange(changes, path, "enum", "enum values added: " ...
                    + describeList(addedValues), "minor");
            end
        end
    end

    lowerBounds = ["Minimum", "ExclusiveMinimum", "MinItems"];
    upperBounds = ["Maximum", "ExclusiveMaximum", "MaxItems"];
    for field = [lowerBounds, upperBounds]
        oldValue = oldNode.(field);
        newValue = newNode.(field);
        if isequal(oldValue, newValue)
            continue
        end
        isLowerBound = any(field == lowerBounds);
        if isempty(oldValue)
            isNarrowed = true;
        elseif isempty(newValue)
            isNarrowed = false;
        elseif isLowerBound
            isNarrowed = newValue > oldValue;
        else
            isNarrowed = newValue < oldValue;
        end
        kind = "range";
        if endsWith(field, "Items")
            kind = "count";
        end
        level = "minor";
        verb = "widened";
        if isNarrowed
            level = "major";
            verb = "narrowed";
        end
        changes = addChange(changes, path, kind, sprintf("%s %s from %s to %s", ...
            lowerFirst(field), verb, describeBound(oldValue), describeBound(newValue)), level);
    end

    removedNonFinite = setdiff(oldNode.NonFinite, newNode.NonFinite);
    addedNonFinite = setdiff(newNode.NonFinite, oldNode.NonFinite);
    if ~isempty(removedNonFinite)
        changes = addChange(changes, path, "nonfinite", "no longer allows " ...
            + strjoin(removedNonFinite, ", "), "major");
    end
    if ~isempty(addedNonFinite)
        changes = addChange(changes, path, "nonfinite", "now allows " + strjoin(addedNonFinite, ", "), "minor");
    end
end

function changes = compareAnnotations(oldNode, newNode, path)
    changes = emptyChanges();
    for field = ["Title", "Description", "Format"]
        if oldNode.(field) ~= newNode.(field)
            changes = addChange(changes, path, "annotation", lowerFirst(field) + " changed", "patch");
        end
    end
    if ~isequal(oldNode.UI, newNode.UI)
        changes = addChange(changes, path, "annotation", """x-ui"" changed", "patch");
    end
end

function changes = emptyChanges()
    changes = struct("Path", {}, "Kind", {}, "Detail", {}, "Level", {});
end

function changes = addChange(changes, path, kind, detail, level)
    if path == ""
        path = "(definition)";
    end
    changes(end+1) = struct("Path", path, "Kind", kind, "Detail", string(detail), "Level", level);
end

function tf = isMember(values, list)
    tf = cellfun(@(value) any(cellfun(@(item) isequal(item, value), list)), values);
end

function text = describeList(values)
    text = strjoin(cellfun(@optionspec.internal.describeValue, values), ", ");
end

function text = describeBound(value)
    if isempty(value)
        text = "none";
    else
        text = optionspec.internal.describeValue(value);
    end
end

function text = describeType(node)
    text = node.Type;
    if node.Type == "array" && ~isempty(node.Items)
        text = "array of " + describeType(node.Items);
    end
end

function text = lowerFirst(text)
    text = lower(extractBefore(text, 2)) + extractAfter(text, 1);
end
