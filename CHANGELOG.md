# Changelog

## Unreleased

### Changed

- Use `Mix.raise/1` for exceptions.

### Fixed

- Use canonical casing for SVG element and attribute names.
- Validate `module_name` in configuration.
- Report the path and the line of the configuration file when it does not
  parse.
- Name the missing callback when a module configured as `provider` does not
  implement the `ExIcon.Provider` behaviour.

## [0.5.0] - 2026-08-02

### Fixed

- Check the generated module before formatting it, so that an icon which does
  not produce valid code is reported instead of raising in the formatter.
- Turn a CRLF and a lone CR in an icon into a LF, as XML requires.
- Add an `icon_` prefix to a generated function name that is a reserved word in
  Elixir, so that `end.svg` becomes `icon_end` instead of generating a module
  that does not compile.

### Security

- Refuse release archives with entries that would be written outside the target
  folder.
- Check the name a zip entry carries in its local file header, not only the one
  in the central directory.
- Refuse a release archive whose entries cannot be listed, instead of unpacking
  it unchecked.
- Only allow known CSS functions in a `style` value, and reject values that
  contain a backslash.
- Only allow `clip-path`, `color`, `fill`, `mask`, `stop-color` and `stroke`
  values that point into the same file.
- Hold a character written into an icon to the same rule as a reference to it,
  which was only applied to references before.
- Reject control characters and invisible characters such as a bidirectional
  override.

## [0.4.0] - 2026-08-01

### Added

- Add `default`, `values`, `required`, and `fixed` options to attribute
  configuration, which allows you more control over the attributes in the
  generated HEEx components.
- Add optional `c:ExIcon.Provider.variants/1` callback and `variants`
  configuration option for icon libraries that have multiple style variants.
  Each variant is generated into a module of its own, from a single download.
- Add provider for Heroicons, which has outlined and filled variants in
  several sizes.
- Add `--cache-dir`, `--config`, `--force`, and `--refresh` arguments to
  `mix ex_icon.gen.icons`. See `mix help ex_icon.gen.icons`.
- Add `exclude` configuration option to skip individual icons.
- Add `path` configuration option to generate an icon set from a local folder.
- Add `global_attrs` configuration option to accept global HTML attributes
  in the generated components.

### Changed

- Skip icons that use SVG elements or attributes that ExIcon does not know,
  which prevents scripts and event handlers from being added to generated
  components. Remove `metadata` elements and elements with a namespace prefix
  other than `svg`.
- Only allow `href` and `xlink:href` values that point at an ID in the same
  file. Reject `style` values that contain `url()`.
- The handling of whitespaces and character references such as `&#233;` was
  changed. Regenerating your icon modules with this version may produce diffs
  even though the source SVG files haven't changed.
- Cache downloaded releases in the Mix cache folder instead of downloading them
  into a shared temporary folder on every run.
- Only move a release into the cache once it is complete, so that an
  interrupted run does not leave a partial release behind.
- Add connect and receive timeouts to the release download.
- Fail if a module was not written.
- Fail if an icon listed in the configuration was not generated.
- Check the provider and the variants of every icon set before downloading or
  writing anything.
- Nest the icon sets in the configuration file under an `icon_sets` key.
- Rename `ExIcon.Lucide` and `ExIcon.SimpleIcons` to `ExIcon.Providers.Lucide`
  and `ExIcon.Providers.SimpleIcons`.

### Removed

- Remove ExIcon.transform_svg/2.

### Fixed

- Keep the `aria-hidden` value set by an SVG file instead of always overwriting
  it with `true`.
- Apply configured attributes to SVG files that have no attributes at all.
- Ignore folders with an `.svg` extension when generating all icons of a
  release.
- Do not ask to overwrite generated modules that have not changed.
- Format all generated modules instead of only the first one.
- Keep attributes that are written with single quotes, and namespaced attribute
  names such as `xmlns:xlink`, which used to end up as `xlink`.
- Add an `icon_` prefix to generated function names that start with a digit, so
  that `icons: :all` works for Simple Icons.
- Raise if two icons map to the same function name.

### Security

- Escape SVG attribute values in the generated module. Previously, an attribute
  value containing `#{}` was written into the generated component code
  unescaped, where it would be evaluated during compilation.
- Skip icons whose names cannot be turned into function names. Previously, a
  file name in a release was written into the generated module unchecked, where
  it could add arbitrary code.
- Validate version string before downloading.
- Set modes of the unpacked files instead of taking them from the archive.
- Refuse a release archive that unpacks to more than 250 MB.
- Require an https URL from a provider, unless it points at the local machine.
- Parse icon files instead of copying their contents into the generated module.
  Previously, an icon file could end the heredoc of a component and add code to
  the module, or add a HEEx expression that was evaluated every time the
  component was rendered.

### How to upgrade

Move the icon sets in your configuration under an `icon_sets` key, and rename
the bundled providers:

```diff
 [
-  lucide: [
-    provider: ExIcon.Lucide,
-    # ...
-  ]
+  icon_sets: [
+    lucide: [
+      provider: ExIcon.Providers.Lucide,
+      # ...
+    ]
+  ]
 ]
```

## [0.3.0] - 2026-04-10

### Added

- Add provider for Simple Icons.
- Add `--icon-set` flag to `mix ex_icon.gen.icons`.

### Changed

- Change `c:ExIcon.Provider.svg_folder/0` to `c:ExIcon.Provider.svg_folder/1`,
  with the argument being the version.

## [0.2.0] - 2026-04-10

### Changed

- Replace `ignore_attrs` option with `attrs`.
- Add `aria-hidden="true"` to SVGs if not already present.

## [0.1.2] - 2026-04-10

### Fixed

- Run `mix format` separately instead of relying on `copy_template/4` for
  formatting to ensure formatter config is applied.

## [0.1.1] - 2026-04-10

### Fixed

- Add Mix template to release.

## [0.1.0] - 2026-04-10

Initial release.
