function rootDir = toolboxdir()
    % TOOLBOXDIR Return the root directory of the toolbox
    %
    %   ROOTDIR = TOOLBOXDIR() returns the folder that contains the
    %   +optionspec namespace folder: the installation folder of the toolbox,
    %   or src/optionspec in a clone of the repository.
    %
    %   Example:
    %       rootDir = optionspec.toolboxdir()
    %
    %   See also optionspec.toolboxversion

    namespaceDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(namespaceDir);
end
