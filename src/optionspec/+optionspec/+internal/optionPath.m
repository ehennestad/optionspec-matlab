function result = optionPath(action, values, path, value)
%optionPath Test, get, set or remove an option of a values struct by dotted path.
%
%   tf = optionspec.internal.optionPath("has", values, path)
%   value = optionspec.internal.optionPath("get", values, path)
%   values = optionspec.internal.optionPath("set", values, path, value)
%   values = optionspec.internal.optionPath("remove", values, path)
%
%   "set" creates the groups on the path that do not exist. "remove"
%   also removes groups that it leaves empty, because a group without
%   options is not valid. A path through a value that is not a scalar
%   struct is an OPTIONSPEC:MigrationFailed error for "set", and absent
%   for "has".

    arguments
        action (1,1) string {mustBeMember(action, ["has", "get", "set", "remove"])}
        values
        path (1,1) string
        value = []
    end

    names = split(path, ".")';
    switch action
        case "has"
            result = hasPath(values, names);
        case "get"
            result = getfield(values, names{:});
        case "set"
            result = setPath(values, names, value, path);
        case "remove"
            result = removePath(values, names);
    end
end

function tf = hasPath(values, names)
    tf = isstruct(values) && isscalar(values) && isfield(values, names(1));
    if tf && numel(names) > 1
        tf = hasPath(values.(names(1)), names(2:end));
    end
end

function values = setPath(values, names, value, path)
    if ~(isstruct(values) && isscalar(values))
        error("OPTIONSPEC:MigrationFailed", ...
            "Cannot set ""%s"": the values on its path are not a group.", path)
    end
    if isscalar(names)
        values.(names(1)) = value;
    else
        if ~isfield(values, names(1))
            values.(names(1)) = struct();
        end
        values.(names(1)) = setPath(values.(names(1)), names(2:end), value, path);
    end
end

function values = removePath(values, names)
    if isscalar(names)
        values = rmfield(values, names(1));
    else
        values.(names(1)) = removePath(values.(names(1)), names(2:end));
        if isempty(fieldnames(values.(names(1))))
            values = rmfield(values, names(1));
        end
    end
end
