[
  icon_sets: [
    lucide: [
      icons: ["arrow-left", "arrow-right"],
      provider: ExIcon.Lucide,
      version: "1.8.0",
      module_path: "output/lucide.ex",
      module_name: MyAppWeb.Components.Lucide,
      # accept the global HTML attributes, with a default class
      global_attrs: [default: %{"class" => "size-6"}],
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
        {"stroke-linejoin",
         values: ["arcs", "miter", "round"], default: "miter"},
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
    heroicons: [
      icons: ["academic-cap", "bell"],
      provider: ExIcon.Heroicons,
      version: "2.2.0",
      module_path: "output/heroicons.ex",
      module_name: MyAppWeb.Components.Heroicons,
      # one module per variant, in output/heroicons/
      variants: [:outline, :solid, :mini, :micro],
      # the outlined icons have stroke attributes on top of the fill that all
      # variants have; attributes a variant does not have are ignored
      attrs: ["stroke", "stroke-width", "fill"]
    ],
    lucide_all: [
      icons: :all,
      # icons to skip
      exclude: ["arrow-left"],
      provider: ExIcon.Lucide,
      version: "1.8.0",
      module_path: "output/lucide_all.ex",
      module_name: MyAppWeb.Components.LucideAll
    ],
    custom: [
      # icon set read from a folder instead of a downloaded release
      path: "dev/icons",
      icons: :all,
      module_path: "output/custom.ex",
      module_name: MyAppWeb.Components.Custom,
      global_attrs: false
    ]
  ]
]
