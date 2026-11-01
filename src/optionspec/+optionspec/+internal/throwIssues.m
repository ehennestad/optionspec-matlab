function throwIssues(errorId, summary, issues)
%throwIssues Throw one error that lists every problem found.

    arguments
        errorId (1,1) string
        summary (1,1) string
        issues (1,:) string
    end

    message = summary + newline + strjoin("  - " + issues, newline);
    error(errorId, "%s", message)
end
