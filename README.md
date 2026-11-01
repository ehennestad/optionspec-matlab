# OptionSpec

[![Version Number](https://img.shields.io/github/v/release/ehennestad/optionspec-matlab?label=version)](https://github.com/ehennestad/optionspec-matlab/releases/latest)
[![Run tests](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-tests.yml/badge.svg)](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-tests.yml)
[![codecov](https://codecov.io/gh/ehennestad/optionspec-matlab/graph/badge.svg?token=VKRD5KP7MZ)](https://codecov.io/gh/ehennestad/optionspec-matlab)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/optionspec-matlab/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/optionspec-matlab/graphs/commit-activity)

Versioned option definitions in JSON Schema, with JSON value documents and migrations

## Description

optionspec defines the options of a processing step in a JSON Schema 2020-12 file with a version, checks MATLAB structs against it, saves the values used for a result as a JSON value document, and upgrades documents written under older versions. It is written to be vendored into other toolboxes, such as imagestack and NANSEN, which then share the file formats rather than MATLAB classes.

- `optionspec.Definition` reads a definition file and returns the defaults (`defaults`), checks values (`validate`, `isValid`), fills in defaults for partial values such as presets (`resolve`), and writes and reads value documents (`writeDocument`, `readDocument`).
- A definition includes other definitions with `allOf`, for example options shared by every step. An included option can be given another default or a narrower range, but not another type.
- A `<name>.migrations.json` file next to a definition lists operations (`rename`, `remove`, `add`, `mapValues`, `scale`, and `function` for a MATLAB function) that upgrade values by one major version each. `readDocument` applies them to documents of older versions.
- Inf, -Inf and NaN are written as the strings `"Inf"`, `"-Inf"` and `"NaN"`, and allowed only for options that list them in `x-nonfinite`.

[docs/format.md](docs/format.md) specifies the three file formats and how values map to MATLAB types.

## Requirements and installation
It is recommended to use **MATLAB R2021a** or later.
The following MathWorks products are required:
- MATLAB

Users or developers who clone the repository using git can use [MatBox](https://github.com/ehennestad/MatBox) to quickly install this project's [requirements](./requirements.txt) (if any):

```matlab
optionspectools.installMatBox() % If MatBox is not installed
matbox.installRequirements(path/to/toolboxRootDir)
```

## Getting started

A definition with one group of options:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "example.registration",
  "x-version": "1.0.0",
  "type": "object",
  "properties": {
    "Registration": {
      "type": "object",
      "properties": {
        "MaxShift": {"type": "number", "minimum": 0, "x-nonfinite": ["Inf"], "default": "Inf"},
        "UpsampleFactor": {"type": "integer", "minimum": 1, "default": 10},
        "Taper": {"type": "boolean", "default": true}
      }
    }
  }
}
```

```matlab
definition = optionspec.Definition("registration.json");
values = definition.defaults();          % values.Registration.MaxShift is Inf
values = definition.resolve(struct("Registration", struct("MaxShift", 15)));
definition.writeDocument("options.json", values)
[values, header] = definition.readDocument("options.json");
```

[src/optionspec/examples/optionspecExample.m](src/optionspec/examples/optionspecExample.m) is a longer example with an included definition and a migration.

## Contributing
Please see the [Contributing guidelines](.github/CONTRIBUTING.md) and the [Developer notes](.github/DeveloperNotes.md)

## License

This project is available under the MIT License. See the LICENSE file for details.

## Author

Eivind Hennestad (ehennestad@gmail.com)
