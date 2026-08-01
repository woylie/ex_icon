defmodule ExIcon.AttrsTest do
  use ExUnit.Case, async: true

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

      {transformed, component_attrs} = transform_svg(svg, attrs)

      declarations =
        Enum.map_join(component_attrs, "\n", fn {name, opts} ->
          "attr :#{name}, :string, #{ExIcon.Attrs.render_attr_options(opts)}"
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

  describe "transform_parsed/3" do
    test "adds aria-hidden to empty svg" do
      svg = "<svg></svg>"

      assert transform_svg(svg) ==
               {~s(<svg aria-hidden="true"></svg>), []}
    end

    test "handles a self-closing root element" do
      assert transform_svg(
               ~s(<svg stroke="currentColor"/>),
               ["stroke"]
             ) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "returns svg without attributes unchanged" do
      svg = """
      <svg>
        <path d="m12 19-7-7 7-7" />
        <path d="M19 12H5" />
      </svg>
      """

      assert transform_svg(svg) ==
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

      assert transform_svg(svg) == {String.trim(svg), []}
    end

    test "transforms svg without inner content and extra attributes unchanged" do
      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      </svg>
      """

      assert transform_svg(svg) ==
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

      assert transform_svg(svg, ["stroke", "stroke-width"]) ==
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
      assert transform_svg(
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

      assert transform_svg(svg, ["stroke"]) ==
               {"""
                <svg xmlNS="http://www.w3.org/2000/svg" WIDTH="24" heiGHt="24" viewbox="0 0 24 24" Stroke={@stroke} Stroke-Width="2" aria-hidden="true">
                  <path d="m12 19-7-7 7-7" />
                  <path d="M19 12H5" />
                </svg>\
                """, [{"stroke", [default: "currentColor"]}]}
    end

    test "overrides the default value of a component attribute" do
      svg = ~s(<svg stroke="currentColor" stroke-width="2"></svg>)

      assert transform_svg(svg, [
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

      assert transform_svg(svg, [{"stroke", fixed: "red"}]) ==
               {~s(<svg stroke="red" aria-hidden="true"></svg>), []}
    end

    test "adds attributes that the svg does not have" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [
               {"fill", fixed: "none"},
               {"class", default: "size-6"}
             ]) ==
               {~s(<svg stroke="currentColor" fill="none" class={@class} aria-hidden="true"></svg>),
                [{"class", [default: "size-6"]}]}
    end

    test "adds attributes to an svg without attributes" do
      svg = ~s(<svg><path d="M19 12H5" /></svg>)

      assert transform_svg(svg, [{"class", default: "size-6"}]) ==
               {~s(<svg class={@class} aria-hidden="true"><path d="M19 12H5" /></svg>),
                [{"class", [default: "size-6"]}]}
    end

    test "ignores attribute names that the svg does not have" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, ["class"]) ==
               {~s(<svg stroke="currentColor" aria-hidden="true"></svg>), []}
    end

    test "overrides attributes case-insensitively" do
      svg = ~s(<svg Stroke-Width="2"></svg>)

      assert transform_svg(svg, [{"stroke-width", fixed: "1.5"}]) ==
               {~s(<svg Stroke-Width="1.5" aria-hidden="true"></svg>), []}
    end

    test "keeps aria-hidden set by the svg" do
      svg = ~s(<svg aria-hidden="false"></svg>)

      assert transform_svg(svg) ==
               {~s(<svg aria-hidden="false"></svg>), []}
    end

    test "restricts a component attribute to the given values" do
      svg = ~s(<svg stroke-linecap="round"></svg>)

      assert transform_svg(svg, [
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

      assert transform_svg(svg, [
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

      assert transform_svg(svg, [{"class", default: nil}]) ==
               {~s(<svg stroke="currentColor" class={@class} aria-hidden="true"></svg>),
                [{"class", [default: nil]}]}
    end

    test "a nil default overrides the value of the svg" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [{"stroke", default: nil}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: nil]}]}
    end

    test "allows nil as one of the values" do
      assert transform_svg(~s(<svg stroke-width="2"></svg>), [
               {"stroke-width", values: ["2", "4", nil], default: nil}
             ]) ==
               {~s(<svg stroke-width={@stroke_width} aria-hidden="true"></svg>),
                [{"stroke_width", [values: ["2", "4", nil], default: nil]}]}
    end

    test "adds a required attribute" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [{"stroke-width", required: true}]) ==
               {~s(<svg stroke="currentColor" stroke-width={@stroke_width} aria-hidden="true"></svg>),
                [{"stroke_width", [required: true]}]}
    end

    test "a required attribute has no default, not even from the svg" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [{"stroke", required: true}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [required: true]}]}
    end

    test "combines required with values" do
      assert transform_svg(~s(<svg></svg>), [
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

      assert transform_svg(svg, [{"stroke", required: false}]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "requires the attribute if values are given without a default" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [
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
                     transform_svg(svg, [
                       {"stroke-linecap", values: ["square", "round"]}
                     ])
                   end
    end

    test "adds aria-hidden if neither the svg nor the options set it" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, ["stroke"]) ==
               {~s(<svg stroke={@stroke} aria-hidden="true"></svg>),
                [{"stroke", [default: "currentColor"]}]}
    end

    test "turns aria-hidden into a component attribute defaulting to true" do
      assert transform_svg(~s(<svg></svg>), ["aria-hidden"]) ==
               {~s(<svg aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [default: "true"]}]}
    end

    test "keeps the casing of aria-hidden set by the svg" do
      assert transform_svg(~s(<svg ARIA-HIDDEN="false"></svg>)) ==
               {~s(<svg ARIA-HIDDEN="false"></svg>), []}
    end

    test "allows setting aria-hidden to a fixed value" do
      assert transform_svg(~s(<svg></svg>), [
               {"aria-hidden", fixed: "false"}
             ]) == {~s(<svg aria-hidden="false"></svg>), []}
    end

    test "requires aria-hidden if values are given without a default" do
      assert transform_svg(~s(<svg></svg>), [
               {"aria-hidden", values: ["true", "false"]}
             ]) ==
               {~s(<svg aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [values: ["true", "false"], required: true]}]}
    end

    test "allows configuring aria-hidden" do
      svg = ~s(<svg stroke="currentColor"></svg>)

      assert transform_svg(svg, [{"aria-hidden", default: "true"}]) ==
               {~s(<svg stroke="currentColor" aria-hidden={@aria_hidden}></svg>),
                [{"aria_hidden", [default: "true"]}]}
    end
  end

  describe "render_global_attr/1" do
    test "renders nothing if global attributes are turned off" do
      assert ExIcon.Attrs.render_global_attr(false) == ""
    end

    test "renders the attribute without options" do
      assert ExIcon.Attrs.render_global_attr(true) == "\n  attr :rest, :global"
      assert ExIcon.Attrs.render_global_attr([]) == "\n  attr :rest, :global"
    end

    test "renders the configured options" do
      assert ExIcon.Attrs.render_global_attr(
               default: %{"class" => "size-6"},
               include: ["fill"]
             ) ==
               ~s(\n  attr :rest, :global, default: %{"class" => "size-6"}, include: ["fill"])
    end
  end

  defp transform_svg(svg, attrs \\ []) do
    {:ok, parsed} = ExIcon.SVG.parse(svg)
    ExIcon.Attrs.transform_parsed(parsed, attrs, false)
  end

  defp render_attr(attr) do
    assigns = [
      icons: [{"arrow_left", {"<svg></svg>", [attr]}}],
      module_name: MyAppWeb.Components.Lucide,
      global_attrs: false
    ]

    EEx.eval_file(ExIcon.Template.template_path(), assigns: assigns)
  end
end
