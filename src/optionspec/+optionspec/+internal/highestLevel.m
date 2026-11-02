function level = highestLevel(changes)
%highestLevel Highest version level of a list of changes.
%
%   level = optionspec.internal.highestLevel(changes) returns "none",
%   "patch", "minor" or "major" for the changes returned by
%   optionspec.internal.compareNodes.

    arguments
        changes struct
    end

    levels = ["none", "patch", "minor", "major"];
    rank = 1;
    for change = changes
        rank = max(rank, find(levels == change.Level));
    end
    level = levels(rank);
end
