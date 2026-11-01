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
%     "allOf"       Optional. Other definitions to include, as
%                   [{"$ref": "<file>"}, ...] with paths relative to this
%                   file. Their options follow the options of this file. An
%                   included option can be redeclared to change its default
%                   or to narrow its allowed values, but not its type.
%
%   Definition properties:
%     Id          - Identifier from "$id"
%     Version     - Version from "x-version"
%     Title       - Title from "title"
%     Description - Description from "description"
%     FilePath    - Path of the definition file
%     Includes    - Included definitions, as "<id>@<version>"
%     MigrationFile - Path of the migrations file, or ""
%     Schema      - Canonical schema node of the options (see getOptionSchema)
%
%   Definition methods:
%     defaults        - Default values of all options
%     validate        - Check values and return them in canonical form
%     resolve         - Fill in defaults for missing options, then validate
%     isValid         - True if values are valid
%     encode          - Encode values as the JSON text of a value document
%     decode          - Read values from the JSON text of a value document
%     writeDocument   - Write values to a value document file
%     readDocument    - Read values from a value document file
%     upgrade         - Bring values of an older version up to this version
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

        % Includes - Included definitions, as "<id>@<version>"
        Includes (1,:) string = strings(1, 0)

        % MigrationFile - Path of the migrations file, or "" if there is none
        %   The migrations file of "<name>.json" is "<name>.migrations.json"
        %   in the same folder.
        MigrationFile (1,1) string = ""

        % Schema - Canonical schema node of the options
        %   A struct with the fields Type, Nullable, Title, Description,
        %   HasDefault, Default, Enum, Minimum, Maximum, ExclusiveMinimum,
        %   ExclusiveMaximum, MinItems, MaxItems, Items, Properties, Format,
        %   UI and NonFinite. Properties holds one node per option. UI holds
        %   the "x-ui" object as decoded by jsondecode.
        Schema struct = struct.empty
    end

    properties (Access = private)
        % Migrations - Steps read from the migrations file
        Migrations struct = struct("From", {}, "To", {}, "Description", {}, "Operations", {})
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
            obj.Includes = header.Includes;

            [folder, name] = fileparts(obj.FilePath);
            migrationFile = fullfile(folder, name + ".migrations.json");
            if isfile(migrationFile)
                obj.MigrationFile = migrationFile;
                currentVersion = optionspec.internal.parseVersion(obj.Version);
                obj.Migrations = optionspec.internal.loadMigrations( ...
                    migrationFile, obj.Id, currentVersion(1));
            end
        end

        function values = defaults(obj)
        %defaults Default values of all options.
        %
        %   values = definition.defaults() returns a struct with one field
        %   per option, holding its default. A group of options is a
        %   nested struct.

            values = optionspec.internal.collectDefaults(obj.Schema);
        end

        function values = validate(obj, values)
        %validate Check values against the definition and return them in canonical form.
        %
        %   values = definition.validate(values) checks that the struct
        %   values sets every option of the definition, and no other, to a
        %   valid value. It returns the values in canonical form, for
        %   example row vectors and char text; see
        %   optionspec.internal.normalizeValue for the forms. Every problem
        %   is listed in one OPTIONSPEC:InvalidValues error.

            arguments
                obj (1,1) optionspec.Definition
                values
            end

            [values, issues] = optionspec.internal.normalizeValue(values, obj.Schema, "");
            if ~isempty(issues)
                optionspec.internal.throwIssues("OPTIONSPEC:InvalidValues", ...
                    sprintf("Values do not match definition ""%s"" %s:", obj.Id, obj.Version), issues)
            end
        end

        function values = resolve(obj, values)
        %resolve Fill in defaults for missing options, then validate.
        %
        %   values = definition.resolve(values) adds the default of every
        %   option that the struct values does not set and validates the
        %   result as definition.validate does. Use it for partial values,
        %   such as a preset that changes a few options.
        %
        %   values = definition.resolve() returns the validated defaults.

            arguments
                obj (1,1) optionspec.Definition
                values = struct()
            end

            values = optionspec.internal.fillDefaults(values, obj.Schema);
            values = obj.validate(values);
        end

        function jsonText = encode(obj, values)
        %encode Encode values as the JSON text of a value document.
        %
        %   jsonText = definition.encode(values) validates the struct values
        %   as definition.validate does and returns the text of a value
        %   document:
        %
        %     {
        %       "optionspec": "1",
        %       "definition": "<id>",
        %       "version": "<version>",
        %       "values": {...}
        %     }
        %
        %   Inf, -Inf and NaN are written as the text "Inf", "-Inf" and
        %   "NaN", and empty values of nullable options as null.

            arguments
                obj (1,1) optionspec.Definition
                values
            end

            values = obj.validate(values);
            document = struct( ...
                "optionspec", optionspec.internal.documentFormatVersion(), ...
                "definition", char(obj.Id), ...
                "version", char(obj.Version), ...
                "values", optionspec.internal.encodeValue(values, obj.Schema));
            jsonText = string(jsonencode(document, PrettyPrint=true)) + newline;
        end

        function [values, header] = decode(obj, jsonText)
        %decode Read values from the JSON text of a value document.
        %
        %   [values, header] = definition.decode(jsonText) checks that the
        %   document was written for this definition, fills in defaults
        %   for options it does not set and validates the values. header is
        %   a struct with the fields Definition and Version of the document.
        %
        %   A document written under an older minor version of the same
        %   major version is read with defaults for the options added since.
        %   A document written under a newer version is an
        %   OPTIONSPEC:NewerVersion error.

            arguments
                obj (1,1) optionspec.Definition
                jsonText {mustBeTextScalar}
            end

            document = optionspec.internal.decodeJson(jsonText, "Value document");
            header = optionspec.internal.readDocumentHeader(document);
            if header.Definition ~= obj.Id
                error("OPTIONSPEC:DefinitionMismatch", ...
                    "Value document was written for definition ""%s"", not ""%s"".", ...
                    header.Definition, obj.Id)
            end
            values = obj.upgrade(document.values, header.Version);
        end

        function writeDocument(obj, filePath, values, options)
        %writeDocument Write values to a value document file.
        %
        %   definition.writeDocument(filePath, values) validates values and
        %   writes them as a value document (see encode) to filePath, in
        %   UTF-8. An existing file is an OPTIONSPEC:FileExists error.
        %
        %   definition.writeDocument(..., Overwrite=true) replaces an
        %   existing file.

            arguments
                obj (1,1) optionspec.Definition
                filePath (1,1) string
                values
                options.Overwrite (1,1) logical = false
            end

            if isfile(filePath) && ~options.Overwrite
                error("OPTIONSPEC:FileExists", ...
                    "File ""%s"" exists. Use Overwrite=true to replace it.", filePath)
            end
            jsonText = obj.encode(values);

            [fileId, message] = fopen(filePath, "w", "n", "UTF-8");
            if fileId == -1
                error("OPTIONSPEC:CannotWriteFile", "Cannot write file ""%s"": %s", filePath, message)
            end
            closeFile = onCleanup(@() fclose(fileId));
            fwrite(fileId, jsonText, "char");
        end

        function [values, header] = readDocument(obj, filePath)
        %readDocument Read values from a value document file.
        %
        %   [values, header] = definition.readDocument(filePath) reads the
        %   file and decodes it as definition.decode does.

            arguments
                obj (1,1) optionspec.Definition
                filePath (1,1) string
            end

            if ~isfile(filePath)
                error("OPTIONSPEC:FileNotFound", "File ""%s"" does not exist.", filePath)
            end
            fileId = fopen(filePath, "r", "n", "UTF-8");
            closeFile = onCleanup(@() fclose(fileId));
            jsonText = fread(fileId, [1, Inf], "*char");
            [values, header] = obj.decode(jsonText);
        end

        function values = upgrade(obj, values, fromVersion)
        %upgrade Bring values written under an older version up to this version.
        %
        %   values = definition.upgrade(values, fromVersion) returns values,
        %   a struct written under definition version fromVersion, as
        %   values of this version. Values of an older major version are
        %   passed through the migrations in MigrationFile, one major
        %   version at a time. Then defaults are filled in for missing
        %   options and the result is validated.
        %
        %   Values of a newer major or minor version are an
        %   OPTIONSPEC:NewerVersion error, and an older major version with
        %   no migration an OPTIONSPEC:MissingMigration error.

            arguments
                obj (1,1) optionspec.Definition
                values
                fromVersion (1,1) string
            end

            fromNumbers = optionspec.internal.parseVersion(fromVersion);
            currentNumbers = optionspec.internal.parseVersion(obj.Version);
            isNewer = fromNumbers(1) > currentNumbers(1) ...
                || (fromNumbers(1) == currentNumbers(1) && fromNumbers(2) > currentNumbers(2));
            if isNewer
                error("OPTIONSPEC:NewerVersion", ...
                    "Values were written under version %s of definition ""%s"", " + ...
                    "which is newer than version %s. Update the definition to read them.", ...
                    fromVersion, obj.Id, obj.Version)
            end
            if fromNumbers(1) < currentNumbers(1)
                values = optionspec.internal.applyMigrations(values, obj.Migrations, ...
                    fromNumbers(1), currentNumbers(1), obj.Id);
            end
            values = obj.resolve(values);
        end

        function [tf, issues] = isValid(obj, values)
        %isValid True if values set every option of the definition to a valid value.
        %
        %   [tf, issues] = definition.isValid(values) returns true or
        %   false, and a string array with one entry per problem.

            arguments
                obj (1,1) optionspec.Definition
                values
            end

            [~, issues] = optionspec.internal.normalizeValue(values, obj.Schema, "");
            tf = isempty(issues);
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
