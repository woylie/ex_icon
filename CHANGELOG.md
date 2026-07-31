# Changelog

## Unreleased

### Added

- Add `default`, `values`, `required`, and `fixed` options to attribute
  configuration, which allows you more control over the attributes in the
  generated HEEx components.
- Add optional `c:ExIcon.Provider.variants/1` callback and `variants`
  configuration option for icon libraries that have multiple style variants.
  Each variant is generated into a module of its own, from a single download.
- Add provider for Heroicons, which has outlined and filled variants in
  several sizes.
- Add `--config`, `--force`, and `--cache-dir` arguments to
  `mix ex_icon.gen.icons`. See `mix help ex_icon.gen.icons`.
- Add `exclude` configuration option to skip icons of a release.

### Changed

- Make `ExIcon.transform_svg/2` internal. The `ExIcon` module has no public
  functions anymore.
- Cache downloaded releases in the Mix cache folder instead of downloading them
  into a shared temporary folder on every run.
- Only move a release into the cache once it is complete, so that an
  interrupted run does not leave a partial release behind.
- Add connect and receive timeouts to the release download.

### Fixed

- Keep the `aria-hidden` value set by an SVG file instead of always overwriting
  it with `true`.
- Apply configured attributes to SVG files that have no attributes at all.
- Ignore folders with an `.svg` extension when generating all icons of a
  release.
- Do not ask to overwrite generated modules that have not changed.
- Format all generated modules instead of only the first one.
- Prefix generated function names that start with a digit with `icon_`, so that
  `icons: :all` works for Simple Icons.
- Raise instead of generating a module that does not compile if two icons map to
  the same function name.

### Security

- Escape SVG attribute values in the generated module. Previously, an attribute
  value containing `#{}` was written into the generated component code
  unescaped, where it would be evaluated during compilation.
- Skip icons whose names cannot be turned into function names. Previously, a
  file name in a release was written into the generated module unchecked, where
  it could add arbitrary code.

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
