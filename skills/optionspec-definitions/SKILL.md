---
name: optionspec-definitions
description: Write, change and version optionspec option definitions — JSON Schema 2020-12 files that define the options of a MATLAB processing step — and their migrations and generated MATLAB classes. Use when asked to add options for a step or function, write an option definition or options schema, convert a MATLAB arguments block or a NANSEN getDefaultOptions struct to a definition, bump the version of a definition, write a migration for old value documents, or generate option classes with optionspec.generateClasses. Covers the optionspec profile, conversion rules, version bumps, migrations and the checks that prove a definition is correct.
license: MIT
---

# optionspec definitions

An optionspec definition is a JSON Schema 2020-12 file, restricted to a profile,
that defines the options of a processing step: their types, defaults, allowed
values and help text. optionspec reads it with `optionspec.Definition`, saves
the values used for a result as a value document, upgrades old documents with
the migrations in `<name>.migrations.json`, and can generate MATLAB classes
from it with `optionspec.generateClasses`.

The specification is `docs/format.md` in
https://github.com/ehennestad/optionspec-matlab. Read it before writing a
definition; this skill is the procedure and the checklist, not the
specification.

## Find optionspec in the repository first

Toolboxes vendor optionspec under their own namespace, so the functions may
not be called `optionspec.*`. Search for the class file:

```bash
grep -rl --include=Definition.m "classdef (Sealed) Definition" .
```

`<path>/+imagestack/+external/+optionspec/Definition.m` means the class is
`imagestack.external.optionspec.Definition`. Use that prefix for every
function named below. Look for existing definition files (`*.json` with
`"x-version"`) and follow their folder, `$id` pattern and grouping.

## Write a new definition

