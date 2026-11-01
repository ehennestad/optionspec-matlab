function values = applyMigrations(values, steps, fromMajor, toMajor, definitionId)
%applyMigrations Upgrade values from one major version to another.
%
%   values = optionspec.internal.applyMigrations(values, steps, fromMajor,
%   toMajor, definitionId) applies the operations of each step from
%   fromMajor to toMajor in order. steps is the struct array returned by
%   optionspec.internal.loadMigrations. The values are not validated
%   between steps, because only the schema of the current version is known.
%
%   Operations act on the values as they are: an operation whose option
%   is absent does nothing, except "rename" to an option that exists,
%   which is an OPTIONSPEC:MigrationFailed error.

    arguments
        values
        steps struct
        fromMajor (1,1) double
        toMajor (1,1) double
        definitionId (1,1) string
    end

    for major = fromMajor:toMajor-1
        step = steps([steps.From] == major);
        if isempty(step)
            error("OPTIONSPEC:MissingMigration", ...
                "Definition ""%s"" has no migration from major version %d to %d.", ...
                definitionId, major, major + 1)
        end
        for i = 1:numel(step.Operations)
            values = applyOperation(values, step.Operations{i}, major);
        end
    end
end

function values = applyOperation(values, operation, major)
    switch operation.op
        case "rename"
            if optionspec.internal.optionPath("has", values, operation.from)
                if optionspec.internal.optionPath("has", values, operation.to)
                    error("OPTIONSPEC:MigrationFailed", ...
                        "Migration from version %d cannot rename ""%s"" to ""%s"", which exists.", ...
                        major, operation.from, operation.to)
                end
                value = optionspec.internal.optionPath("get", values, operation.from);
                values = optionspec.internal.optionPath("remove", values, operation.from);
                values = optionspec.internal.optionPath("set", values, operation.to, value);
            end

        case "remove"
            if optionspec.internal.optionPath("has", values, operation.path)
                values = optionspec.internal.optionPath("remove", values, operation.path);
            end

        case "add"
            if ~optionspec.internal.optionPath("has", values, operation.path)
                values = optionspec.internal.optionPath("set", values, operation.path, operation.value);
            end

        case "mapValues"
            if optionspec.internal.optionPath("has", values, operation.path)
                value = optionspec.internal.optionPath("get", values, operation.path);
                for i = 1:numel(operation.map)
                    if isequal(value, operation.map{i}.from)
                        values = optionspec.internal.optionPath("set", values, operation.path, ...
                            operation.map{i}.to);
                        break
                    end
                end
            end

        case "scale"
            if optionspec.internal.optionPath("has", values, operation.path)
                value = optionspec.internal.optionPath("get", values, operation.path);
                values = optionspec.internal.optionPath("set", values, operation.path, ...
                    scaleValue(value, operation.factor));
            end

        case "function"
            values = callMigrationFunction(values, operation.matlab, major);
    end
end

function value = scaleValue(value, factor)
% Numbers are scaled; text such as "Inf" in a decoded document is not a
% number until the values are validated, and is left as it is
    if isnumeric(value)
        value = value*factor;
    elseif iscell(value)
        for i = 1:numel(value)
            value{i} = scaleValue(value{i}, factor);
        end
    end
end

function values = callMigrationFunction(values, functionName, major)
    % exist returns 0 for namespace functions; which finds them
    if isempty(which(functionName))
        error("OPTIONSPEC:MigrationFailed", ...
            "Migration from version %d calls ""%s"", which is not a function on the MATLAB path.", ...
            major, functionName)
    end
    migrationFunction = str2func(functionName);
    try
        values = migrationFunction(values);
    catch cause
        exception = MException("OPTIONSPEC:MigrationFailed", ...
            "Migration function ""%s"" failed: %s", functionName, cause.message);
        throw(exception.addCause(cause))
    end
    if ~(isstruct(values) && isscalar(values))
        error("OPTIONSPEC:MigrationFailed", ...
            "Migration function ""%s"" must return a scalar struct.", functionName)
    end
end
