defmodule ExIconTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias ExIconTest.UnreachableProvider

  doctest ExIcon

  defmodule UnreachableProvider do
    @moduledoc false
    @behaviour ExIcon.Provider

    @impl true
    def release_url(_), do: "https://localhost:1/nonexistent.zip"

    @impl true
    def svg_folder(_), do: "icons"
  end

  describe "prepare_assigns/2" do
    @describetag :tmp_dir
    test "prepares assigns for configured icon", %{tmp_dir: tmp_dir} do
      icon_name = "arrow-left"
      icon_path = Path.join(tmp_dir, "#{icon_name}.svg")
      module_path = Path.join(tmp_dir, "lib/components/lucide.ex")

      opts = [
        icons: [icon_name],
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: module_path,
        module_name: MyAppWeb.Components.Lucide,
        attrs: ["stroke", "stroke-width"]
      ]

      svg = """
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
      """

      File.write!(icon_path, svg)

      assert [
               icons: [{name, {transformed_svg, attrs}}],
               module_name: MyAppWeb.Components.Lucide
             ] = ExIcon.prepare_assigns(tmp_dir, opts)

      assert name == "arrow_left"

      assert transformed_svg == """
             <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width} aria-hidden="true">
               <path d="m12 19-7-7 7-7" />
               <path d="M19 12H5" />
             </svg>\
             """

      assert attrs == [
               {"stroke", [default: "currentColor"]},
               {"stroke_width", [default: "2"]}
             ]
    end

    test "prepares assigns for all icons", %{tmp_dir: tmp_dir} do
      icon_name = "arrow-left"
      icon_path = Path.join(tmp_dir, "#{icon_name}.svg")
      module_path = Path.join(tmp_dir, "lib/components/lucide.ex")

      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: module_path,
        module_name: MyAppWeb.Components.Lucide
      ]

      svg = """
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
      """

      File.write!(icon_path, svg)

      assert [
               icons: [{"arrow_left", {_transformed_svg, _attrs}}],
               module_name: MyAppWeb.Components.Lucide
             ] =
               ExIcon.prepare_assigns(tmp_dir, opts)
    end

    test "ignores folders that look like svg files", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")
      File.mkdir_p!(Path.join(tmp_dir, "not-an-icon.svg"))

      output =
        capture_io(fn ->
          assert [
                   icons: [{"arrow_left", _}],
                   module_name: MyAppWeb.Components.Lucide
                 ] = ExIcon.prepare_assigns(tmp_dir, opts)
        end)

      refute output =~ "Could not read file"
    end

    test "ignores non-svg files", %{tmp_dir: tmp_dir} do
      icon_name = "arrow-left"
      icon_path = Path.join(tmp_dir, "#{icon_name}.json")
      module_path = Path.join(tmp_dir, "lib/components/lucide.ex")

      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: module_path,
        module_name: MyAppWeb.Components.Lucide
      ]

      svg = """
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
      """

      File.write!(icon_path, svg)

      assert ExIcon.prepare_assigns(tmp_dir, opts) == [
               icons: [],
               module_name: MyAppWeb.Components.Lucide
             ]
    end
  end

  describe "template rendering" do
    test "renders attribute values as string literals" do
      assert render_attr({"stroke", [default: "currentColor"]}) =~
               ~S|attr :stroke, :string, default: "currentColor"|
    end

    test "renders values and required attribute options" do
      assert render_attr(
               {"stroke_linecap", [values: ["square", "round"], required: true]}
             ) =~
               ~S|attr :stroke_linecap, :string, values: ["square", "round"], required: true|
    end

    test "escapes interpolation in attribute values" do
      # An SVG attribute value can contain `#{}`, which would be evaluated as
      # Elixir code during compilation.
      assert render_attr({"stroke", [default: ~S|#{1 + 1}|]}) =~
               ~S|attr :stroke, :string, default: "\#{1 + 1}"|
    end
  end

  describe "transform_svg/2" do
    test "adds aria-hidden to empty svg" do
      svg = "<svg></svg>"

      assert ExIcon.transform_svg(svg) ==
               {~s(<svg aria-hidden="true"></svg>), []}
    end

    test "returns strings without a closing tag unchanged" do
      assert ExIcon.transform_svg(~s(<svg stroke="currentColor"/>), ["stroke"]) ==
               {~s(<svg stroke="currentColor"/>), []}

      assert ExIcon.transform_svg("  not an svg  ", ["stroke"]) ==
               {"not an svg", []}
    end

    test "returns svg without attributes unchanged" do
      svg = """
      <svg>
        <path d="m12 19-7-7 7-7" />
        <path d="M19 12H5" />
      </svg>
      """

      assert ExIcon.transform_svg(svg) ==
               {"""
                <svg aria-hidden="true">
                  <path d="m12 19-7-7 7-7" />
                  <path d="M19 12H5" />
                </svg>\
                """, []}
    end

    test "does not add aria-hidden attribute if already present" do
      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path d="m12 19-7-7 7-7" />
        <path d="M19 12H5" />
      </svg>
      """

      assert ExIcon.transform_svg(svg) == {String.trim(svg), []}
    end

    test "transforms svg without inner content and extra attributes unchanged" do
      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      </svg>
      """

      assert ExIcon.transform_svg(svg) ==
               {"""
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">
                </svg>\
                """, []}
    end

    test "replaces attributes with HEEx variables" do
      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path d="m12 19-7-7 7-7" />
        <path d="M19 12H5" />
      </svg>
      """

      assert ExIcon.transform_svg(svg, ["stroke", "stroke-width"]) ==
               {"""
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width} aria-hidden="true">
                  <path d="m12 19-7-7 7-7" />
                  <path d="M19 12H5" />
                </svg>\
                """,
                [
                  {"stroke", [default: "currentColor"]},
                  {"stroke_width", [default: "2"]}
                ]}
    end

    test "replaces attributes with HEEx variables (with line breaks)" do
      assert ExIcon.transform_svg(
               """
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
               """,
               ["stroke", "stroke-width"]
             ) ==
               {"""
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width} aria-hidden="true">
                  <path d="m12 19-7-7 7-7" />
                  <path d="M19 12H5" />
                </svg>\
                """,
                [
                  {"stroke", [default: "currentColor"]},
                  {"stroke_width", [default: "2"]}
                ]}
    end

    test "attributes are case-insensitive" do
      svg = """
      <svg xmlNS="http://www.w3.org/2000/svg" WIDTH="24" heiGHt="24" viewbox="0 0 24 24" Stroke="currentColor" Stroke-Width="2">
        <path d="m12 19-7-7 7-7" />
        <path d="M19 12H5" />
      </svg>
      """

      assert ExIcon.transform_svg(svg, ["stroke"]) ==
               {"""
                <svg xmlNS="http://www.w3.org/2000/svg" WIDTH="24" heiGHt="24" viewbox="0 0 24 24" Stroke={@stroke} Stroke-Width="2" aria-hidden="true">
                  <path d="m12 19-7-7 7-7" />
                  <path d="M19 12H5" />
                </svg>\
                """, [{"stroke", [default: "currentColor"]}]}
    end

    test "overrides the default value of a component attribute" do
      svg = ~s(<svg stroke="currentColor" stroke-width="2"></svg>)

      assert ExIcon.transform_svg(svg, [
               "stroke",
               {"stroke-width", default: "1.5"}
             ]) ==
               {~s(<svg stroke={@stroke} stroke-width={@stroke_width} aria-hidden="true"></svg>),
                [
                  {"stroke", [default: "currentColor"]},
                  {"stroke_width", [default: "1.5"]}
                ]}
    end

    test "overrides an attribute value without adding a component attribute" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke", fixed: "red"}]) ==
               {~s(<svg stroke="red" aria-hidden="true"></svg>), []}
    end

    test "adds attributes that the svg does not have" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [
               {"fill", fixed: "none"},
               {"class", default: "size-6"}
             ]) ==
               {~s(<svg stroke="currentColor" fill="none" class={@class} aria-hidden="true"></svg>),
                [{"class", [default: "size-6"]}]}
    end

    test "adds attributes to an svg without attributes" do
      svg = ~s(<svg><path d="M19 12H5" /></svg>)

      assert ExIcon.transform_svg(svg, [{"class", default: "size-6"}]) ==
               {~s(<svg class={@class} aria-hidden="true"><path d="M19 12H5" /></svg>),
                [{"class", [default: "size-6"]}]}
    end

    test "ignores attribute names that the svg does not have" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, ["class"]) ==
               {~s(<svg stroke="currentColor" aria-hidden="true"></svg>), []}
    end

    test "overrides attributes case-insensitively" do
      svg = ~s(<svg Stroke-Width="2"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke-width", fixed: "1.5"}]) ==
               {~s(<svg Stroke-Width="1.5" aria-hidden="true"></svg>), []}
    end

    test "keeps aria-hidden set by the svg" do
      svg = ~s(<svg aria-hidden="false"></svg>)

      assert ExIcon.transform_svg(svg) ==
               {~s(<svg aria-hidden="false"></svg>), []}
    end

    test "restricts a component attribute to the given values" do
      svg = ~s(<svg stroke-linecap="round"></svg>)

      assert ExIcon.transform_svg(svg, [
               {"stroke-linecap", values: ["square", "round"]}
             ]) ==
               {~s(<svg stroke-linecap={@stroke_linecap} aria-hidden="true"></svg>),
                [
                  {"stroke_linecap",
                   [values: ["square", "round"], default: "round"]}
                ]}
    end

    test "combines values with an explicit default" do
      svg = ~s(<svg stroke-linecap="round"></svg>)

      assert ExIcon.transform_svg(svg, [
               {"stroke-linecap",
                values: ["square", "round"], default: "square"}
             ]) ==
               {~s(<svg stroke-linecap={@stroke_linecap} aria-hidden="true"></svg>),
                [
                  {"stroke_linecap",
                   [values: ["square", "round"], default: "square"]}
                ]}
    end

    test "adds an optional attribute with a nil default" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"class", default: nil}]) ==
               {~s(<svg stroke="currentColor" class={@class} aria-hidden="true"></svg>),
                [{"class", [default: nil]}]}
    end

    test "a nil default overrides the value of the svg" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke", default: nil}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: nil]}]}
    end

    test "allows nil as one of the values" do
      assert ExIcon.transform_svg(~s(<svg stroke-width="2"></svg>), [
               {"stroke-width", values: ["2", "4", nil], default: nil}
             ]) ==
               {~s(<svg stroke-width={@stroke_width} aria-hidden="true"></svg>),
                [{"stroke_width", [values: ["2", "4", nil], default: nil]}]}
    end

    test "adds a required attribute" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke-width", required: true}]) ==
               {~s(<svg stroke="currentColor" stroke-width={@stroke_width} aria-hidden="true"></svg>),
                [{"stroke_width", [required: true]}]}
    end

    test "a required attribute has no default, not even from the svg" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke", required: true}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [required: true]}]}
    end

    test "combines required with values" do
      assert ExIcon.transform_svg(~s(<svg></svg>), [
               {"stroke-linecap", required: true, values: ["square", "round"]}
             ]) ==
               {~s(<svg stroke-linecap={@stroke_linecap} aria-hidden="true"></svg>),
                [
                  {"stroke_linecap",
                   [values: ["square", "round"], required: true]}
                ]}
    end

    test "required: false keeps the default from the svg" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"stroke", required: false}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "requires the attribute if values are given without a default" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [
               {"stroke-linecap", values: ["square", "round"]}
             ]) ==
               {~s(<svg stroke="currentColor" stroke-linecap={@stroke_linecap} aria-hidden="true"></svg>),
                [
                  {"stroke_linecap",
                   [values: ["square", "round"], required: true]}
                ]}
    end

    test "raises if the value in the svg is not one of the given values" do
      svg = ~s(<svg stroke-linecap="butt"></svg>)

      assert_raise ArgumentError,
                   ~r/"butt" is not one of \["square", "round"\]/,
                   fn ->
                     ExIcon.transform_svg(svg, [
                       {"stroke-linecap", values: ["square", "round"]}
                     ])
                   end
    end

    test "adds aria-hidden if neither the svg nor the options set it" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, ["stroke"]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "turns aria-hidden into a component attribute defaulting to true" do
      assert ExIcon.transform_svg(~s(<svg></svg>), ["aria-hidden"]) ==
               {~s(<svg aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [default: "true"]}]}
    end

    test "keeps the casing of aria-hidden set by the svg" do
      assert ExIcon.transform_svg(~s(<svg ARIA-HIDDEN="false"></svg>)) ==
               {~s(<svg ARIA-HIDDEN="false"></svg>), []}
    end

    test "allows setting aria-hidden to a fixed value" do
      assert ExIcon.transform_svg(~s(<svg></svg>), [
               {"aria-hidden", fixed: "false"}
             ]) == {~s(<svg aria-hidden="false"></svg>), []}
    end

    test "requires aria-hidden if values are given without a default" do
      assert ExIcon.transform_svg(~s(<svg></svg>), [
               {"aria-hidden", values: ["true", "false"]}
             ]) ==
               {~s(<svg aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [values: ["true", "false"], required: true]}]}
    end

    test "allows configuring aria-hidden" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert ExIcon.transform_svg(svg, [{"aria-hidden", default: "true"}]) ==
               {~s(<svg stroke="currentColor" aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [default: "true"]}]}
    end
  end

  describe "targets/1" do
    test "returns a single target without variants" do
      assert ExIcon.targets(
               icons: :all,
               provider: ExIcon.Lucide,
               version: "1.8.0",
               module_path: "lib/components/lucide.ex",
               module_name: MyAppWeb.Components.Lucide
             ) ==
               [
                 {"icons", MyAppWeb.Components.Lucide,
                  "lib/components/lucide.ex"}
               ]
    end

    test "returns a target per configured variant" do
      assert ExIcon.targets(
               icons: :all,
               provider: ExIcon.Heroicons,
               version: "2.2.0",
               module_path: "lib/components/heroicons.ex",
               module_name: MyAppWeb.Components.Heroicons,
               variants: [:outline, :mini]
             ) ==
               [
                 {"heroicons-2.2.0/optimized/24/outline",
                  MyAppWeb.Components.Heroicons.Outline,
                  "lib/components/heroicons/outline.ex"},
                 {"heroicons-2.2.0/optimized/20/solid",
                  MyAppWeb.Components.Heroicons.Mini,
                  "lib/components/heroicons/mini.ex"}
               ]
    end

    test "raises for an unknown variant" do
      assert_raise ArgumentError, ~r/unknown variant :outlined/, fn ->
        ExIcon.targets(
          icons: :all,
          provider: ExIcon.Heroicons,
          version: "2.2.0",
          module_path: "lib/components/heroicons.ex",
          module_name: MyAppWeb.Components.Heroicons,
          variants: [:outlined]
        )
      end
    end

    test "raises if the provider has no variants" do
      assert_raise ArgumentError, ~r/not supported by ExIcon.Lucide/, fn ->
        ExIcon.targets(
          icons: :all,
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide,
          variants: [:outline]
        )
      end
    end
  end

  describe "download/2" do
    @describetag :tmp_dir

    test "reuses a cached release without downloading again", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      icon_dir = Path.join([tmp_dir, "lucide", "1.8.0"])
      svg_dir = Path.join(icon_dir, "icons")
      File.mkdir_p!(svg_dir)
      File.write!(Path.join(svg_dir, "cached.svg"), "<svg></svg>")

      assert ExIcon.download(tmp_dir, opts) == icon_dir
      assert File.read!(Path.join(svg_dir, "cached.svg")) == "<svg></svg>"
    end

    test "downloads again when forced", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: UnreachableProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      icon_dir = Path.join([tmp_dir, "unreachable_provider", "1.0.0"])
      svg_dir = Path.join(icon_dir, "icons")
      File.mkdir_p!(svg_dir)

      assert ExIcon.download(tmp_dir, opts) == icon_dir

      capture_io(fn ->
        assert_raise RuntimeError, ~r/unable to fetch icons/, fn ->
          ExIcon.download(tmp_dir, opts, force: true)
        end
      end)

      refute File.dir?(svg_dir)
    end

    test "leaves no staging folder behind when the download fails", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: UnreachableProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      capture_io(fn ->
        assert_raise RuntimeError, ~r/unable to fetch icons/, fn ->
          ExIcon.download(tmp_dir, opts)
        end
      end)

      refute File.dir?(Path.join([tmp_dir, "unreachable_provider", "1.0.0"]))
      assert File.ls!(Path.join(tmp_dir, "unreachable_provider")) == []
    end
  end

  describe "unpack_archive!/2" do
    @describetag :tmp_dir

    test "unpacks a regular archive", %{tmp_dir: tmp_dir} do
      zip = build_zip([{~c"icons/arrow-left.svg", "<svg></svg>"}])
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.unpack_archive!(zip, target) == :ok

      assert File.read!(Path.join([target, "icons", "arrow-left.svg"])) ==
               "<svg></svg>"
    end

    test "refuses entries that escape the target folder", %{tmp_dir: tmp_dir} do
      zip =
        build_zip([
          {~c"icons/arrow-left.svg", "<svg></svg>"},
          {~c"../escaped.svg", "<svg></svg>"}
        ])

      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []
      refute File.exists?(Path.join(tmp_dir, "escaped.svg"))
    end

    test "refuses entries with an absolute path", %{tmp_dir: tmp_dir} do
      zip = build_zip_with_absolute_entry()
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []
    end
  end

  describe "indent/2" do
    test "indents a multi-line string" do
      assert ExIcon.indent(
               """
               <span>
                 Hello
               </span>
               """,
               4
             ) == """
                 <span>
                   Hello
                 </span>
             """
    end
  end

  describe "read_config/1" do
    @describetag :tmp_dir
    test "returns a valid configuration", %{tmp_dir: tmp_dir} do
      config = [
        lucide: [
          icons: ["arrow-left", "arrow-right"],
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/my_app_web/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide,
          attrs: ["stroke"]
        ]
      ]

      path = Path.join(tmp_dir, ".ex_icon.exs")
      File.write!(path, inspect(config))

      assert {:ok, [lucide: read_config]} = ExIcon.read_config(path)
      assert Keyword.get(read_config, :icons) == ["arrow-left", "arrow-right"]
      assert Keyword.get(read_config, :attrs) == ["stroke"]
      assert Keyword.get(read_config, :variants) == []
    end

    test "returns error if file is not found", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, ".ex_icon.exs")
      assert ExIcon.read_config(path) == {:error, :enoent}
    end

    test "returns error if configuration is invalid", %{tmp_dir: tmp_dir} do
      config = [
        lucide: %{
          icons: ["arrow-left", "arrow-right"],
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/my_app_web/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide
        }
      ]

      path = Path.join(tmp_dir, ".ex_icon.exs")
      File.write!(path, inspect(config))

      assert {:error, %NimbleOptions.ValidationError{}} =
               ExIcon.read_config(path)
    end
  end

  describe "validate_config/1" do
    test "returns schema that accepts config with list of icons" do
      config = [
        lucide: [
          icons: ["arrow-left", "arrow-right"],
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/my_app_web/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide
        ]
      ]

      assert {:ok, _} = ExIcon.validate_config(config)
    end

    test "returns schema that accepts config with all icons" do
      config = [
        lucide: [
          icons: :all,
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/my_app_web/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide
        ]
      ]

      assert {:ok, _} = ExIcon.validate_config(config)
    end

    test "accepts attribute options" do
      assert {:ok, _} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     "stroke",
                     {"stroke-width", default: "1.5"},
                     {"stroke-linecap", values: ["square", "round"]},
                     {"stroke-linejoin",
                      values: ["arcs", "miter"], default: "miter"},
                     {"fill", fixed: "none"}
                   ])
               )
    end

    test "returns error if attribute sets both a default and a fixed value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([{"stroke", default: "red", fixed: "red"}])
               )

      assert Exception.message(error) =~ "sets both :default and :fixed"
    end

    test "returns error regardless of the order of the attribute options" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([{"stroke", fixed: "red", default: "red"}])
               )

      assert Exception.message(error) =~ "sets both :default and :fixed"
    end

    test "returns error if an attribute sets both values and a fixed value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke", fixed: "red", values: ["red", "blue"]}
                   ])
               )

      assert Exception.message(error) =~ "sets both :values and :fixed"
    end

    test "returns error if an attribute is configured more than once" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke", default: "red"},
                     {"STROKE", default: "blue"}
                   ])
               )

      assert Exception.message(error) =~
               ~s(attribute "stroke" is configured more than once)
    end

    test "returns error if an attribute sets both a default and required" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke", default: "red", required: true}
                   ])
               )

      assert Exception.message(error) =~ "sets both :default and :required"
    end

    test "returns error if an attribute sets both required and a fixed value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([{"stroke", required: true, fixed: "red"}])
               )

      assert Exception.message(error) =~ "sets both :required and :fixed"
    end

    test "returns error if a nil default is not one of the values" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke-width", values: ["2", "4"], default: nil}
                   ])
               )

      assert Exception.message(error) =~
               ~s(has the default value nil, which is not one of ["2", "4"])
    end

    test "accepts a nil default if nil is one of the values" do
      assert {:ok, _} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke-width", values: ["2", "4", nil], default: nil}
                   ])
               )
    end

    test "returns error if the values list is empty" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide: config_with_attrs([{"stroke", values: []}])
               )

      assert Exception.message(error) =~ "has an empty :values list"
    end

    test "returns error if attrs is not a list" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(lucide: config_with_attrs("stroke"))

      assert Exception.message(error) =~ "expected a list of attributes"
    end

    test "returns error if an attribute is neither a string nor a tuple" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(lucide: config_with_attrs([:stroke]))

      assert Exception.message(error) =~
               "expected an attribute name or a {name, options} tuple"
    end

    test "returns error if the default is not one of the values" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide:
                   config_with_attrs([
                     {"stroke-linecap",
                      values: ["square", "round"], default: "butt"}
                   ])
               )

      assert Exception.message(error) =~
               ~s(has the default value "butt", which is not one of)
    end

    test "returns error if an attribute has an unknown option" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide: config_with_attrs([{"stroke", fallback: "red"}])
               )

      assert Exception.message(error) =~
               ~s(attribute "stroke": unknown options [:fallback])
    end

    test "returns error if an attribute value is not a string" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               ExIcon.validate_config(
                 lucide: config_with_attrs([{"stroke-width", default: 2}])
               )

      assert Exception.message(error) =~
               ~s(invalid value for :default option: expected string, got: 2)
    end
  end

  defp config_with_attrs(attrs) do
    [
      icons: :all,
      provider: ExIcon.Lucide,
      version: "1.8.0",
      module_path: "lib/my_app_web/components/lucide.ex",
      module_name: MyAppWeb.Components.Lucide,
      attrs: attrs
    ]
  end

  defp render_attr(attr) do
    assigns = [
      icons: [{"arrow_left", {"<svg></svg>", [attr]}}],
      module_name: MyAppWeb.Components.Lucide
    ]

    EEx.eval_file(ExIcon.template_path(), assigns: assigns)
  end

  defp build_zip(entries) do
    {:ok, {_name, zip}} = :zip.create(~c"icons.zip", entries, [:memory])
    zip
  end

  defp build_zip_with_absolute_entry do
    ~c"_abs/escaped.svg"
    |> then(&build_zip([{&1, "<svg></svg>"}]))
    |> String.replace("_abs/escaped.svg", "/abs/escaped.svg")
  end
end
