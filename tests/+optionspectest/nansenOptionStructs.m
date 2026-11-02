function structs = nansenOptionStructs()
%nansenOptionStructs Option structs in the style of NANSEN session methods.
%
%   structs = optionspectest.nansenOptionStructs() returns a struct whose
%   fields are option structs as NANSEN session methods and toolbox
%   wrappers build them, with <name>_ hint fields:
%
%     Normcorre         nansen.wrapper.normcorre.Options.getDefaults, with a
%                       declaration for every option, so that it matches
%                       tests/fixtures/definitions/normcorre.json
%     Suite2p           suite2p options without declarations: types and
%                       ranges are inferred from the values alone
%     Extract           a numeric dropdown and [] defaults hidden as internal
%     Backup            the session method data.backup: enum values with
%                       spaces and a folder path
%     FovManager        fovmanager.App.getDefaultSettings: a nested struct
%     MotionCorrection  nansen.processing.MotionCorrection.getDefaultOptions:
%                       a button, a folder, a transient file name and a
%                       numeric dropdown

    integerAtLeastOne = '(1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(x, 1)}';

    P = struct();
    P.Configuration.numRows = 4;
    P.Configuration.numRows_ = struct('type', 'slider', ...
        'args', {{'Min', 1, 'Max', 16, 'nTicks', 15, 'TooltipPrecision', 0}}, ...
        'declaration', '(1,1) double {mustBeInteger}');
    P.Configuration.numCols = 4;
    P.Configuration.numCols_ = P.Configuration.numRows_;
    P.Configuration.patchOverlap = [32, 32, 16];
    P.Configuration.patchOverlap_ = '(1,3) double {mustBeInteger, mustBeNonnegative}';
    P.Configuration.gridUpsampling = [4, 4, 1];
    P.Configuration.gridUpsampling_ = '(1,3) double {mustBeInteger, mustBeGreaterThanOrEqual(x, 1)}';
    P.Template.initialBatchSize = 100;
    P.Template.initialBatchSize_ = integerAtLeastOne;
    P.Template.updateTemplate = true;
    P.Template.binWidth = 50;
    P.Template.binWidth_ = integerAtLeastOne;
    P.Correction.maximumShift = [40, 40, 5];
    P.Correction.maximumShift_ = '(1,3) double {mustBeInteger, mustBeNonnegative}';
    P.Correction.maximumDeviation = [15, 15, 1];
    P.Correction.maximumDeviation_ = P.Correction.maximumShift_;
    P.Correction.subpixelUpsampling = 50;
    P.Correction.subpixelUpsampling_ = integerAtLeastOne;
    P.Correction.numIterations = 1;
    P.Correction.numIterations_ = integerAtLeastOne;
    P.Correction.shiftsMethod = 'FFT';
    P.Correction.shiftsMethod_ = {'FFT', 'cubic', 'linear'};
    P.Correction.boundary = 'copy';
    P.Correction.boundary_ = {'NaN', 'copy', 'zero', 'template'};
    P.Correction.phaseFlag = false;
    P.Misc.Verbose = false;
    P.Misc.UseParallel = true;
    structs.Normcorre = P;

    S = struct();
    S.CellDetection.cellDiameter = 12;
    S.CellDetection.smoothingSigma = 0.5;
    S.CellDetection.signalExtractionType = 'surround';
    S.CellDetection.signalExtractionType_ = {'surround', 'raw', 'regression'};
    S.CellDetection.refineDetectedRois = true;
    S.Neuropil.radius = inf;
    S.Neuropil.minNeuropilPixels = 400;
    S.Deconvolution.imagingRate = 30;
    structs.Suite2p = S;

    E = struct();
    E.Main.avg_cell_radius = 7;
    E.Main.use_gpu = true;
    E.Main.verbose = 2;
    E.Main.verbose_ = {0, 1, 2};
    E.Computation.num_parallel_cpu_workers = inf;
    E.Fov.movie_mask = [];
    E.Fov.movie_mask_ = 'internal';
    E.CellFind.S_init = [];
    E.CellFind.filter_type = 'butter';
    E.CellFind.filter_type_ = {'butter', 'gauss', 'wiener', 'movavg', 'none'};
    E.Optimization.TOL_sub = 1e-6;
    structs.Extract = E;

    B = struct();
    B.BackupMode = 'merge (no replace)';
    B.BackupMode_ = {'merge (no replace)', 'merge (replace)', 'mirror'};
    B.BackupLocation = '';
    B.BackupLocation_ = 'uigetdir';
    structs.Backup = B;

    F = struct();
    F.hemisphereToLabel = 'left';
    F.hemisphereToLabel_ = {'left', 'right', 'both'};
    F.fovOrientation = struct('flipVertical', false, 'flipHorizontal', false, 'rotationAngle', -90);
    structs.FovManager = F;

    M = struct();
    M.Preprocessing.NumFlybackLines = 0;
    M.Preprocessing.BidirectionalCorrection = 'None';
    M.Preprocessing.BidirectionalCorrection_ = {'None', 'Constant', 'Continuous'};
    M.Preview.run = false;
    M.Preview.run_ = struct('type', 'button', 'args', {{'String', 'Run Preview'}});
    M.Export.FileName = '';
    M.Export.FileName_ = 'transient';
    M.Export.SaveDirectory = '';
    M.Export.SaveDirectory_ = 'uigetdir';
    M.Export.IntensityAdjustmentPercentile = 0.005;
    M.Export.IntensityAdjustmentPercentile_ = {0.05, 0.005, 0};
    M.Export.OutputFormat = 'Tiff';
    M.Export.OutputFormat_ = {'Binary', 'Tiff'};
    structs.MotionCorrection = M;
end