1. **Collect the options from their source.** Keep names exactly as the code
   uses them; renaming is a separate decision for the user.

   From a MATLAB `arguments` block:

   | MATLAB | Definition |
   | --- | --- |
   | `(1,1) double` | `"type": "number"` |
   | `(1,1) double {mustBeInteger}` | `"type": "integer"` |
   | `(1,1) logical` | `"type": "boolean"` |
   | `(1,1) string`, `char` | `"type": "string"` |
   | `mustBeMember(x, ["a", "b"])` | `"enum": ["a", "b"]` |
   | `mustBePositive` / `mustBeNonnegative` | `"exclusiveMinimum": 0` / `"minimum": 0` |
   | `mustBeGreaterThanOrEqual(x, 1)` | `"minimum": 1` |
   | `(1,2) double` | `"type": "array"`, `"items": {"type": "number"}`, `"minItems": 2`, `"maxItems": 2` |
   | `(1,:) double` | `"type": "array"`, `"items": {"type": "number"}` |
   | `(:,:) double` | `"type": "array"`, `"items": {"type": "array", "items": {"type": "number"}}` |
   | default `Inf`, `-Inf`, `NaN` | the string `"Inf"`, `"-Inf"`, `"NaN"` and `"x-nonfinite": ["Inf"]` (list each one used) |
   | default `[]` meaning "not set" | `"type": ["number", "null"]` (or `["array", "null"]`), `"default": null` |

   From a NANSEN options struct (`getDefaultOptions`, `getDefaults`): each
   top-level struct field is a group (`"type": "object"` with
   `"properties"`). Hint fields named `<name>_` become keywords of `<name>`,
   not options:

   | NANSEN hint | Definition |
   | --- | --- |
   | `x_ = {'a', 'b'}` | `"enum": ["a", "b"]`, `"x-ui": {"widget": "dropdown"}` |
   | `x_ = {0, 1, 2}` | `"type": "integer"`, `"enum": [0, 1, 2]`, dropdown |
   | `x_ = struct('type', 'slider', 'args', {{'Min', 1, 'Max', 16, ...}})` | `"minimum": 1`, `"maximum": 16`, `"x-ui": {"widget": "slider"}` (and `"units"` from `TooltipUnits`) |
   | `x_ = 'uigetdir'` / `'uigetfile'` | `"format": "folder-path"` / `"file-path"` and widget `"folder"` / `"file"` |
   | `x_ = 'internal'` | `"x-ui": {"widget": "hidden"}` |
   | `x_ = struct('type', 'button', ...)` | `"type": "boolean"`, widget `"button"` |
   | trailing `% comment` on the assignment | `"description"` |

   A validation function (NANSEN's second output `V`) maps to the same
   keywords as `arguments` validators. If a constraint has no keyword (for
   example a dependency between two options), say so to the user; do not
   invent a keyword.

2. **Choose the header.** `"$id"`: the toolbox and step, for example
   `"imagestack.rigid-registration"`, matching existing files. `"x-version"`:
   `"1.0.0"`. Add `"$schema": "https://json-schema.org/draft/2020-12/schema"`,
   a `"title"` and a `"description"`.

3. **Share options with `allOf`.** Options common to several steps belong in
   one definition that others include with
   `"allOf": [{"$ref": "stack.json"}]` (path relative to the including file).
   An including definition may redeclare an included option with only the
   keywords it changes (`{"default": 500}`, a smaller `"enum"`, a higher
   `"minimum"`), but never its type. A definition that others include must
   not set `"unevaluatedProperties"` or `"additionalProperties"`.

4. **Write descriptions a user can act on.** Name units and the meaning of
   special values: "Largest shift searched, in pixels", "null processes all
   parts". Put units in `"x-ui": {"units": "..."}` too when the option has a
   widget.

5. **Verify** (next section) before reporting the definition as done.

## Verify a definition

Run in MATLAB, with the toolbox on the path:

```matlab
definition = optionspec.Definition("path/to/step.json");   % lists every profile problem
values = definition.defaults();
isequaln(values, sourceDefaults)                             % against the struct or arguments defaults
roundTrip = definition.decode(definition.encode(values));
isequaln(roundTrip, values)
```

- `sourceDefaults` is the struct the old code builds (NANSEN) or a struct of
  the `arguments` defaults. Compare with `isequaln`, because `NaN ~= NaN`.
  Text options come back as char and arrays of text as string arrays.
- If the repository commits generated classes, regenerate them (next
  section) and run its test that calls `checkGeneratedClasses`.
- Add the definition to the toolbox's tests: loading it, its defaults, and
  any value the code relies on.

## Change an existing definition

Every change needs a new `"x-version"`. Decide the bump from the change:

| Change | Bump | Also needed |
| --- | --- | --- |
| Description, title or `x-ui` only | patch | nothing |
| Option added (with a default) | minor | nothing; old documents get the default |
| Enum value added, range or element count widened | minor | nothing |
| Option removed, renamed, moved to another group, retyped; enum value removed; range or element count narrowed; default `[]` no longer allowed | major | a migration from the old major version |
| Default changed | minor | nothing, unless documents that do not set the option (presets) must keep the old default: then a major bump with an `add` migration; ask the user |

For a major bump, add a step to `<name>.migrations.json` next to the
definition (create it if missing):

```json
{
  "definition": "<$id>",
  "migrations": [
    {"from": 1, "to": 2, "description": "What changed and why old values map this way.",
     "operations": [
       {"op": "rename", "from": "Correction.maxShift", "to": "Correction.maximumShift"},
       {"op": "remove", "path": "Misc.useGpu"},
       {"op": "add", "path": "Correction.phaseFlag", "value": true},
       {"op": "mapValues", "path": "Correction.method", "map": [{"from": "fft", "to": "FFT"}]},
       {"op": "scale", "path": "Deconvolution.tau", "factor": 0.001}
     ]}
  ]
}
```

Prefer the declarative operations: any implementation of the format can
apply them. Use `{"op": "function", "matlab": "<function name>"}` only for a
value computed from other values, and write that function next to the code
that owns the definition.

A definition that includes a changed definition changes too: bump it by the
same level, and for a major change copy the operations into its own
migrations file with the paths it uses.

Add a test with a value document of the old version (write it by hand with
the old option names) and check that `readDocument` returns the expected
current values.

## Generated classes

When the toolbox uses generated option classes:

```matlab
optionspec.generateClasses("path/to/step.json", "src/<toolbox>", Namespace="<toolbox>.options")
```

- Regenerate after every change to a definition, and commit the generated
  files with the definition change.
- Never edit a generated file; the header says so. Change the definition and
  regenerate.
- The toolbox should have a test like
  `testCase.verifyEmpty(optionspec.checkGeneratedClasses(file, folder, Namespace=...))`.
  Add it if it is missing.
- The class of a definition is `<BaseName>Options`, a group `G` is
  `<BaseName>GOptions`; `BaseName` defaults to the last part of `$id` in
  UpperCamelCase.

## Checklist of mistakes optionspec rejects

- An object key that is not a valid MATLAB name, such as `"frame-rate"`.
  Keys are option names and must start with a letter and contain only
  letters, digits and underscores.
- `NaN` or `Infinity` written as JSON tokens. Write `"NaN"`, `"Inf"`,
  `"-Inf"` and list them in `"x-nonfinite"`.
- An option without `"default"`, or a group (`"type": "object"`) with one.
- A default outside its own `"enum"` or range.
- Keywords outside the profile: `"pattern"`, `"$defs"`, `"oneOf"`, nested
  `"allOf"`, `"const"`, `"minLength"` and others. Use only the keywords in
  `docs/format.md`.
- More than one non-null type, such as `["number", "string"]`.
- `"x-ui"` widgets that do not fit the option: `"slider"` needs
  `"minimum"` and `"maximum"`, `"dropdown"` needs `"enum"`, `"checkbox"` and
  `"button"` need a boolean.
