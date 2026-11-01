function problems = checkGeneratedClasses(definition, outputFolder, options)
%checkGeneratedClasses List generated option classes that do not match their definition.
%
%   problems = optionspec.checkGeneratedClasses(definition, outputFolder)
%   generates the option classes of definition in memory, as
%   optionspec.generateClasses would, and compares them with the files in
%   outputFolder. It returns a string array with one entry per file that
%   is missing or differs, and per file in the same folders that
%   generateClasses wrote from this definition but would no longer write.
%   An empty result means the files match.
%
%   Use it in a test of the toolbox that holds the classes, so that a
%   changed definition without regenerated classes fails:
%
%       testCase.verifyEmpty(optionspec.checkGeneratedClasses( ...
%           definitionFile, sourceFolder, Namespace="imagestack.options"))
%
%   Name-value arguments Namespace and BaseName are those passed to
%   optionspec.generateClasses.
%
%   See also optionspec.generateClasses

    arguments
        definition
        outputFolder (1,1) string
        options.Namespace (1,1) string = ""
        options.BaseName (1,1) string = ""
    end

    [classFiles, definition] = optionspec.internal.planOptionClasses( ...
        definition, options.Namespace, options.BaseName);

    problems = strings(1, 0);
    expectedPaths = strings(1, numel(classFiles));
    for i = 1:numel(classFiles)
        filePath = string(fullfile(outputFolder, classFiles(i).RelativePath));
        expectedPaths(i) = filePath;
        if ~isfile(filePath)
            problems(end+1) = sprintf("%s: missing.", filePath); %#ok<AGROW>
        elseif readText(filePath) ~= classFiles(i).Text
            problems(end+1) = sprintf("%s: differs from definition ""%s"" version %s.", ...
                filePath, definition.Id, definition.Version); %#ok<AGROW>
        end
    end

    marker = sprintf("from definition ""%s"",", definition.Id);
    for folder = unique(arrayfun(@(path) string(fileparts(path)), expectedPaths))
        for fileInfo = dir(fullfile(folder, "*.m"))'
            filePath = string(fullfile(fileInfo.folder, fileInfo.name));
            if ~any(filePath == expectedPaths) && optionspec.internal.isGeneratedClassFile(filePath) ...
                    && contains(readText(filePath), marker)
                problems(end+1) = sprintf("%s: generated from definition ""%s"" but no longer generated.", ...
                    filePath, definition.Id); %#ok<AGROW>
            end
        end
    end
end

function text = readText(filePath)
    fileId = fopen(filePath, "r", "n", "UTF-8");
    closeFile = onCleanup(@() fclose(fileId));
    text = string(fread(fileId, [1, Inf], "*char"));
end
