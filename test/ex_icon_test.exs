defmodule ExIconTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

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
               module_name: MyAppWeb.Components.Lucide,
               global_attrs: false
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
               module_name: MyAppWeb.Components.Lucide,
               global_attrs: false
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
                   module_name: MyAppWeb.Components.Lucide,
                   global_attrs: false
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
                   module_name: MyAppWeb.Components.Lucide,
                   global_attrs: false
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
               module_name: MyAppWeb.Components.Lucide,
               global_attrs: false
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
               module_name: MyAppWeb.Components.SimpleIcons,
               global_attrs: false
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
                   module_name: MyAppWeb.Components.Lucide,
                   global_attrs: false
                 ] = ExIcon.prepare_assigns(tmp_dir, opts)
        end)

      assert output =~ "icon names must match"
    end

    test "writes the global attribute before the ones of the file", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        global_attrs: true,
        provider: ExIcon.Lucide,
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
               module_name: MyAppWeb.Components.Lucide,
               global_attrs: true
             ] = ExIcon.prepare_assigns(tmp_dir, opts)

      assert svg == ~s(<svg {@rest} width="24" aria-hidden="true"></svg>)
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
               module_name: MyAppWeb.Components.Lucide,
               global_attrs: false
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
        icon_sets: [
          lucide: [
            icons: ["arrow-left", "arrow-right"],
            provider: ExIcon.Lucide,
            version: "1.8.0",
            module_path: "lib/my_app_web/components/lucide.ex",
            module_name: MyAppWeb.Components.Lucide,
            attrs: ["stroke"]
          ]
        ]
      ]

      path = Path.join(tmp_dir, ".ex_icon.exs")
      File.write!(path, inspect(config))

      assert {:ok, [icon_sets: [lucide: read_config]]} =
               ExIcon.read_config(path)

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
          module_name: MyAppWeb.Components.Lucide,
          global_attrs: false
        ]
      ]

      assert {:ok, _} = validate_icon_sets(config)
    end

    test "returns schema that accepts config with all icons" do
      config = [
        lucide: [
          icons: :all,
          provider: ExIcon.Lucide,
          version: "1.8.0",
          module_path: "lib/my_app_web/components/lucide.ex",
          module_name: MyAppWeb.Components.Lucide,
          global_attrs: false
        ]
      ]

      assert {:ok, _} = validate_icon_sets(config)
    end

    test "accepts global attributes" do
      for global_attrs <- [
            true,
            false,
            [],
            [default: %{"class" => "size-6"}],
            [include: ["fill"]],
            [default: %{"class" => "size-6"}, include: ["fill"]]
          ] do
        assert {:ok, _} =
                 validate_icon_sets(
                   lucide: config_with_global_attrs(global_attrs)
                 )
      end
    end

    test "returns error for an unknown global attribute option" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(lucide: config_with_global_attrs(nope: 1))

      assert Exception.message(error) =~ "unknown options [:nope]"
    end

    test "returns error if global attributes are not a boolean or list" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(lucide: config_with_global_attrs("yes"))

      assert Exception.message(error) =~ "expected keyword list, got: \"yes\""
    end

    test "returns error if the global default is not a map of strings" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_global_attrs(default: ["class"])
               )

      assert Exception.message(error) =~ "expected map, got: [\"class\"]"

      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_global_attrs(default: %{"class" => 1})
               )

      assert Exception.message(error) =~ ~s(map key "class": expected string)
    end

    test "returns error if the global include is not a list of strings" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_global_attrs(include: "fill")
               )

      assert Exception.message(error) =~ ~s(expected list, got: "fill")

      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_global_attrs(include: [:fill])
               )

      assert Exception.message(error) =~ "at position 0: expected string"
    end

    test "accepts attribute options" do
      assert {:ok, _} =
               validate_icon_sets(
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
               validate_icon_sets(
                 lucide:
                   config_with_attrs([{"stroke", default: "red", fixed: "red"}])
               )

      assert Exception.message(error) =~ "sets both :default and :fixed"
    end

    test "returns error regardless of the order of the attribute options" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide:
                   config_with_attrs([{"stroke", fixed: "red", default: "red"}])
               )

      assert Exception.message(error) =~ "sets both :default and :fixed"
    end

    test "returns error if an attribute sets both values and a fixed value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide:
                   config_with_attrs([
                     {"stroke", fixed: "red", values: ["red", "blue"]}
                   ])
               )

      assert Exception.message(error) =~ "sets both :values and :fixed"
    end

    test "returns error if an attribute is configured more than once" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
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
               validate_icon_sets(
                 lucide:
                   config_with_attrs([
                     {"stroke", default: "red", required: true}
                   ])
               )

      assert Exception.message(error) =~ "sets both :default and :required"
    end

    test "returns error if an attribute sets both required and a fixed value" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide:
                   config_with_attrs([{"stroke", required: true, fixed: "red"}])
               )

      assert Exception.message(error) =~ "sets both :required and :fixed"
    end

    test "returns error if a nil default is not one of the values" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
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
               validate_icon_sets(
                 lucide:
                   config_with_attrs([
                     {"stroke-width", values: ["2", "4", nil], default: nil}
                   ])
               )
    end

    test "returns error if the values list is empty" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_attrs([{"stroke", values: []}])
               )

      assert Exception.message(error) =~ "has an empty :values list"
    end

    test "returns error if attrs is not a list" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(lucide: config_with_attrs("stroke"))

      assert Exception.message(error) =~ "expected a list of attributes"
    end

    test "returns error if an attribute is neither a string nor a tuple" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(lucide: config_with_attrs([:stroke]))

      assert Exception.message(error) =~
               "expected an attribute name or a {name, options} tuple"
    end

    test "returns error if the default is not one of the values" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
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
               validate_icon_sets(
                 lucide: config_with_attrs([{"stroke", fallback: "red"}])
               )

      assert Exception.message(error) =~
               ~s(attribute "stroke": unknown options [:fallback])
    end

    test "returns error if an attribute value is not a string" do
      assert {:error, %NimbleOptions.ValidationError{} = error} =
               validate_icon_sets(
                 lucide: config_with_attrs([{"stroke-width", default: 2}])
               )

      assert Exception.message(error) =~
               ~s(invalid value for :default option: expected string, got: 2)
    end
  end

  defp validate_icon_sets(icon_sets) do
    ExIcon.validate_config(icon_sets: icon_sets)
  end

  defp config_with_global_attrs(global_attrs) do
    attrs = config_with_attrs([])
    Keyword.put(attrs, :global_attrs, global_attrs)
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
end
