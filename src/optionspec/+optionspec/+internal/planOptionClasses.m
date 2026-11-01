function [classFiles, definition] = planOptionClasses(definition, namespace, baseName)
%planOptionClasses Read the definition and render its option classes.
%
%   [classFiles, definition] = optionspec.internal.planOptionClasses(
%   definition, namespace, baseName) accepts an optionspec.Definition or
%   the path of a definition file, derives the base name from the
%   definition id when baseName is "", and returns the classes rendered by
%   optionspec.internal.renderOptionClasses.

    arguments
        definition
        namespace (1,1) string
        baseName (1,1) string
    end

    if ~isa(definition, "optionspec.Definition")
        definition = optionspec.Definition(definition);
    end
    if baseName == ""
        baseName = deriveBaseName(definition.Id);
    end
    if ~isvarname(baseName)
        error("OPTIONSPEC:InvalidBaseName", ...
            "BaseName ""%s"" is not a valid MATLAB name. Pass a BaseName such as ""RigidRegistration"".", baseName)
    end
    classFiles = optionspec.internal.renderOptionClasses(definition, namespace, baseName);
end

function baseName = deriveBaseName(definitionId)
% "example.rigid-registration" gives "RigidRegistration"
    segments = split(definitionId, ".");
    words = split(segments(end), ["-", "_", "/", ":"])';
    words = words(words ~= "");
    words = upper(extractBefore(words, 2)) + extractAfter(words, 1);
    baseName = strjoin(words, "");
end
