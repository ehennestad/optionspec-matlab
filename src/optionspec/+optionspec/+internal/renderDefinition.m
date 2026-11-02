function jsonText = renderDefinition(header, rootNode)
%renderDefinition Write a definition file from a header and a canonical root node.
%
%   jsonText = optionspec.internal.renderDefinition(header, rootNode)
%   returns the JSON text of a definition. header is a struct with the
%   fields Id, Version, Title and Description; rootNode is a finalized
%   group node without included definitions. Keys are written in a fixed
%   order, so the same definition always gives the same text.

    arguments
        header (1,1) struct
        rootNode (1,1) struct
    end

    definition = struct();
    definition.(placeholder("$schema")) = 'https://json-schema.org/draft/2020-12/schema';
    definition.(placeholder("$id")) = char(header.Id);
    definition.(placeholder("x-version")) = char(header.Version);
    if header.Title ~= ""
        definition.title = char(header.Title);
    end
    if header.Description ~= ""
        definition.description = char(header.Description);
    end
    definition.type = 'object';
    definition.properties = renderProperties(rootNode);

    jsonText = string(jsonencode(definition, PrettyPrint=true));
    for keyword = ["$schema", "$id", "x-version", "x-ui", "x-nonfinite"]
        jsonText = replace(jsonText, """" + placeholder(keyword) + """", """" + keyword + """");
    end
    jsonText = jsonText + newline;
end

function properties = renderProperties(node)
    properties = struct();
    for name = string(fieldnames(node.Properties))'
        if startsWith(name, placeholderPrefix())
            error("OPTIONSPEC:ReservedOptionName", "Option names cannot start with ""%s"".", placeholderPrefix())
        end
        properties.(name) = renderNode(node.Properties.(name), false);
    end
end

function rendered = renderNode(node, isItemsNode)
    rendered = struct();
    if node.Nullable
        rendered.type = {char(node.Type), 'null'};
    else
        rendered.type = char(node.Type);
    end
    if node.Title ~= ""
        rendered.title = char(node.Title);
    end
    if node.Description ~= ""
        rendered.description = char(node.Description);
    end
    if node.Type == "object"
        rendered.properties = renderProperties(node);
        return
    end

    valueNode = node;
    valueNode.Nullable = false;
    if ~isempty(node.Enum)
        rendered.enum = cellfun(@(value) optionspec.internal.encodeValue(value, valueNode), ...
            node.Enum, "UniformOutput", false);
    end
    for field = ["Minimum", "Maximum", "ExclusiveMinimum", "ExclusiveMaximum", "MinItems", "MaxItems"]
        if ~isempty(node.(field))
            rendered.(lower(extractBefore(field, 2)) + extractAfter(field, 1)) = node.(field);
        end
    end
    if ~isempty(node.Items)
        rendered.items = renderNode(node.Items, true);
    end
    if ~isempty(node.NonFinite)
        rendered.(placeholder("x-nonfinite")) = cellstr(node.NonFinite);
    end
    if node.Format ~= ""
        rendered.format = char(node.Format);
    end
    if ~isItemsNode
        rendered.default = optionspec.internal.encodeValue(node.Default, node);
    end
    if ~isempty(node.UI)
        rendered.(placeholder("x-ui")) = node.UI;
    end
end

function name = placeholder(keyword)
% A field name for a keyword that is not a valid MATLAB name, replaced by
% the keyword after jsonencode. renderProperties rejects option names with
% this prefix.
    name = placeholderPrefix() + regexprep(keyword, '\W', '_');
end

function prefix = placeholderPrefix()
    prefix = "zzOptionspecKeyword_";
end
