function filePath = writeDefinition(folder, fileName, properties, topLevel)
%writeDefinition Write a definition file for a test.
%
%   filePath = optionspectest.writeDefinition(folder, fileName, properties)
%   writes a definition with the id "test.<name>", version "1.0.0" and the
%   given properties, a JSON object as text.
%
%   filePath = optionspectest.writeDefinition(..., topLevel) adds the
%   top-level members in topLevel, JSON text without the outer braces, or
%   replaces the whole file when topLevel starts with "{" or "[".

    arguments
        folder (1,1) string
        fileName (1,1) string
        properties (1,1) string
        topLevel (1,1) string = ""
    end

    [~, name] = fileparts(fileName);
    if startsWith(topLevel, ["{", "["])
        jsonText = topLevel;
    else
        jsonText = sprintf('{"$id": "test.%s", "x-version": "1.0.0", "type": "object", "properties": %s', ...
            name, properties);
        if topLevel ~= ""
            jsonText = jsonText + ", " + topLevel;
        end
        jsonText = jsonText + "}";
    end
    filePath = fullfile(folder, fileName);
    fileId = fopen(filePath, "w", "n", "UTF-8");
    fwrite(fileId, jsonText, "char");
    fclose(fileId);
end
