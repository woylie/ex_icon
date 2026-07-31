# Changelog

## Unreleased

### Added

- Add `--force` flag to `mix ex_icon.gen.icons`, which discards the cached
  release and downloads it again.

### Changed

- Cache downloaded releases in the Mix cache folder instead of downloading them
  into a shared temporary folder on every run.
- Prevent interrupted runs from leaving a partial release behind.
- Add HTTP request timeouts.

### Fixed

- Escape SVG attribute values in the generated module. Previously, an attribute
  value containing `#{}` was written into the generated component code
  unescaped, where it would be evaluated during compilation.
- Refuse release archives with entries pointing outside the target folder.

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
