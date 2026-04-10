# ExIcon

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
    {:ex_icon, "~> 0.1.1", only: :dev}
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
    # SVG attributes that should _not_ be turned into component attributes.
    # Values must be lowercase strings.
    # Default: ["xmlns", "viewbox", "width", "height"]
    # ignore_attrs: []
  ]
]
```

`lucide` is an arbitrary name that is currently only used for CLI output.
You can configure any number of icon providers.

With your configuration in place, you can download the configured release of
the icon library and generate a module with function components with:

```bash
mix ex_icon.gen_icons
```

## Providers

Providers for specific icon libraries are based on the `ExIcon.Provider`
behaviour. Currently, ExIcon includes a single provider for
[Lucide](https://lucide.dev/).

## Contributing

Please open an issue or PR if you need additional options, features, or support
for other icon libraries. Be sure to read the [contributing guidelines](https://github.com/woylie/ex_icon?tab=contributing-ov-file).
