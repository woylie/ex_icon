defmodule ExIcon.Template do
  @moduledoc false

  # The EEx template that a generated module is rendered from, the helper it
  # calls, and the check on what it produced.

  def indent(text, spaces) do
    pad = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> pad <> line
    end)
  end

  # A generated module should only contain a moduledoc, a use, attr calls, and
  # one component per icon. If there is a bug in the parser that results in
  # anything else being added to the module, generation is aborted.
  def verify_module!(contents) do
    case parse(contents) do
      {:ok, {:defmodule, _, [_alias, [do: body]]}} ->
        if Enum.all?(module_body(body), &allowed_node?/1),
          do: :ok,
          else: refuse_unexpected!()

      {:ok, _quoted} ->
        refuse_unexpected!()

      {:syntax_error, message} ->
        refuse_syntax_error!(message)
    end
  end

  # the module is checked before it is formatted, so that an icon that does not
  # produce valid code is reported here instead of by the formatter
  defp parse(contents) do
    {:ok, Code.string_to_quoted!(contents)}
  rescue
    error -> {:syntax_error, Exception.message(error)}
  end

  @spec refuse_syntax_error!(binary) :: no_return()
  defp refuse_syntax_error!(message) do
    Mix.raise("""
    Refusing to write the generated module

    The generated code is not valid Elixir:

        #{message}

    An icon whose name cannot be used as a function name can cause this.
    """)
  end

  @spec refuse_unexpected!() :: no_return()
  defp refuse_unexpected! do
    raise """
    Refusing to write the generated module

    It contains code that does not belong to an icon component. This is a
    bug in ExIcon. Please report it.
    """
  end

  defp module_body({:__block__, _meta, nodes}), do: nodes
  defp module_body(node), do: [node]

  defp allowed_node?({:@, _, [{:moduledoc, _, [doc]}]}), do: is_binary(doc)

  defp allowed_node?({:use, _, [{:__aliases__, _, [:Phoenix, :Component]}]}),
    do: true

  defp allowed_node?({:attr, _, args}),
    do: Enum.all?(args, &Macro.quoted_literal?/1)

  defp allowed_node?({:def, _, [{name, _, [{:assigns, _, ctx}]}, [do: body]]})
       when is_atom(name) and is_atom(ctx),
       do: heex_sigil?(body)

  defp allowed_node?(_node), do: false

  defp heex_sigil?({:sigil_H, _, [{:<<>>, _, [content]}, []]}),
    do: is_binary(content)

  defp heex_sigil?(_node), do: false

  def template_path do
    Path.join([:code.priv_dir(:ex_icon), "templates", "icon.ex.eex"])
  end
end
