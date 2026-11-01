# optionspec file formats

optionspec uses three kinds of JSON file. All three are plain JSON (RFC 8259): the tokens `NaN`, `Infinity` and `-Infinity` are not allowed, and every object key must be a valid MATLAB name (a letter followed by letters, digits and underscores, at most 63 characters) or one of the keywords `$schema`, `$id`, `$ref`, `$comment`, `x-version`, `x-ui` and `x-nonfinite`.

| File | Name | Content |
| --- | --- | --- |
| Definition | `<name>.json` | The options, their types and defaults, as JSON Schema 2020-12 |
| Migrations | `<name>.migrations.json`, next to the definition | Operations that upgrade values from one major version to the next |
| Value document | any name | The values used for a result, with the definition id and version |

## Definitions

A definition is a JSON Schema 2020-12 schema of the values object, restricted to the profile below. `optionspec.Definition` rejects anything outside the profile and lists every problem in one `OPTIONSPEC:InvalidDefinition` error.

The definitions in `tests/fixtures/definitions` and `src/optionspec/examples/definitions` pass `Draft202012Validator.check_schema` of the Python package jsonschema 4.26.0. A standard validator checks values against a definition with three differences from optionspec: it reports the strings `"Inf"`, `"-Inf"` and `"NaN"` as type errors (see [Non-finite numbers](#non-finite-numbers)), it rejects unknown options only at the top level and only if the definition sets `unevaluatedProperties` to `false`, and it does not fill in defaults.

Top-level keys:

| Key | Required | Value |
| --- | --- | --- |
| `$schema` | no | `"https://json-schema.org/draft/2020-12/schema"` |
| `$id` | yes | Identifier of the definition, without spaces, for example `"imagestack.motion-correction"` |
| `x-version` | yes | Version `"MAJOR.MINOR.PATCH"` |
| `title`, `description` | no | Text |
| `type` | yes | `"object"` |
| `properties` | yes, unless `allOf` is given | The options |
| `allOf` | no | Included definitions, `[{"$ref": "<file>"}, ...]` |
| `unevaluatedProperties`, `additionalProperties` | no | `false` only, and only in a definition that no other definition includes, because a standard validator evaluates an included definition on its own and would reject the options of the including one. optionspec always rejects unknown options. |
| `$comment` | no | Ignored |

### Options

Each member of `properties` is an option. An option of type `"object"` is a group: it has `properties` of its own and no `default`. Every other option has a `type` and a `default`. Keywords of an option:

| Keyword | Applies to | Meaning |
| --- | --- | --- |
| `type` | all | One of `"boolean"`, `"integer"`, `"number"`, `"string"`, `"array"`, `"object"`, optionally in a list with `"null"`, for example `["array", "null"]` |
| `default` | all but groups | The default value; it must be valid for the option |
| `title`, `description` | all | Text |
| `enum` | string, integer, number | The allowed values |
| `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` | integer, number | Range |
| `x-nonfinite` | integer, number | Which of `"Inf"`, `"-Inf"`, `"NaN"` the option allows |
| `items` | array | Schema of the elements: a boolean, integer, number or string schema, or an array schema whose items are boolean, integer or number (a matrix whose rows are the inner arrays) |
| `minItems`, `maxItems` | array | Number of elements, or of rows of a matrix |
| `format` | string | `"folder-path"` or `"file-path"`; a hint, not checked |
| `x-ui` | all but groups | User interface hints, see below |
| `properties` | object | The options of the group |
| `additionalProperties` | object | `false` only |
| `$comment` | all | Ignored |

Items of an array take the same keywords except `default`, `x-ui` and `"null"`.

### User interface hints

`x-ui` is an object with a required `widget` and optional `label` (text), `units` (text) and `step` (positive number). optionspec checks the hints and returns them with the schema of the option; it does not draw anything.

| `widget` | Option must be |
| --- | --- |
| `"edit"`, `"hidden"` | any type |
| `"dropdown"` | an option with `enum` |
| `"slider"` | integer or number with `minimum` and `maximum` |
| `"checkbox"`, `"button"`, `"togglebutton"` | boolean |
| `"multilinetext"`, `"folder"`, `"file"` | string |

### Non-finite numbers

JSON has no numbers for infinity and not-a-number. optionspec writes them as the strings `"Inf"`, `"-Inf"` and `"NaN"`, in defaults and in value documents. An option accepts them only if it lists them in `x-nonfinite`:

```json
"radius": {"type": "number", "minimum": 0, "x-nonfinite": ["Inf"], "default": "Inf"}
```

A standard JSON Schema validator reports these strings as type errors, because the schema says `"number"`. `null` means an empty value and is allowed only when `"null"` is in the type.

### Composition

`allOf` includes other definitions. Each `$ref` is a file path relative to the including definition. The included options follow the options of the including definition, and groups with the same name merge option by option, with the options of the including definition first. Definitions can be nested: an included definition may include others. `Definition.Includes` lists every included definition as `"<id>@<version>"`.

The including definition may redeclare an included option with only the keywords it changes, for example `{"default": 500}`. It may change `default`, `title`, `description` and `x-ui`, and narrow the allowed values: remove values from `enum` or `x-nonfinite`, raise a minimum, lower a maximum, raise `minItems` or lower `maxItems`. Changing the type or `format`, or widening a range, is an error. So is an option declared by two included definitions.

A change to an included definition changes the values of every definition that includes it, so it needs a new version of those definitions too, and a migration in their migrations files when the change is a major one.

## Versions

A definition has a semantic version `MAJOR.MINOR.PATCH`:

- **Major**: values valid under the old version can be invalid under the new one. An option was removed, renamed, retyped or narrowed. Needs a migration.
- **Minor**: options were added. Values of an older minor version are read with the defaults of the new options.
- **Patch**: only titles, descriptions or hints changed.

Reading values written under a newer major or minor version is an `OPTIONSPEC:NewerVersion` error. A newer patch version is read.

## Value documents

```json
{
  "optionspec": "1",
  "definition": "example.rigid-registration",
  "version": "2.0.0",
  "values": {
    "Registration": {"MaxShift": "Inf", "UpsampleFactor": 10, "Taper": true},
    "Stack": {"TimepointInterval": [1, 1000], "PartsToProcess": null}
  }
}
```

| Key | Value |
| --- | --- |
| `optionspec` | Version of the document format, `"1"` |
| `definition` | `$id` of the definition |
| `version` | `x-version` of the definition the values were written under |
| `values` | The values, as described by the definition |

Other keys are an error. `Definition.writeDocument` writes every option. `Definition.readDocument` also accepts documents that set only some options, such as hand-written presets, and fills in the defaults of the others.

Arrays are written as arrays even when they hold one element, and a matrix as an array of rows. The same values are always written as the same text, with the options in the order of the definition, so documents differ in git only where values differ.

## Migrations

```json
{
  "definition": "fixtures.normcorre",
  "migrations": [
    {
      "from": 1,
      "to": 2,
      "description": "Spell out abbreviated names.",
      "operations": [
        {"op": "rename", "from": "Correction.maxShift", "to": "Correction.maximumShift"},
        {"op": "mapValues", "path": "Correction.shiftsMethod", "map": [{"from": "fft", "to": "FFT"}]}
      ]
    }
  ]
}
```

Each migration upgrades values from one major version (`from`) to the next (`to`). Reading values of major version 1 under version 3 applies the migration from 1 to 2, then the one from 2 to 3, then fills in defaults and validates. The values are not validated between migrations, because only the current definition is known. A missing migration is an `OPTIONSPEC:MissingMigration` error.

Paths are dotted option paths such as `"Correction.maximumShift"`. An operation on a path that the values do not have does nothing.

| Operation | Keys | Effect |
| --- | --- | --- |
| `rename` | `from`, `to` | Move an option or group; creates groups on the new path. An existing target is an `OPTIONSPEC:MigrationFailed` error. |
| `remove` | `path` | Remove an option or group, and groups it leaves empty |
| `add` | `path`, `value` | Set an option the values do not have; use it when old values should keep an old behaviour rather than the new default |
| `mapValues` | `path`, `map` | Replace a value equal to a `from` with its `to` |
| `scale` | `path`, `factor` | Multiply a number, or the numbers of an array, by `factor`; `"Inf"` and other text stay as they are |
| `function` | `matlab` | Call the named MATLAB function, which takes and returns the values struct |

The first five operations are declarative, so any implementation of the format can apply them. A `function` operation is for changes they cannot express, such as computing a new value from old ones. An implementation in another language needs its own function for it, named in a key for that language.

## MATLAB values

`optionspec.Definition` returns values as a struct with one field per option, in the order of the definition, and a nested struct per group.

| Schema | MATLAB value |
| --- | --- |
| `null` | `[]` (0x0 double) |
| boolean | logical scalar |
| integer, number | double scalar; `Inf`, `-Inf`, `NaN` for `"Inf"`, `"-Inf"`, `"NaN"` |
| string | char row vector; `''` when empty |
| array of numbers or integers | 1xN double; `zeros(1, 0)` when empty |
| array of booleans | 1xN logical |
| array of strings | 1xN string array; `strings(1, 0)` when empty |
| array of arrays (matrix) | MxN double or logical; `zeros(0, 0)` when empty |
| object (group) | scalar struct |

`validate` and `resolve` accept other forms and convert them: numeric classes other than double, string scalars for text, column vectors, cell arrays of numbers or text (as `jsondecode` returns), and a string scalar for a one-element string array. `[]` means `null` for an option that allows it, and an empty array otherwise.

## Generated MATLAB classes

`optionspec.generateClasses(definition, outputFolder, Namespace="imagestack.options")` writes one value class per definition and one per group of options. The class of the definition `example.rigid-registration` is `RigidRegistrationOptions`; its group `Stack` is `RigidRegistrationStackOptions`. The classes are generated from the composed schema, so they include the included options and do not inherit from the classes of included definitions. A group is a property that holds the class of the group.

| Schema | Property |
| --- | --- |
| boolean | `(1,1) logical` |
| integer | `(1,1) double {mustBeFinite, mustBeInteger}` |
| number | `(1,1) double {mustBeFinite}` |
| `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` | `mustBeGreaterThanOrEqual`, `mustBeLessThanOrEqual`, `mustBeGreaterThan`, `mustBeLessThan` |
| `x-nonfinite` | `mustBeFinite` is left out or replaced by a local `mustBeFiniteOr`; with `"NaN"`, ranges are checked by a local `mustBeInRangeOrNaN` |
| string | `(1,:) char`, with `mustBeMember` for `enum` |
| array | `(1,:)`, or `(1,N)` when `minItems` and `maxItems` are both N, of `double`, `logical` or `string` |
| matrix | `(:,:) double` or `(:,:) logical` |
| `"null"` in the type | no size validation, so that `[]` stays `[]`, and a local validator for the rest |
| object (group) | `(1,1)` the class of the group |

Each class has:

- the constructor `Options()`, `Options(values)` with a struct that may set only some options, and `Options(Name=Value)`. Unknown names are an `OPTIONSPEC:UnknownOption` error. Assigning a struct to a group property sets the options it holds and keeps the defaults of the others.
- `toStruct()`, which returns the values in the form of the [MATLAB values](#matlab-values) table, for `Definition.validate`, `Definition.writeDocument` and so on.
- the constant properties `DefinitionId` and `DefinitionVersion` (the class of the definition only).
- help text from `title`, `description`, the default, the allowed values and range, and the `x-ui` units.

The classes use only MATLAB functions and local functions in their files, so a toolbox that vendors optionspec under another namespace keeps them unchanged. MATLAB converts compatible values when it sets a property: `1` to `true`, `"3"` to `3`, `'ab'` to `"ab"` for a string array. `Definition.validate` rejects these values because their class differs; `GeneratedClassTest` lists the conversions.

`generateClasses` replaces a file only if it wrote it, which it recognises by the line `%   Generated by optionspec.generateClasses from definition` in the header. Commit the generated classes, and add a test that fails when they no longer match the definition:

```matlab
testCase.verifyEmpty(optionspec.checkGeneratedClasses(definitionFile, sourceFolder, ...
    Namespace="imagestack.options"))
```

`checkGeneratedClasses` lists files that are missing, that differ from what the definition generates, and that were generated from the definition but would no longer be generated, such as the class of a removed group.

