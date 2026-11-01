%% Options for a processing step with optionspec
% This example reads the definition of a registration step, changes some
% options, saves the values used as a value document, and reads a document
% written under an older version of the definition.
%
% The definition files are in the definitions folder next to this script:
%
% * stack.json holds the options shared by every step, in a Stack group.
% * rigid-registration.json holds the options of the registration step, in
%   a Registration group, and includes stack.json with "allOf".
% * rigid-registration.migrations.json upgrades values of version 1 to
%   version 2.

%% Read the definition
exampleFolder = fileparts(mfilename("fullpath"));
definition = optionspec.Definition(fullfile(exampleFolder, "definitions", "rigid-registration.json"));
disp(definition.Id + " " + definition.Version)
disp("Includes: " + strjoin(definition.Includes, ", "))

%% Default values
% The values are a struct. Options of the step come first, then the
% included stack options. The registration step narrows the channel modes
% of the stack to "batch" and "serial".
values = definition.defaults();
disp(values.Registration)
disp(values.Stack)

%% Change options
% resolve fills in defaults for the options a struct does not set, so a
% preset only lists what it changes. Invalid values are listed in one error.
preset = struct("Registration", struct("MaxShift", 15), ...
    "Stack", struct("TimepointInterval", [1, 1000]));
values = definition.resolve(preset);

invalidValues = values;
invalidValues.Registration.UpsampleFactor = 0.5;
invalidValues.Stack.ChannelProcessingMode = 'single';
[isValid, problems] = definition.isValid(invalidValues);
disp(problems')

%% Save the values used for a result
% The value document records the definition and its version next to the
% values. Inf, -Inf and NaN are written as text, because JSON has no
% numbers for them.
documentFile = fullfile(tempdir, "rigid-registration-options.json");
definition.writeDocument(documentFile, values, Overwrite=true);
disp(fileread(documentFile))

%% Read values back
% isequaln, unlike isequal, treats the NaN of ChunkLength as equal to itself
[valuesRead, header] = definition.readDocument(documentFile);
disp(isequaln(valuesRead, values))

%% Read a document written under version 1
% Version 1 named UpsampleFactor SubpixelFactor and had no Taper option.
% The migration renames the option and sets Taper to false, then defaults
% fill in the options the document does not set.
[upgradedValues, oldHeader] = definition.readDocument( ...
    fullfile(exampleFolder, "rigid-registration-1.0.0.json"));
disp(oldHeader.Version)
disp(upgradedValues.Registration)

%% Schema of one option
% getOptionSchema returns the canonical schema of an option, for example
% to build a user interface from its type, range and "x-ui" hints.
optionSchema = definition.getOptionSchema("Registration.Taper");
disp(optionSchema.Description)
disp(optionSchema.UI.widget)

delete(documentFile)
