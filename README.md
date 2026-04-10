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
    {:ex_icon, "~> 0.1.2", only: :dev}
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
    # SVG attributes that should be turned into component attributes. Only
    # attributes present in the original SVG files will be considered.
    # Values must be lowercase strings.
    # Example: ["stroke", "stroke-width"]
    attrs: []
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

## Attributes

ExIcon can optionally turn SVG attributes present in the original SVG files into
function component attributes.

For example, consider this original SVG:

```svg
<svg
  xmlns="http://www.w3.org/2000/svg"
  width="24"
  height="24"
  viewBox="0 0 24 24"
  stroke="currentColor"
  stroke-width="2"
>
  <path d="m12 19-7-7 7-7" />
  <path d="M19 12H5" />
</svg>
```

If you set the `attrs` option to `["stroke"]`, the generated function component
will look like this:

```elixir
attr :stroke, :string, default: "currentColor"

def arrow_left(assigns) do
  ~H"""
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width="24"
    height="24"
    viewBox="0 0 24 24"
    stroke={@stroke}
    stroke-width="2"
    aria-hidden="true"
  >
    <path d="m12 19-7-7 7-7" />
    <path d="M19 12H5" />
  </svg>
  """
end
```

Note that if you generate a lot of icons, compilation times can increase
substantially by adding attributes.

## Providers

Providers for specific icon libraries are based on the `ExIcon.Provider`
behaviour. Currently, ExIcon includes a single provider for
[Lucide](https://lucide.dev/).

## Contributing

Please open an issue or PR if you need additional options, features, or support
for other icon libraries. Be sure to read the [contributing guidelines](https://github.com/woylie/ex_icon?tab=contributing-ov-file).
