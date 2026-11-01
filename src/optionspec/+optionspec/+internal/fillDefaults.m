function values = fillDefaults(values, node)
%fillDefaults Add the default of every option that values does not set.
%
%   values = optionspec.internal.fillDefaults(values, node) adds missing
%   options of the group node to the struct values, recursing into
%   groups. Options that values sets, including unknown ones, are kept
%   as they are, so that validation can report them.

    arguments
        values
        node (1,1) struct
    end

    if ~(isstruct(values) && isscalar(values))
        return
    end
    for name = string(fieldnames(node.Properties))'
        optionNode = node.Properties.(name);
        if ~isfield(values, name)
            values.(name) = optionspec.internal.collectDefaults(optionNode);
        elseif optionNode.Type == "object"
            values.(name) = optionspec.internal.fillDefaults(values.(name), optionNode);
        end
    end
end
