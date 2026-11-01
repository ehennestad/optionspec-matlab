# OptionSpec

[![Version Number](https://img.shields.io/github/v/release/ehennestad/optionspec-matlab?label=version)](https://github.com/ehennestad/optionspec-matlab/releases/latest)
[![Run tests](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-tests.yml/badge.svg)](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-tests.yml)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/optionspec-matlab/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/optionspec-matlab/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/optionspec-matlab/graphs/commit-activity)

Versioned option definitions in JSON Schema, with JSON value documents and migrations

## Description

Defines options as versioned JSON Schema 2020-12 files, validates MATLAB structs against them, saves the values used for a result as JSON documents, and upgrades documents written under older definition versions with migration functions. Designed to be vendored into other toolboxes.

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

```matlab
< add some code examples here >
```

## Contributing
Please see the [Contributing guidelines](.github/CONTRIBUTING.md) and the [Developer notes](.github/DeveloperNotes.md)

## License

This project is available under the MIT License. See the LICENSE file for details.

## Author

Eivind Hennestad (ehennestad@gmail.com)
