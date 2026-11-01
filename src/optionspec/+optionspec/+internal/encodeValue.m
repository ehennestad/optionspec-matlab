function jsonValue = encodeValue(value, node)
%encodeValue Convert a canonical value to the form jsonencode writes as intended.
%
%   jsonValue = optionspec.internal.encodeValue(value, node) takes a value
%   in canonical form (see optionspec.internal.normalizeValue) and returns
%   a value that jsonencode writes as the JSON of the value document:
%
%     - null becomes NaN, which jsonencode writes as null. Non-finite
%       numbers are converted to text first, so no other NaN remains.
%     - Inf, -Inf and NaN become the text "Inf", "-Inf" and "NaN".
%     - Arrays become cell arrays, so that jsonencode writes a one-element
%       array as [x] rather than x. A matrix becomes a cell array of rows.

    arguments
        value
        node (1,1) struct
    end

    if node.Nullable && isa(value, "double") && isequal(size(value), [0, 0])
        jsonValue = NaN;
        return
    end

    switch node.Type
        case "object"
            jsonValue = struct();
            for name = string(fieldnames(node.Properties))'
                jsonValue.(name) = optionspec.internal.encodeValue(value.(name), node.Properties.(name));
            end
        case "array"
            if node.Items.Type == "array"
                jsonValue = cell(1, size(value, 1));
                for i = 1:size(value, 1)
                    jsonValue{i} = optionspec.internal.encodeValue(value(i, :), node.Items);
                end
            else
                jsonValue = cell(1, numel(value));
                for i = 1:numel(value)
                    jsonValue{i} = optionspec.internal.encodeValue(value(i), node.Items);
                end
            end
        case {"integer", "number"}
            jsonValue = encodeNumber(value);
        case "string"
            jsonValue = char(value);
        otherwise
            jsonValue = value;
    end
end

function jsonValue = encodeNumber(value)
    if isnan(value)
        jsonValue = 'NaN';
    elseif value == Inf
        jsonValue = 'Inf';
    elseif value == -Inf
        jsonValue = '-Inf';
    else
        jsonValue = value;
    end
end
