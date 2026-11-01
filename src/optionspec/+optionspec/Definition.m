classdef (Sealed) Definition
%Definition A versioned option definition read from a JSON Schema file.
%
%   definition = optionspec.Definition(filePath) reads a definition file
%   and checks it against the optionspec profile of JSON Schema 2020-12.
%   Problems are listed in one OPTIONSPEC:InvalidDefinition error.
%
%   A definition file is a JSON object with these top-level keys:
%     "$schema"     Optional. "https://json-schema.org/draft/2020-12/schema".
%     "$id"         Identifier of the definition, for example
%                   "imagestack.motion-correction".
%     "x-version"   Version of the definition, "MAJOR.MINOR.PATCH".
%     "title", "description"   Optional text.
%     "type"        "object".
%     "properties"  The options, each an object with a "type" and a
%                   "default". An option of type "object" is a group of
%                   options and has "properties" instead of a default.
%
%   Definition properties:
%     Id          - Identifier from "$id"
%     Version     - Version from "x-version"
%     Title       - Title from "title"
%     Description - Description from "description"
%     FilePath    - Path of the definition file
%     Schema      - Canonical schema node of the options (see getOptionSchema)
%
%   Definition methods:
%     defaults        - Default values of all options
%     getOptionSchema - Schema node of one option or group
%
%   See also optionspec.toolboxdir

    properties (SetAccess = private)
        % Id - Identifier of the definition, from "$id"
        Id (1,1) string = ""

        % Version - Version of the definition, from "x-version"
        Version (1,1) string = ""

        % Title - Title of the definition, from "title"
        Title (1,1) string = ""

        % Description - Description of the definition, from "description"
        Description (1,1) string = ""

        % FilePath - Absolute path of the definition file
        FilePath (1,1) string = ""

        % Schema - Canonical schema node of the options
        %   A struct with the fields Type, Nullable, Title, Description,
        %   HasDefault, Default, Enum, Minimum, Maximum, ExclusiveMinimum,
        %   ExclusiveMaximum, MinItems, MaxItems, Items, Properties, Format,
        %   UI and NonFinite. Properties holds one node per option. UI holds
        %   the "x-ui" object as decoded by jsondecode.
        Schema struct = struct.empty
    end

    methods
        function obj = Definition(filePath)
            arguments
                filePath (1,1) string {mustBeFile}
            end

            obj.FilePath = getAbsolutePath(filePath);
            [obj.Schema, header] = optionspec.internal.loadDefinitionFile(obj.FilePath);
            obj.Id = header.Id;
            obj.Version = header.Version;
            obj.Title = header.Title;
            obj.Description = header.Description;
        end

        function values = defaults(obj)
        %defaults Default values of all options.
        %
        %   values = definition.defaults() returns a struct with one field
        %   per option, holding its default. A group of options is a
        %   nested struct.

            values = optionspec.internal.collectDefaults(obj.Schema);
        end

        function optionSchema = getOptionSchema(obj, optionPath)
        %getOptionSchema Schema node of one option or group.
        %
        %   optionSchema = definition.getOptionSchema(optionPath) returns the
        %   canonical schema node of the option at optionPath, a dotted path
        %   such as "Correction.maximumShift". See the Schema property for
        %   the fields of a node.

            arguments
                obj (1,1) optionspec.Definition
                optionPath (1,1) string
            end

            optionSchema = obj.Schema;
            for name = split(optionPath, ".")'
                isGroup = optionSchema.Type == "object";
                if ~isGroup || ~isfield(optionSchema.Properties, name)
                    error("OPTIONSPEC:UnknownOption", ...
                        "Definition ""%s"" has no option ""%s"".", obj.Id, optionPath)
                end
                optionSchema = optionSchema.Properties.(name);
            end
        end
    end
end

function absolutePath = getAbsolutePath(filePath)
    fileInfo = dir(filePath);
    absolutePath = string(fullfile(fileInfo.folder, fileInfo.name));
end
