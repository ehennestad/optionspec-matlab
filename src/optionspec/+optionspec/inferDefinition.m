function jsonText = inferDefinition(options, header)
%inferDefinition Write a definition for an options struct.
%
%   jsonText = optionspec.inferDefinition(options, Id=id) returns the JSON
%   text of a definition, version "1.0.0", whose options and defaults are
%   the fields and values of the struct options. Save it to a file and read
%   it with optionspec.Definition, or let optionspec.updateDefinition do both.
%
%   Inference from values:
%     logical scalar               boolean
%     numeric scalar               number, which allows Inf, -Inf and NaN as
%                                  a double does (integer for integer classes)
%     numeric or logical vector    array of any length
%     numeric or logical matrix    matrix
%     char, string scalar          string
%     string array, cellstr        array of strings
%     struct                       group
%     []                           array of numbers or null, default null
%   Write mustBeFinite in a declaration (below) to rule out Inf and NaN.
%   Other values, such as function handles, mixed cell arrays or objects,
%   are an OPTIONSPEC:CannotInferDefinition error.
%
%   A value does not say whether a number is an integer, whether a vector
%   has a fixed length, or what [] holds. Hints say so. A field named
%   <name>_ next to <name> is a hint, as in NANSEN option structs:
%     {'a', 'b'} or {0, 1, 2}      enum, shown as a dropdown
%     struct('type', 'slider', 'args', {{'Min', 1, 'Max', 16}})
%                                  minimum and maximum, shown as a slider
%     struct('type', 'button'), struct('type', 'togglebutton'),
%     struct('type', 'multilinechar')   the widget only
%     'uigetdir'                   a folder path
%     'uigetfile', 'uiputfile'     a file path
%     'internal', 'ignore'         a hidden option
%     '(1,3) double {mustBeInteger, mustBePositive}'
%                                  a declaration in the syntax of an arguments
%                                  block: size, class and validators (see
%                                  optionspec.internal.parseDeclaration)
%   A struct hint can hold a declaration too, in a field "declaration":
%     struct('type', 'slider', 'args', {{'Min', 1, 'Max', 16}}, ...
%         'declaration', '(1,1) double {mustBeInteger}')
%   As in an arguments block, a declared double allows Inf and NaN unless
%   mustBeFinite or mustBeInteger rules them out. With a declaration, []
%   means "not set" for a scalar or fixed size, and an empty array otherwise.
%
%   Name-value arguments:
%     Id           - "$id" of the definition (required)
%     Version      - "x-version". Default: "1.0.0"
%     Title        - "title". Default: ""
%     Description  - "description". Default: ""
%     Descriptions - Struct of the shape of options whose fields hold the
%                    description of each option, such as the comments
%                    NANSEN reads with OptionsManager.extractStructDescriptions.
%                    Default: struct()
%
%   See also optionspec.checkDefinition, optionspec.updateDefinition

    arguments
        options (1,1) struct
        header.Id (1,1) string {mustBeNonzeroLengthText}
        header.Version (1,1) string = "1.0.0"
        header.Title (1,1) string = ""
        header.Description (1,1) string = ""
        header.Descriptions (1,1) struct = struct()
    end

    optionspec.internal.parseVersion(header.Version);
    rootNode = optionspec.internal.inferRootNode(options, header.Descriptions);
    jsonText = optionspec.internal.renderDefinition(header, rootNode);
end
