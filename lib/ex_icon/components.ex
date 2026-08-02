defmodule ExIcon.Components do
  @moduledoc false

  # Turns the SVG files of an icon set into the components of one module:
  # selects the icons, derives a function name for each, and reads and
  # transforms the files.

  def prepare_assigns(path, opts) do
    attrs = Keyword.get(opts, :attrs, [])
    global_attrs = Keyword.get(opts, :global_attrs, false)

    exclude = MapSet.new(Keyword.get(opts, :exclude, []))

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
        with {:ok, function_name} <- function_name(icon_name),
             svg when is_binary(svg) <- read_icon(path, icon_name),
             {:ok, parsed} <- parse_icon(icon_name, svg) do
          {function_name,
           ExIcon.Attrs.transform_parsed(parsed, attrs, global_attrs)}
        else
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> ensure_unique_names!()

    if configured != :all, do: ensure_nothing_missing!(wanted, icons)

    [icons: icons, global_attrs: global_attrs]
  end

  # raise if icon listed in the configuration is missing
  defp ensure_nothing_missing!(wanted, icons)
       when length(wanted) != length(icons) do
    raise ArgumentError, """
    could not generate every configured icon

    #{length(icons)} of #{length(wanted)} icons were generated. See the messages
    above for the icons that were skipped and why.
    """
  end

  defp ensure_nothing_missing!(_wanted, _icons), do: :ok

  # Icon names end up as function names in the generated module, so they are
  # restricted to characters that can produce one. Names that cannot be used as
  # they are get an `icon_` prefix.
  @icon_name_regex ~r/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/

  # a function cannot be named after a reserved word; `unquote` and
  # `unquote_splicing` parse but are special forms, and `not` is fine
  @reserved_names ~w(
    after and catch do else end false fn in nil or rescue true unquote
    unquote_splicing when
  )

  defp function_name(icon_name) do
    if Regex.match?(@icon_name_regex, icon_name) do
      {:ok, icon_name |> ExIcon.Attrs.to_snake_case() |> prefix_name()}
    else
      IO.puts(
        "Skipping #{inspect(icon_name)}: icon names must match " <>
          inspect(@icon_name_regex.source)
      )

      :error
    end
  end

  # HEEx does not accept a component name that starts with a digit
  defp prefix_name(<<char, _::binary>> = name) when char in ?0..?9,
    do: "icon_" <> name

  defp prefix_name(name) when name in @reserved_names, do: "icon_" <> name

  defp prefix_name(name), do: name

  defp ensure_unique_names!(icons) do
    duplicates =
      icons
      |> Enum.frequencies_by(fn {name, _} -> name end)
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> name end)

    if duplicates != [] do
      raise ArgumentError, """
      duplicate function names

      These function names are generated more than once:
      #{Enum.map_join(duplicates, ", ", &inspect/1)}

      Remove the duplicate icons from the :icons option, or add one of them to
      the :exclude option.
      """
    end

    icons
  end

  defp parse_icon(name, svg) do
    case ExIcon.SVG.parse(svg) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, reason} ->
        IO.puts("Skipping #{name}.svg: #{reason}")
        :error
    end
  end

  defp read_icon(path, name) do
    path = Path.join(path, "#{name}.svg")

    case File.read(path) do
      {:ok, content} ->
        content

      {:error, error} ->
        IO.puts("Could not read file #{path}: #{inspect(error)}")
        nil
    end
  end

  defp list_svgs(path) do
    path
    |> File.ls!()
    |> Enum.filter(
      &(Path.extname(&1) == ".svg" and not File.dir?(Path.join(path, &1)))
    )
    |> Enum.map(&Path.basename(&1, ".svg"))
  end
end
