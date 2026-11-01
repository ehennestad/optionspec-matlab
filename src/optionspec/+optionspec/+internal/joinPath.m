function path = joinPath(parentPath, name)
%joinPath Join an option path and an option name with a dot.

    arguments
        parentPath (1,1) string
        name (1,1) string
    end

    if parentPath == ""
        path = name;
    else
        path = parentPath + "." + name;
    end
end
