function versionStr = toolboxversion()
    % TOOLBOXVERSION Return the version number of the toolbox
    %
    %   VERSIONSTR = TOOLBOXVERSION() returns the version number written in
    %   Contents.m, for example '1.2.3', or '1.2.3.4' when it has a build
    %   number.
    %
    %   Example:
    %       versionStr = optionspec.toolboxversion()
    %
    %   See also optionspec.toolboxdir

    rootPath = fileparts(fileparts(mfilename('fullpath')));
    contentsFile = fullfile(rootPath, 'Contents.m');

    fileStr = fileread(contentsFile);
    versionMatch = regexp(fileStr, 'Version (?<number>\d+\.\d+\.\d+(?:\.\d+)?)', 'names', 'once');

    if isempty(versionMatch)
        error('OPTIONSPEC:Version:VersionNotFound', ...
            'No version was detected for this %s installation.', ...
            'OptionSpec')
    end
    versionStr = versionMatch.number;
end
