defmodule ExIconTest do
  use ExUnit.Case
  doctest ExIcon

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

      assert attrs == [{"stroke", "currentColor"}, {"stroke_width", "2"}]
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

  describe "transform_svg/2" do
    test "adds aria-hidden to empty svg" do
      svg = "<svg></svg>"

      assert ExIcon.transform_svg(svg) ==
               {~s(<svg aria-hidden="true"></svg>), []}
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
                """, [{"stroke", "currentColor"}, {"stroke_width", "2"}]}
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
                """, [{"stroke", "currentColor"}, {"stroke_width", "2"}]}
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
                """, [{"stroke", "currentColor"}]}
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

      assert ExIcon.read_config(path) == {:ok, config}
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
  end
end
