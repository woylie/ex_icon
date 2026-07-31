# ExIcon

[![CI](https://github.com/woylie/ex_icon/workflows/CI/badge.svg)](https://github.com/woylie/ex_icon/actions) [![Hex](https://img.shields.io/hexpm/v/ex_icon)](https://hex.pm/packages/ex_icon) [![Hex Docs](https://img.shields.io/badge/hex-docs-green)](https://hexdocs.pm/ex_icon/readme.html) [![Coverage Status](https://coveralls.io/repos/github/woylie/ex_icon/badge.svg)](https://coveralls.io/github/woylie/ex_icon)

Generic icon library for Phoenix LiveView.

- Downloads icon sets and generates Phoenix LiveView function components.
- Extensible via behaviour to support multiple icon libraries.
- Icon library versions are set via configuration. Update your icons without
  updating this library.
- Generate components for all icons or only the ones you need.
- Dev-only dependency. The library is only used for generating icon modules.

## Installation

Add `ex_icon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_icon, "~> 0.3.0", only: :dev}
  ]
end
```

## Usage

ExIcon expects a configuration file named `.ex_icon.exs`.

```elixir
[
  lucide: [
    # Either list only the icons you want to generate, or set to `:all` to
    # generate all available icons.
    icons: ["arrow-left", "arrow-right"],
    # A module implementing the `ExIcon.Provider` behaviour.
    provider: ExIcon.Lucide,
    # The release version of the icon library.
    version: "1.8.0",
    # The destination path of the icon module that ExIcon will generate for you.
    module_path: "lib/my_app_web/components/lucide.ex",
    # The name of the generated module.
    module_name: MyAppWeb.Components.Lucide,
    # SVG attributes to turn into component attributes, to override, or to add.
    # Example: ["stroke", {"stroke-width", default: "1.5"}]
    attrs: []
  ]
]
```

`lucide` is an arbitrary name that is currently only used for CLI output.
You can configure any number of icon providers.

With your configuration in place, you can download the configured release of
the icon library and generate a module with function components with:

```bash
mix ex_icon.gen.icons
```

Downloaded releases are cached in your Mix cache folder (`~/.cache/mix/ex_icon`
on Linux, `~/Library/Caches/mix/ex_icon` on macOS), so regenerating your icons
does not download the same release again. The exact path is printed after the
task ran. To force a fresh download, run:

```bash
mix ex_icon.gen.icons --force
```

## Attributes

ExIcon can optionally turn SVG attributes into function component attributes,
override the values of the original SVG files, and add attributes that the
original SVG files do not have.

For example, consider this original SVG:

```svg
<svg
  xmlns="http://www.w3.org/2000/svg"
  width="24"
  height="24"
  viewBox="0 0 24 24"
  stroke="currentColor"
  stroke-width="2"
  stroke-linecap="round"
>
  <path d="m12 19-7-7 7-7" />
  <path d="M19 12H5" />
</svg>
```

And this configuration:

```elixir
attrs: [
  # component attribute, defaults to the value in the SVG file
  "stroke",

  # component attribute with a default value that overrides the value in the
  # SVG file
  {"stroke-width", default: "1.5"},

  # component attribute with a limited set of values
  {"stroke-linecap", values: ["square", "round"]},

  # required attribute
  {"class", required: true},

  # optional component attribute that is omitted unless it is passed
  {"stroke-dasharray", default: nil},

  # sets a fixed attribute value without adding a component attribute
  {"fill", fixed: "none"}
]
```

The generated function component will look like this:

```elixir
attr :stroke, :string, default: "currentColor"
attr :stroke_width, :string, default: "1.5"
attr :stroke_linecap, :string, values: ["square", "round"], default: "round"
attr :class, :string, required: true
attr :stroke_dasharray, :string, default: nil

def arrow_left(assigns) do
  ~H"""
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="24"
    height="24"
    viewBox="0 0 24 24"
    stroke={@stroke}
    stroke-width={@stroke_width}
    stroke-linecap={@stroke_linecap}
    class={@class}
    stroke-dasharray={@stroke_dasharray}
    fill="none"
    aria-hidden="true"
  >
    <path d="m12 19-7-7 7-7" />
    <path d="M19 12H5" />
  </svg>
  """
end
```

Note that if you generate a lot of icons, compilation times can increase
substantially by adding component attributes.

## Providers

Providers for specific icon libraries are based on the `ExIcon.Provider`
behaviour. The library currently supports these providers:

- [Lucide](https://lucide.dev/)
- [Simple Icons](https://simpleicons.org/)

## Contributing

Please open an issue or PR if you need additional options, features, or support
for other icon libraries. Be sure to read the [contributing guidelines](https://github.com/woylie/ex_icon?tab=contributing-ov-file).
