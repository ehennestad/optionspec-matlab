function data = decodeJson(jsonText, sourceName)
%decodeJson Decode JSON text after checking that every object key is allowed.
%
%   data = optionspec.internal.decodeJson(jsonText, sourceName) decodes
%   jsonText with jsondecode. jsondecode renames keys that are not valid
%   MATLAB names (for example "my-option" becomes my_option), so a key
%   that is neither a valid MATLAB name nor one of the keywords below
%   is an error rather than a silently renamed field. sourceName names
%   the text in error messages.
%
%   jsondecode also reads the tokens NaN, Infinity and -Infinity, which
%   are not JSON and which strict parsers in other languages reject. They
%   are an error; documents write non-finite numbers as the strings
%   "NaN", "Inf" and "-Inf".
%
%   Allowed keywords: "$schema", "$id", "$ref", "$comment", "x-version",
%   "x-ui" and "x-nonfinite". jsondecode returns them as the fields
%   x_schema, x_id, x_ref, x_comment, x_version, x_ui and x_nonfinite.

    arguments
        jsonText {mustBeTextScalar}
        sourceName (1,1) string = "JSON text"
    end

    jsonText = char(jsonText);
    invalidKeys = findInvalidKeys(jsonText);
    if ~isempty(invalidKeys)
        error("OPTIONSPEC:InvalidKey", ...
            "%s has keys that are not valid MATLAB names: %s. " + ...
            "Use names that start with a letter and contain only letters, digits and underscores.", ...
            sourceName, strjoin("""" + invalidKeys + """", ", "))
    end

    textWithoutStrings = regexprep(jsonText, '"(?:[^"\\]|\\.)*"', '""');
    if ~isempty(regexp(textWithoutStrings, '(?<![\w.])(NaN|Infinity)(?![\w.])', "once"))
        error("OPTIONSPEC:InvalidJson", ...
            "%s is not valid JSON: it uses NaN or Infinity. Write them as the strings ""NaN"", ""Inf"" and ""-Inf"".", ...
            sourceName)
    end

    try
        data = jsondecode(jsonText);
    catch exception
        error("OPTIONSPEC:InvalidJson", "%s is not valid JSON: %s", ...
            sourceName, exception.message)
    end
end

function invalidKeys = findInvalidKeys(jsonText)
% Every double quote outside a string starts a string, so matching string
% tokens from left to right finds exactly the strings of the text. A string
% followed by a colon is an object key.
    keywords = ["$schema", "$id", "$ref", "$comment", "x-version", "x-ui", "x-nonfinite"];

    [tokenStarts, tokenEnds] = regexp(jsonText, '"(?:[^"\\]|\\.)*"', "start", "end");
    invalidKeys = strings(1, 0);
    textLength = numel(jsonText);
    for i = 1:numel(tokenStarts)
        nextIndex = tokenEnds(i) + 1;
        while nextIndex <= textLength && isspace(jsonText(nextIndex))
            nextIndex = nextIndex + 1;
        end
        isKey = nextIndex <= textLength && jsonText(nextIndex) == ':';
        if isKey
            key = jsonText(tokenStarts(i)+1:tokenEnds(i)-1);
            if ~(isvarname(key) || any(key == keywords))
                invalidKeys(end+1) = string(key); %#ok<AGROW> Keys are few and rarely invalid
            end
        end
    end
    invalidKeys = unique(invalidKeys, "stable");
end
