function data = readJsonFile(filePath)
%readJsonFile Read and decode a JSON file whose keys are valid MATLAB names.
%
%   data = optionspec.internal.readJsonFile(filePath) reads filePath as
%   UTF-8 and decodes it with optionspec.internal.decodeJson.

    arguments
        filePath (1,1) string
    end

    if ~isfile(filePath)
        error("OPTIONSPEC:FileNotFound", "File ""%s"" does not exist.", filePath)
    end
    fileId = fopen(filePath, "r", "n", "UTF-8");
    closeFile = onCleanup(@() fclose(fileId));
    jsonText = fread(fileId, [1, Inf], "*char");
    data = optionspec.internal.decodeJson(jsonText, "File """ + filePath + """");
end
