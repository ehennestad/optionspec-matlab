function values = collectDefaults(node)
%collectDefaults Return the default values of a finalized schema node.
%
%   values = optionspec.internal.collectDefaults(node) returns the default
%   of an option, or for a group a struct with the defaults of its options.

    arguments
        node (1,1) struct
    end

    if node.Type == "object"
        values = struct();
        for name = string(fieldnames(node.Properties))'
            values.(name) = optionspec.internal.collectDefaults(node.Properties.(name));
        end
    else
        values = node.Default;
    end
end
