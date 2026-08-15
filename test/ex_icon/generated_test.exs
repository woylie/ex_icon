defmodule ExIcon.GeneratedTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  @moduletag :tmp_dir

  describe "generated module" do
    test "compiles and renders", %{tmp_dir: tmp_dir} do
      module =
        compile(tmp_dir, Icons.Plain, %{
          "arrow-left" =>
            ~s(<svg stroke="currentColor"><path d="M19 12H5" /></svg>)
        })

      assert render_component(&module.arrow_left/1, %{}) ==
               ~s(<svg stroke="currentColor" aria-hidden="true"><path d="M19 12H5"></path></svg>)
    end

    test "escapes a brace in text", %{tmp_dir: tmp_dir} do
      module =
        compile(tmp_dir, Icons.TextBrace, %{
          "brace" => ~s(<svg><title>a {b} c</title></svg>)
        })

      assert render_component(&module.brace/1, %{}) =~
               "<title>a &lbrace;b&rbrace; c</title>"
    end

    test "renders a brace in an attribute as a literal", %{tmp_dir: tmp_dir} do
      module =
        compile(tmp_dir, Icons.AttrBrace, %{
          "brace" => ~s(<svg><path d="M{1}" /></svg>)
        })

      assert render_component(&module.brace/1, %{}) =~ ~s(d="M{1}")
    end

    test "renders the global attributes", %{tmp_dir: tmp_dir} do
      module =
        compile(
          tmp_dir,
          Icons.Global,
          %{"square" => ~s(<svg><path d="M19 12H5" /></svg>)},
          global_attrs: true
        )

      assert render_component(&module.square/1, %{"class" => "size-6"}) =~
               ~s(<svg class="size-6")
    end

    test "renders the canonical element and attribute names", %{
      tmp_dir: tmp_dir
    } do
      module =
        compile(tmp_dir, Icons.Casing, %{
          "casing" => ~s(<svg viewbox="0 0 1 1"><Circle CX="1" /></svg>)
        })

      rendered = render_component(&module.casing/1, %{})

      assert rendered =~ ~s(viewBox="0 0 1 1")
      assert rendered =~ ~s(<circle cx="1">)
    end
  end

  defp compile(tmp_dir, module_name, icons, opts \\ []) do
    dir = Path.join(tmp_dir, "icons")
    File.mkdir_p!(dir)

    for {name, svg} <- icons,
        do: File.write!(Path.join(dir, "#{name}.svg"), svg)

    opts =
      Keyword.merge(
        [icons: Map.keys(icons), module_name: module_name],
        opts
      )

    assigns =
      [module_name: module_name] ++ ExIcon.Components.prepare_assigns(dir, opts)

    source = EEx.eval_file(ExIcon.Template.template_path(), assigns: assigns)
    [{module, _binary}] = Code.compile_string(source)
    module
  end
end
