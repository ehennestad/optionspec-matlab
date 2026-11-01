function header = readDocumentHeader(document)
%readDocumentHeader Check the keys of a decoded value document and return its header.
%
%   header = optionspec.internal.readDocumentHeader(document) checks that
%   document, as returned by jsondecode, has exactly the keys "optionspec",
%   "definition", "version" and "values", and returns a struct with the
%   fields Definition and Version.

    arguments
        document
    end

    expectedKeys = ["optionspec", "definition", "version", "values"];
    issues = strings(1, 0);
    if ~(isstruct(document) && isscalar(document))
        issues(end+1) = "A value document must be a JSON object.";
    else
        keys = string(fieldnames(document))';
        for key = setdiff(expectedKeys, keys, "stable")
            issues(end+1) = sprintf("Key ""%s"" is missing.", key); %#ok<AGROW>
        end
        for key = setdiff(keys, expectedKeys, "stable")
            issues(end+1) = sprintf("Key ""%s"" is not part of a value document.", key); %#ok<AGROW>
        end
    end
    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:InvalidDocument", "Value document is not valid:", issues)
    end

    formatVersion = optionspec.internal.documentFormatVersion();
    if ~isequal(document.optionspec, formatVersion)
        issues(end+1) = sprintf("""optionspec"" must be ""%s"".", formatVersion);
    end
    if ~(ischar(document.definition) && isrow(document.definition))
        issues(end+1) = """definition"" must be a string.";
    end
    if ~isVersion(document.version)
        issues(end+1) = """version"" must be of the form MAJOR.MINOR.PATCH.";
    end
    if ~(isstruct(document.values) && isscalar(document.values))
        issues(end+1) = """values"" must be a JSON object.";
    end
    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:InvalidDocument", "Value document is not valid:", issues)
    end

    header = struct("Definition", string(document.definition), "Version", string(document.version));
end

function tf = isVersion(value)
    try
        optionspec.internal.parseVersion(value);
        tf = true;
    catch exception
        if exception.identifier ~= "OPTIONSPEC:InvalidVersion"
            rethrow(exception)
        end
        tf = false;
    end
end
