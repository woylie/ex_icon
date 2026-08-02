defmodule ExIcon.TemplateTest do
  use ExUnit.Case

  alias ExIcon.Template

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
      assert ExIcon.Template.verify_module!(@valid) == :ok
    end

    test "accepts a module with a single expression in its body" do
      assert ExIcon.Template.verify_module!("""
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
        ExIcon.Template.verify_module!(contents)
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
        ExIcon.Template.verify_module!(contents)
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
        ExIcon.Template.verify_module!(contents)
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
        ExIcon.Template.verify_module!(contents)
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
        ExIcon.Template.verify_module!(contents)
      end
    end

    test "refuses source that does not parse" do
      assert_raise RuntimeError, ~r/is not valid Elixir/, fn ->
        ExIcon.Template.verify_module!("defmodule G do")
      end
    end

    # the formatter would raise on this before the check could report it
    test "refuses a component named after a reserved word" do
      contents = String.replace(@valid, "def arrow_left", "def do")

      assert_raise RuntimeError, ~r/is not valid Elixir/, fn ->
        ExIcon.Template.verify_module!(contents)
      end
    end
  end

  describe "indent/2" do
    test "indents a multi-line string" do
      assert Template.indent(
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
end
