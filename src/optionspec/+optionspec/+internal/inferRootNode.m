function rootNode = inferRootNode(options, descriptions)
%inferRootNode Infer and finalize the root node of an options struct.
%
%   rootNode = optionspec.internal.inferRootNode(options, descriptions)
%   infers the node with optionspec.internal.inferNode and checks it with
%   optionspec.internal.finalizeNode. Every problem is listed in one
%   OPTIONSPEC:CannotInferDefinition error.

    arguments
        options (1,1) struct
        descriptions (1,1) struct
    end

    [rootNode, issues] = optionspec.internal.inferNode(options, descriptions, "");
    if isempty(issues)
        [rootNode, issues] = optionspec.internal.finalizeNode(rootNode, "");
    end
    if ~isempty(issues)
        optionspec.internal.throwIssues("OPTIONSPEC:CannotInferDefinition", ...
            "Cannot infer a definition from the options struct:", issues)
    end
end
