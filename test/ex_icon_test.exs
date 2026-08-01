defmodule ExIconTest do
  use ExUnit.Case

  doctest ExIcon

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
            provider: ExIcon.Providers.Lucide,
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
          provider: ExIcon.Providers.Lucide,
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
          provider: ExIcon.Providers.Lucide,
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
          provider: ExIcon.Providers.Lucide,
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
      provider: ExIcon.Providers.Lucide,
      version: "1.8.0",
      module_path: "lib/my_app_web/components/lucide.ex",
      module_name: MyAppWeb.Components.Lucide,
      attrs: attrs
    ]
  end
end
