function keyword = displayKeyword(fieldName)
%displayKeyword Return the JSON spelling of a keyword decoded by jsondecode.
%
%   keyword = optionspec.internal.displayKeyword(fieldName) maps the
%   field names jsondecode gives keywords, such as x_ui and x_ref, back to
%   the keys written in files, such as "x-ui" and "$ref". Other names are
%   returned unchanged.

    arguments
        fieldName (1,1) string
    end

    fieldNames = ["x_schema", "x_id", "x_ref", "x_comment", "x_version", "x_ui", "x_nonfinite"];
    keywords = ["$schema", "$id", "$ref", "$comment", "x-version", "x-ui", "x-nonfinite"];
    isMatch = fieldName == fieldNames;
    if any(isMatch)
        keyword = keywords(isMatch);
    else
        keyword = fieldName;
    end
end
