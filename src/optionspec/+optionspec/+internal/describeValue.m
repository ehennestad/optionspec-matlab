function description = describeValue(value)
%describeValue Describe a value briefly for an error message.
%
%   description = optionspec.internal.describeValue(value) returns text
%   such as "FFT" (quoted), 3, true, or "a 2x3 double array".

    if ischar(value) && (isrow(value) || isempty(value))
        description = """" + string(value) + """";
    elseif isstring(value) && isscalar(value) && ~ismissing(value)
        description = """" + value + """";
    elseif islogical(value) && isscalar(value)
        description = string(mat2str(value));
    elseif isnumeric(value) && isscalar(value) && isreal(value)
        description = string(num2str(value, 10));
    else
        sizeText = strjoin(string(size(value)), "x");
        description = sprintf("a %s %s array", sizeText, class(value));
    end
end
