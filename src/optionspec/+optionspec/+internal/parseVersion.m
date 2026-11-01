function versionNumbers = parseVersion(versionText)
%parseVersion Split a semantic version "MAJOR.MINOR.PATCH" into three numbers.
%
%   versionNumbers = optionspec.internal.parseVersion(versionText) returns
%   [major, minor, patch] as a 1x3 double. Pre-release and build suffixes
%   are not part of the format and are an error.

    arguments
        versionText
    end

    isText = ischar(versionText) || (isstring(versionText) && isscalar(versionText));
    tokens = {};
    if isText
        tokens = regexp(char(versionText), '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$', "tokens", "once");
    end
    if isempty(tokens)
        error("OPTIONSPEC:InvalidVersion", ...
            "Version must be text of the form MAJOR.MINOR.PATCH, for example ""1.2.0"".")
    end
    versionNumbers = str2double(tokens);
end
