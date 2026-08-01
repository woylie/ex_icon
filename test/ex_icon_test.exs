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

  defmodule LocalProvider do
    @behaviour ExIcon.Provider

    @impl true
    def release_url(version) do
      "#{Application.fetch_env!(:ex_icon, :test_base_url)}/#{version}.zip"
    end

    @impl true
    def svg_folder(_), do: "icons"

    @impl true
    def variants(_), do: %{plain: "icons", nested: "icons/nested"}
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

    test "reports and fails for a configured icon that cannot be read", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: ["arrow-left", "does-not-exist"],
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")

      output =
        capture_io(fn ->
          assert_raise ArgumentError,
                       ~r/could not generate every configured icon/,
                       fn -> ExIcon.prepare_assigns(tmp_dir, opts) end
        end)

      assert output =~ "Could not read file"
      assert output =~ "does-not-exist.svg"
    end

    test "skips an icon of :all that cannot be read", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "broken.svg"), "<svg><script /></svg>")

      output =
        capture_io(fn ->
          assert [
                   icons: [{"arrow_left", _}],
                   module_name: MyAppWeb.Components.Lucide
                 ] = ExIcon.prepare_assigns(tmp_dir, opts)
        end)

      assert output =~ "Skipping broken.svg"
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

    test "prefixes icon names that start with a digit", %{tmp_dir: tmp_dir} do
      opts = [
        icons: ["1password"],
        provider: ExIcon.SimpleIcons,
        version: "15.0.0",
        module_path: Path.join(tmp_dir, "lib/components/simple_icons.ex"),
        module_name: MyAppWeb.Components.SimpleIcons
      ]

      File.write!(Path.join(tmp_dir, "1password.svg"), "<svg></svg>")

      assert [
               icons: [{"icon_1password", _}],
               module_name: MyAppWeb.Components.SimpleIcons
             ] = ExIcon.prepare_assigns(tmp_dir, opts)
    end

    test "skips icon names that are not valid function names", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      injection = "pwn(_a), do: :erlang.display(:INJECTED)\n  def filler"
      File.write!(Path.join(tmp_dir, "#{injection}.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")

      output =
        capture_io(fn ->
          assert [
                   icons: [{"arrow_left", _}],
                   module_name: MyAppWeb.Components.Lucide
                 ] = ExIcon.prepare_assigns(tmp_dir, opts)
        end)

      assert output =~ "icon names must match"
    end

    test "skips excluded icons", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        exclude: ["arrow-right"],
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "arrow-right.svg"), "<svg></svg>")

      assert [
               icons: [{"arrow_left", _}],
               module_name: MyAppWeb.Components.Lucide
             ] = ExIcon.prepare_assigns(tmp_dir, opts)
    end

    test "skips and reports icons that cannot be parsed", %{tmp_dir: tmp_dir} do
      opts = [
        icons: ["arrow-left", "broken"],
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")

      File.write!(
        Path.join(tmp_dir, "broken.svg"),
        ~s|<svg><script>alert(1)</script></svg>|
      )

      output =
        capture_io(fn ->
          assert_raise ArgumentError,
                       ~r/could not generate every configured icon/,
                       fn -> ExIcon.prepare_assigns(tmp_dir, opts) end
        end)

      assert output =~ "Skipping broken.svg"
      assert output =~ "the <script> element is not allowed"
    end

    test "an icon cannot add code to the generated module", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      # a body line of """ would close the heredoc of the generated component
      File.write!(Path.join(tmp_dir, "evil.svg"), """
      <svg xmlns="http://www.w3.org/2000/svg"><title>
      \"\"\"
        end

        def pwned(_assigns) do
          :erlang.display(:INJECTED)
          ~H\"\"\"
      </title></svg>
      """)

      assigns = ExIcon.prepare_assigns(tmp_dir, opts)
      source = EEx.eval_file(ExIcon.template_path(), assigns: assigns)

      functions =
        source
        |> Code.string_to_quoted!()
        |> Macro.prewalk([], fn
          {:def, _meta, [{name, _, _} | _]} = node, acc -> {node, [name | acc]}
          node, acc -> {node, acc}
        end)
        |> elem(1)

      assert functions == [:evil]
    end

    test "raises if two icons map to the same function name", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: ["1password", "icon-1password"],
        provider: ExIcon.SimpleIcons,
        version: "15.0.0",
        module_path: Path.join(tmp_dir, "lib/components/simple_icons.ex"),
        module_name: MyAppWeb.Components.SimpleIcons
      ]

      File.write!(Path.join(tmp_dir, "1password.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "icon-1password.svg"), "<svg></svg>")

      assert_raise ArgumentError, ~r/"icon_1password"/, fn ->
        ExIcon.prepare_assigns(tmp_dir, opts)
      end
    end
  end

  describe "verify_module!/1" do
    @valid """
    defmodule Generated do
      @moduledoc "Provides function components for icons."
      use Phoenix.Component

      attr :stroke, :string, default: "currentColor"

      def arrow_left(assigns) do
        ~H\"\"\"
        <svg></svg>
        \"\"\"
      end
    end
    """

    test "accepts a generated module" do
      assert ExIcon.verify_module!(@valid) == :ok
    end

    test "accepts a module with a single expression in its body" do
      assert ExIcon.verify_module!("""
             defmodule G do
               @moduledoc "x"
             end
             """) == :ok
    end

    test "refuses an added function" do
      contents =
        String.replace(
          @valid,
          "  def arrow_left",
          "  def pwned(_a), do: :x\n\n  def arrow_left"
        )

      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!(contents)
      end
    end

    test "refuses an added module attribute" do
      contents =
        String.replace(
          @valid,
          "  use Phoenix.Component",
          ~s|  use Phoenix.Component\n  @x System.cmd("id", [])|
        )

      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!(contents)
      end
    end

    test "refuses an attribute option that is not a literal" do
      contents =
        String.replace(
          @valid,
          ~s|default: "currentColor"|,
          ~s|default: System.get_env("X")|
        )

      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!(contents)
      end
    end

    test "refuses a moduledoc that is not a string" do
      contents =
        String.replace(
          @valid,
          ~s|@moduledoc "Provides function components for icons."|,
          "@moduledoc false"
        )

      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!(contents)
      end
    end

    test "refuses a component that is not a heex sigil" do
      contents =
        String.replace(
          @valid,
          ~r/def arrow_left\(assigns\) do.*?end/s,
          "def arrow_left(assigns), do: assigns"
        )

      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!(contents)
      end
    end

    test "refuses source that does not parse" do
      assert_raise RuntimeError, ~r/does not belong to an icon/, fn ->
        ExIcon.verify_module!("defmodule G do")
      end
    end
  end

  describe "template rendering" do
    test "generates the component documented in the readme" do
      svg = """
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
      </svg>
      """

      attrs = [
        "stroke",
        {"stroke-width", default: "1.5"},
        {"stroke-linecap", values: ["square", "round"]},
        {"class", required: true},
        {"stroke-dasharray", default: nil},
        {"fill", fixed: "none"}
      ]

      {transformed, component_attrs} = ExIcon.transform_svg(svg, attrs)

      declarations =
        Enum.map_join(component_attrs, "\n", fn {name, opts} ->
          "attr :#{name}, :string, #{ExIcon.render_attr_options(opts)}"
        end)

      assert declarations == """
             attr :stroke, :string, default: "currentColor"
             attr :stroke_width, :string, default: "1.5"
             attr :stroke_linecap, :string, values: ["square", "round"], default: "round"
             attr :class, :string, required: true
             attr :stroke_dasharray, :string, default: nil\
             """

      assert transformed =~
               ~s(<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" ) <>
                 ~s(viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width} ) <>
                 ~s(stroke-linecap={@stroke_linecap} class={@class} ) <>
                 ~s(stroke-dasharray={@stroke_dasharray} fill="none" aria-hidden="true">)
    end

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

    test "handles a self-closing root element" do
      assert ExIcon.transform_svg(
               ~s(<svg stroke="currentColor"/>),
               ["stroke"]
             ) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "raises if the file is not an svg" do
      assert_raise ArgumentError, ~r/invalid SVG/, fn ->
        ExIcon.transform_svg("  not an svg  ", ["stroke"])
      end
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

    test "raises if the provider cannot be loaded" do
      assert_raise ArgumentError, ~r/could not load the provider/, fn ->
        ExIcon.targets(
          icons: :all,
          provider: NoSuchProvider,
          version: "1.0.0",
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons,
          variants: [:outline]
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

  describe "download/3 with a served release" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      {:ok, _} = Application.ensure_all_started(:inets)

      served = Path.join(tmp_dir, "served")
      File.mkdir_p!(served)

      {:ok, {_name, zip}} =
        :zip.create(
          ~c"1.0.0.zip",
          [
            {~c"icons/arrow-left.svg", "<svg></svg>"},
            {~c"icons/nested/bell.svg", "<svg></svg>"}
          ],
          [:memory]
        )

      File.write!(Path.join(served, "1.0.0.zip"), zip)

      {:ok, httpd} =
        :inets.start(:httpd,
          port: 0,
          server_name: ~c"ex_icon_test",
          server_root: String.to_charlist(served),
          document_root: String.to_charlist(served),
          bind_address: {127, 0, 0, 1}
        )

      port = Keyword.fetch!(:httpd.info(httpd), :port)
      Application.put_env(:ex_icon, :test_base_url, "http://127.0.0.1:#{port}")

      on_exit(fn ->
        :inets.stop(:httpd, httpd)
        Application.delete_env(:ex_icon, :test_base_url)
      end)

      cache_dir = Path.join(tmp_dir, "cache")

      opts = [
        icons: :all,
        provider: LocalProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      %{cache_dir: cache_dir, opts: opts}
    end

    test "downloads and unpacks the release into the cache", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      {icon_dir, output} = with_io(fn -> ExIcon.download(cache_dir, opts) end)

      assert output =~ "Downloading local_provider 1.0.0..."

      assert icon_dir ==
               Path.join([cache_dir, "ex_icon_test_local_provider", "1.0.0"])

      assert File.read!(Path.join([icon_dir, "icons", "arrow-left.svg"])) ==
               "<svg></svg>"

      assert File.ls!(Path.join(cache_dir, "ex_icon_test_local_provider")) == [
               "1.0.0"
             ]
    end

    test "reuses the cached release on the next call", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      capture_io(fn -> ExIcon.download(cache_dir, opts) end)

      marker =
        Path.join([cache_dir, "ex_icon_test_local_provider", "1.0.0", "marker"])

      File.write!(marker, "kept")

      assert capture_io(fn -> ExIcon.download(cache_dir, opts) end) == ""
      assert File.read!(marker) == "kept"
    end

    test "downloads again with the force option", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      capture_io(fn -> ExIcon.download(cache_dir, opts) end)

      marker =
        Path.join([cache_dir, "ex_icon_test_local_provider", "1.0.0", "marker"])

      File.write!(marker, "discarded")

      assert capture_io(fn ->
               ExIcon.download(cache_dir, opts, force: true)
             end) =~ "Downloading local_provider 1.0.0..."

      refute File.exists?(marker)

      assert File.exists?(
               Path.join([
                 cache_dir,
                 "ex_icon_test_local_provider",
                 "1.0.0",
                 "icons"
               ])
             )
    end

    test "raises if the release cannot be moved into the cache", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      icon_dir = Path.join([cache_dir, "ex_icon_test_local_provider", "1.0.0"])
      File.mkdir_p!(Path.dirname(icon_dir))
      File.write!(icon_dir, "not a folder")

      capture_io(fn ->
        assert_raise RuntimeError,
                     ~r/Unable to move the downloaded icons into the cache/,
                     fn -> ExIcon.download(cache_dir, opts) end
      end)

      assert File.ls!(Path.dirname(icon_dir)) == ["1.0.0"]
    end

    test "unpacks the folder of every variant from a single download", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      opts = Keyword.put(opts, :variants, [:plain, :nested])

      {icon_dir, _output} = with_io(fn -> ExIcon.download(cache_dir, opts) end)

      for {svg_folder, _module_name, _module_path} <- ExIcon.targets(opts) do
        assert File.dir?(Path.join(icon_dir, svg_folder))
      end
    end
  end

  describe "download/3" do
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

      icon_dir = Path.join([tmp_dir, "ex_icon_lucide", "1.8.0"])
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

      icon_dir =
        Path.join([tmp_dir, "ex_icon_test_unreachable_provider", "1.0.0"])

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

      refute File.dir?(
               Path.join([
                 tmp_dir,
                 "ex_icon_test_unreachable_provider",
                 "1.0.0"
               ])
             )

      assert File.ls!(Path.join(tmp_dir, "ex_icon_test_unreachable_provider")) ==
               []
    end
  end

  describe "download/3 validation" do
    @describetag :tmp_dir

    defmodule PlainHttpProvider do
      @behaviour ExIcon.Provider
      @impl true
      def release_url(_), do: "http://example.com/icons.zip"
      @impl true
      def svg_folder(_), do: "icons"
    end

    test "raises for a version that is not a plain version", %{
      tmp_dir: tmp_dir
    } do
      for version <- ["../../etc", "1.0.0/../..", ".."] do
        opts = [provider: UnreachableProvider, version: version]

        assert_raise ArgumentError, ~r/invalid version/, fn ->
          ExIcon.download(tmp_dir, opts)
        end
      end
    end

    test "raises for a release URL that is not https", %{tmp_dir: tmp_dir} do
      opts = [provider: PlainHttpProvider, version: "1.0.0"]

      capture_io(fn ->
        assert_raise ArgumentError, ~r/invalid release URL/, fn ->
          ExIcon.download(tmp_dir, opts)
        end
      end)
    end

    test "keeps providers apart that share the last name segment", %{
      tmp_dir: tmp_dir
    } do
      capture_io(fn ->
        assert_raise RuntimeError, fn ->
          ExIcon.download(tmp_dir,
            provider: UnreachableProvider,
            version: "1.0.0"
          )
        end
      end)

      assert File.ls!(tmp_dir) == ["ex_icon_test_unreachable_provider"]
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

    test "raises if the archive is not a zip file", %{tmp_dir: tmp_dir} do
      assert_raise RuntimeError, ~r/Unable to unpack zip archive/, fn ->
        ExIcon.unpack_archive!("not a zip archive", tmp_dir)
      end
    end

    test "raises if the archive cannot be unpacked", %{tmp_dir: tmp_dir} do
      target = Path.join(tmp_dir, "read-only")
      File.mkdir_p!(target)
      File.chmod!(target, 0o500)
      on_exit(fn -> File.chmod(target, 0o700) end)

      zip = build_zip([{~c"icons/arrow-left.svg", "<svg></svg>"}])

      assert_raise RuntimeError, ~r/Unable to unpack zip archive/, fn ->
        ExIcon.unpack_archive!(zip, target)
      end
    end

    test "refuses an archive that declares more than the size cap", %{
      tmp_dir: tmp_dir
    } do
      zip = build_zip([{~c"icons/big.svg", String.duplicate("A", 5000)}])
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/unpacks to more than/, fn ->
        ExIcon.unpack_archive!(zip, target, max_size: 1024)
      end

      assert File.ls!(target) == []
    end

    test "refuses an archive that unpacks to more than the size cap", %{
      tmp_dir: tmp_dir
    } do
      zip = build_zip_with_understated_size()
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/unpacks to more than/, fn ->
        ExIcon.unpack_archive!(zip, target, max_size: 1024)
      end
    end

    test "normalizes the modes of the unpacked files", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      File.mkdir_p!(Path.join(source, "icons"))
      icon = Path.join([source, "icons", "arrow-left.svg"])
      File.write!(icon, "<svg></svg>")
      File.chmod!(icon, 0o777)

      zip_path = Path.join(tmp_dir, "modes.zip")

      {:ok, _} =
        :zip.create(String.to_charlist(zip_path), [~c"icons"],
          cwd: String.to_charlist(source)
        )

      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.unpack_archive!(File.read!(zip_path), target) == :ok

      unpacked = Path.join([target, "icons", "arrow-left.svg"])
      assert File.stat!(unpacked).mode == 0o100644
      assert File.stat!(Path.join(target, "icons")).mode == 0o40755
    end

    @tag :capture_log
    test "keeps traversing entries inside the target folder", %{
      tmp_dir: tmp_dir
    } do
      zip =
        build_zip([
          {~c"../escaped.svg", "<svg></svg>"},
          {~c"icons/../../escaped-too.svg", "<svg></svg>"},
          {~c"./../escaped-again.svg", "<svg></svg>"}
        ])

      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.unpack_archive!(zip, target) == :ok

      assert Enum.sort(File.ls!(target)) ==
               ["escaped-again.svg", "escaped-too.svg", "escaped.svg"]

      assert File.ls!(tmp_dir) == ["target"]
    end

    @tag :capture_log
    test "keeps absolute entries inside the target folder", %{tmp_dir: tmp_dir} do
      zip = build_zip_with_absolute_entry()
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.unpack_archive!(zip, target) == :ok

      assert File.exists?(Path.join([target, "abs", "escaped.svg"]))
      assert File.ls!(tmp_dir) == ["target"]
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

  defp build_zip_with_understated_size do
    zip = build_zip([{~c"icons/big.svg", String.duplicate("A", 5000)}])
    {position, _length} = :binary.match(zip, <<0x50, 0x4B, 0x01, 0x02>>)
    offset = position + 24

    binary_part(zip, 0, offset) <>
      <<100::little-32>> <>
      binary_part(zip, offset + 4, byte_size(zip) - offset - 4)
  end

  defp build_zip_with_absolute_entry do
    ~c"_abs/escaped.svg"
    |> then(&build_zip([{&1, "<svg></svg>"}]))
    |> String.replace("_abs/escaped.svg", "/abs/escaped.svg")
  end
end
