function values = upsampleFactorToGridUpsampling(values)
%upsampleFactorToGridUpsampling Migration hook of the normcorre fixture, version 2 to 3.
%
%   Version 2 upsampled the patch grid by one factor in y and x and not in
%   z. Version 3 has a factor per dimension, so the factor f becomes
%   [f, f, 1]. A migrations file names this function in a "function"
%   operation, because no declarative operation computes a new value.

    if isfield(values, "Configuration") && isfield(values.Configuration, "upsampleFactor")
        factor = values.Configuration.upsampleFactor;
        values.Configuration.gridUpsampling = [factor, factor, 1];
        values.Configuration = rmfield(values.Configuration, "upsampleFactor");
    end
end
