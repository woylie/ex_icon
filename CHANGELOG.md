# Changelog

## Unreleased

### Added

- Add `--force` flag to `mix ex_icon.gen.icons`, which discards the cached
  release and downloads it again.
- Add `--config` flag to `mix ex_icon.gen.icons`, which reads the configuration
  from the given path instead of `.ex_icon.exs`.
- Add `default`, `values`, `required`, and `fixed` options to attribute
  configuration, which allows you more control over the attributes in the
  generated HEEx components.
- Add provider for Heroicons.
- Support the `EX_ICON_CACHE_DIR` environment variable to cache releases outside
  of the Mix cache folder.
- Add optional `c:ExIcon.Provider.variants/1` callback and `variants`
  configuration option for icon libraries that have multiple style variants.

### Changed

- Cache downloaded releases in the Mix cache folder instead of downloading them
  into a shared temporary folder on every run.
- Prevent interrupted runs from leaving a partial release behind.
- Add HTTP request timeouts.
- Change the second element of the tuple returned by `ExIcon.transform_svg/2`
  from a list of `{name, default}` tuples to a list of `{name, options}` tuples,
  where the options are those of the generated component attribute.

### Fixed

- Escape SVG attribute values in the generated module. Previously, an attribute
  value containing `#{}` was written into the generated component code
  unescaped, where it would be evaluated during compilation.
- Refuse release archives with entries pointing outside the target folder.
- Keep the `aria-hidden` value set by an SVG file instead of always overwriting
  it with `true`.
- Apply configured attributes to SVG files that have no attributes at all.
- Format all generated modules instead of only the first one.
- Do not ask to overwrite generated modules that have not changed.
- Ignore folders with an `.svg` extension when generating all icons of a
  release.

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
