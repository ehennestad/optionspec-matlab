function result = compareVersions(versionA, versionB)
%compareVersions Compare two semantic versions.
%
%   result = optionspec.internal.compareVersions(versionA, versionB)
%   returns -1 if versionA is older than versionB, 0 if they are equal and
%   1 if versionA is newer.

    arguments
        versionA
        versionB
    end

    numbersA = optionspec.internal.parseVersion(versionA);
    numbersB = optionspec.internal.parseVersion(versionB);
    differenceIndex = find(numbersA ~= numbersB, 1);
    if isempty(differenceIndex)
        result = 0;
    else
        result = sign(numbersA(differenceIndex) - numbersB(differenceIndex));
    end
end
