[
  lucide: [
    icons: ["arrow-left", "arrow-right"],
    provider: ExIcon.Lucide,
    version: "1.8.0",
    module_path: "output/lucide.ex",
    module_name: MyAppWeb.Components.Lucide,
    attrs: [
      # attribute that defaults to the value in the SVG file
      "stroke",
      # attribute with explicit default value
      {"stroke-width", default: "1.5"},
      # additional attribute not in the original SVG
      {"class", default: "size-6"},
      # attribute restricted to a set of values
      {"stroke-linecap", values: ["butt", "round", "square"]},
      # restricted values combined with an explicit default
      {"stroke-linejoin", values: ["arcs", "miter", "round"], default: "miter"},
      # override existing attribute with fixed value
      {"fill", fixed: "currentColor"},
      # aria-hidden added automatically, but can be set explicitly
      {"aria-hidden", default: "true"}
    ]
  ],
  simple_icons: [
    icons: ["helix", "mastodon"],
    provider: ExIcon.SimpleIcons,
    version: "16.15.0",
    module_path: "output/simple_icons.ex",
    module_name: MyAppWeb.Components.SimpleIcons,
    attrs: [
      # additional attribute not in the original SVG
      {"fill", fixed: "currentColor"}
    ]
  ],
  lucide_all: [
    icons: :all,
    provider: ExIcon.Lucide,
    version: "1.8.0",
    module_path: "output/lucide_all.ex",
    module_name: MyAppWeb.Components.LucideAll
  ]
]
