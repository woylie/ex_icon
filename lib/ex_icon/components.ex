defmodule ExIcon.Components do
  @moduledoc false

  # Turns the SVG files of an icon set into the components of one module:
  # selects the icons, derives a function name for each, and reads and
  # transforms the files.

  def prepare_assigns(path, opts) do
    attrs = Keyword.get(opts, :attrs, [])
    global_attrs = Keyword.get(opts, :global_attrs, false)

    exclude = MapSet.new(Keyword.get(opts, :exclude, []))
    rename = Keyword.get(opts, :rename, %{})

    configured = Keyword.fetch!(opts, :icons)

    icon_names =
      case configured do
        :all -> list_svgs(path)
        icon_names -> icon_names
      end

    wanted = Enum.reject(icon_names, &MapSet.member?(exclude, &1))

    icons =
      wanted
      |> Enum.map(fn icon_name ->
        with {:ok, function_name} <- function_name(icon_name, rename),
             svg when is_binary(svg) <- read_icon(path, icon_name),
             {:ok, parsed} <- parse_icon(icon_name, svg) do
          {icon_name, function_name,
           ExIcon.Attrs.transform_parsed(parsed, attrs, global_attrs)}
        else
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> ensure_unique_names!()
      |> Enum.map(fn {_icon_name, function_name, icon} ->
        {function_name, icon}
      end)

    if configured != :all, do: ensure_nothing_missing!(wanted, icons)

    [icons: icons, global_attrs: global_attrs]
  end

  defp ensure_nothing_missing!(wanted, icons)
       when length(wanted) != length(icons) do
    Mix.raise("""
    could not generate every configured icon

    #{length(icons)} of #{length(wanted)} icons were generated. See the messages
    above for the icons that were skipped and why.
    """)
  end

  defp ensure_nothing_missing!(_wanted, _icons), do: :ok

  # Icon names end up as function names in the generated module, so they are
  # restricted to characters that can produce one. Names that cannot be used as
  # they are get an `icon_` prefix.
  @icon_name_regex ~r/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/

  # a function cannot be named after a reserved word; `unquote` and
  # `unquote_splicing` parse but are special forms, `module_info` is defined by
  # Erlang for every module, and `not` is fine
  @reserved_names ~w(
    after and catch do else end false fn in module_info nil or rescue true
    unquote unquote_splicing when
  )

  # the icon name is checked even if the icon is renamed, because it is also
  # the name of the file that is read
  defp function_name(icon_name, rename) do
    if Regex.match?(@icon_name_regex, icon_name) do
      {:ok,
       Map.get_lazy(rename, icon_name, fn ->
         icon_name |> ExIcon.Attrs.to_snake_case() |> prefix_name()
       end)}
    else
      regex = inspect(@icon_name_regex.source)
      IO.puts("#{skipping(icon_name)}: icon names must match #{regex}")

      :error
    end
  end

  # HEEx does not accept a component name that starts with a digit
  defp prefix_name(<<char, _::binary>> = name) when char in ?0..?9,
    do: "icon_" <> name

  defp prefix_name(name) when name in @reserved_names, do: "icon_" <> name

  defp prefix_name(name), do: name

  # a function name set with :rename does not get a prefix, so it has to be
  # valid as it is
  @function_name_regex ~r/\A[a-z][a-z0-9_]*\z/

  def valid_function_name?(name) do
    Regex.match?(@function_name_regex, name) and name not in @reserved_names
  end

  defp ensure_unique_names!(icons) do
    duplicates =
      icons
      |> Enum.group_by(
        fn {_icon_name, function_name, _icon} -> function_name end,
        fn {icon_name, _function_name, _icon} -> icon_name end
      )
      |> Enum.filter(fn {_function_name, icon_names} ->
        length(icon_names) > 1
      end)
      |> Enum.sort()

    if duplicates != [] do
      Mix.raise("""
      duplicate function names

      Remove the duplicate icons from the :icons option, add one of them to the
      :exclude option, or set another function name for one of them with the
      :rename option.

      Function names and the icons they come from:

      #{Enum.map_join(duplicates, "\n", &format_duplicate/1)}
      """)
    end

    icons
  end

  defp format_duplicate({function_name, icon_names}) do
    "    #{inspect(function_name)}: #{Enum.map_join(icon_names, ", ", &inspect/1)}"
  end

  defp parse_icon(name, svg) do
    case ExIcon.SVG.parse(svg) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, reason} ->
        IO.puts("#{skipping(name)}: #{reason}")
        :error
    end
  end

  defp read_icon(path, name) do
    path = Path.join(path, "#{name}.svg")

    case File.read(path) do
      {:ok, content} ->
        content

      {:error, error} ->
        reason = :file.format_error(error)
        IO.puts("#{skipping(name)}: could not read #{path}: #{reason}")
        nil
    end
  end

  defp skipping(icon_name), do: "Skipping #{inspect(icon_name <> ".svg")}"

  defp list_svgs(path) do
    path
    |> File.ls!()
    |> Enum.filter(
      &(Path.extname(&1) == ".svg" and not File.dir?(Path.join(path, &1)))
    )
    |> Enum.map(&Path.basename(&1, ".svg"))
  end
end
