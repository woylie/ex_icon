defmodule ExIcon.ComponentsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  describe "Components.prepare_assigns/2" do
    @describetag :tmp_dir
    test "prepares assigns for configured icon", %{tmp_dir: tmp_dir} do
      icon_name = "arrow-left"
      icon_path = Path.join(tmp_dir, "#{icon_name}.svg")
      module_path = Path.join(tmp_dir, "lib/components/lucide.ex")

      opts = [
        icons: [icon_name],
        provider: ExIcon.Providers.Lucide,
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
               global_attrs: false
             ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)

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
        provider: ExIcon.Providers.Lucide,
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
               global_attrs: false
             ] =
               ExIcon.Components.prepare_assigns(tmp_dir, opts)
    end

    test "ignores folders that look like svg files", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
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
                   global_attrs: false
                 ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)
        end)

      refute output =~ "Could not read file"
    end

    test "reports and fails for a configured icon that cannot be read", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: ["arrow-left", "does-not-exist"],
        provider: ExIcon.Providers.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")

      output =
        capture_io(fn ->
          assert_raise ArgumentError,
                       ~r/could not generate every configured icon/,
                       fn ->
                         ExIcon.Components.prepare_assigns(tmp_dir, opts)
                       end
        end)

      assert output =~ "Could not read file"
      assert output =~ "does-not-exist.svg"
    end

    test "skips an icon of :all that cannot be read", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
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
                   global_attrs: false
                 ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)
        end)

      assert output =~ "Skipping broken.svg"
    end

    test "ignores non-svg files", %{tmp_dir: tmp_dir} do
      icon_name = "arrow-left"
      icon_path = Path.join(tmp_dir, "#{icon_name}.json")
      module_path = Path.join(tmp_dir, "lib/components/lucide.ex")

      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
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

      assert ExIcon.Components.prepare_assigns(tmp_dir, opts) == [
               icons: [],
               global_attrs: false
             ]
    end

    test "prefixes icon names that start with a digit", %{tmp_dir: tmp_dir} do
      opts = [
        icons: ["1password"],
        provider: ExIcon.Providers.SimpleIcons,
        version: "15.0.0",
        module_path: Path.join(tmp_dir, "lib/components/simple_icons.ex"),
        module_name: MyAppWeb.Components.SimpleIcons
      ]

      File.write!(Path.join(tmp_dir, "1password.svg"), "<svg></svg>")

      assert [
               icons: [{"icon_1password", _}],
               global_attrs: false
             ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)
    end

    test "skips icon names that are not valid function names", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
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
                   global_attrs: false
                 ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)
        end)

      assert output =~ "icon names must match"
    end

    test "writes the global attribute before the ones of the file", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        global_attrs: true,
        provider: ExIcon.Providers.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(
        Path.join(tmp_dir, "arrow-left.svg"),
        ~s(<svg width="24"></svg>)
      )

      assert [
               icons: [{"arrow_left", {svg, []}}],
               global_attrs: true
             ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)

      assert svg == ~s(<svg {@rest} width="24" aria-hidden="true"></svg>)
    end

    test "skips excluded icons", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        exclude: ["arrow-right"],
        provider: ExIcon.Providers.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      File.write!(Path.join(tmp_dir, "arrow-left.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "arrow-right.svg"), "<svg></svg>")

      assert [
               icons: [{"arrow_left", _}],
               global_attrs: false
             ] = ExIcon.Components.prepare_assigns(tmp_dir, opts)
    end

    test "skips and reports icons that cannot be parsed", %{tmp_dir: tmp_dir} do
      opts = [
        icons: ["arrow-left", "broken"],
        provider: ExIcon.Providers.Lucide,
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
                       fn ->
                         ExIcon.Components.prepare_assigns(tmp_dir, opts)
                       end
        end)

      assert output =~ "Skipping broken.svg"
      assert output =~ "the <script> element is not allowed"
    end

    test "an icon cannot add code to the generated module", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
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

      assigns =
        [module_name: MyAppWeb.Components.Lucide] ++
          ExIcon.Components.prepare_assigns(tmp_dir, opts)

      source = EEx.eval_file(ExIcon.Template.template_path(), assigns: assigns)

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
        provider: ExIcon.Providers.SimpleIcons,
        version: "15.0.0",
        module_path: Path.join(tmp_dir, "lib/components/simple_icons.ex"),
        module_name: MyAppWeb.Components.SimpleIcons
      ]

      File.write!(Path.join(tmp_dir, "1password.svg"), "<svg></svg>")
      File.write!(Path.join(tmp_dir, "icon-1password.svg"), "<svg></svg>")

      assert_raise ArgumentError, ~r/"icon_1password"/, fn ->
        ExIcon.Components.prepare_assigns(tmp_dir, opts)
      end
    end
  end
end
