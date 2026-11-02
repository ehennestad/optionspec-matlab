function [changes, level, renameCandidates] = checkDefinition(options, definition, nameValues)
%checkDefinition Compare an options struct with its definition.
%
%   [changes, level] = optionspec.checkDefinition(options, definition)
%   infers a definition from the struct options, as
%   optionspec.inferDefinition does, and compares it option by option with
%   definition, an optionspec.Definition or the path of a definition file.
%   changes is a struct array with the fields Path, Kind, Detail and Level,
%   one element per difference. level is the version change the
%   differences need, the highest of their levels: "none", "patch",
%   "minor" or "major".
%
%     major  an option removed or retyped, an enum value or non-finite
%            value removed, a range or element count narrowed, null no
%            longer allowed
%     minor  an option added, an enum value added, a range widened, a
%            default changed
%     patch  a title, description, format or "x-ui" hint changed
%
%   A changed default is a change of the definition: the default is what
%   a run uses when the caller does not pass the option.
%
%   [changes, level, renameCandidates] = optionspec.checkDefinition(...)
%   also returns an N-by-2 string array of [removed, added] option paths
%   that may be renames: a removed and an added option in the same group
%   with the same type. A rename cannot be told apart from a removed and an
%   added option, so a person confirms it; pass confirmed renames to
%   optionspec.updateDefinition.
%
%   Name-value arguments:
%     Descriptions - Descriptions of the options, as for
%                    optionspec.inferDefinition. Default: struct()
%
%   See also optionspec.updateDefinition, optionspec.inferDefinition

    arguments
        options (1,1) struct
        definition
        nameValues.Descriptions (1,1) struct = struct()
    end

    if ~isa(definition, "optionspec.Definition")
        definition = optionspec.Definition(definition);
    end
    if ~isempty(definition.Includes)
        error("OPTIONSPEC:IncludesNotSupported", ...
            "Definition ""%s"" includes other definitions. An options struct can only be compared " + ...
            "with a definition without ""allOf"".", definition.Id)
    end

    newRoot = optionspec.internal.inferRootNode(options, nameValues.Descriptions);
    changes = optionspec.internal.compareNodes(definition.Schema, newRoot, "");
    level = optionspec.internal.highestLevel(changes);
    renameCandidates = findRenameCandidates(changes, definition.Schema, newRoot);
end

function candidates = findRenameCandidates(changes, oldRoot, newRoot)
    candidates = strings(0, 2);
    kinds = string({changes.Kind});
    paths = string({changes.Path});
    removedPaths = paths(kinds == "removed");
    addedPaths = paths(kinds == "added");
    for removedPath = removedPaths
        for addedPath = addedPaths
            isSameGroup = parentPath(removedPath) == parentPath(addedPath);
            if isSameGroup && haveSameType(nodeAt(oldRoot, removedPath), nodeAt(newRoot, addedPath))
                candidates(end+1, :) = [removedPath, addedPath]; %#ok<AGROW>
            end
        end
    end
end

function tf = haveSameType(nodeA, nodeB)
    tf = nodeA.Type == nodeB.Type && nodeA.Nullable == nodeB.Nullable;
    if tf && nodeA.Type == "array"
        tf = haveSameType(nodeA.Items, nodeB.Items);
    end
end

function node = nodeAt(rootNode, path)
    node = rootNode;
    for name = split(path, ".")'
        node = node.Properties.(name);
    end
end

function parent = parentPath(path)
    parts = split(path, ".");
    parent = strjoin(parts(1:end-1), ".");
end
