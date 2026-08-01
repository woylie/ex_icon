defmodule ExIcon.Attrs do
  @moduledoc false

  # Merges the attributes of an SVG file with the ones from the `attrs` and
  # `global_attrs` options, and renders them into the tag of a component.

  @spec transform_parsed(parsed, attrs, global_attrs) :: {svg, component_attrs}
        when parsed: {[{binary, binary}], binary},
             attrs: [binary | {binary, keyword}],
             global_attrs: boolean | keyword,
             svg: binary,
             component_attrs: [{binary, keyword}]
  def transform_parsed({svg_attrs, inner}, attrs, global_attrs) do
    merged = merge_attrs(svg_attrs, normalize_attrs(attrs))

    # HTML keeps the first of two attributes with the same name, so the ones
    # passed to the component are written before the ones of the SVG file
    rendered =
      merged
      |> with_global_attrs(global_attrs)
      |> Enum.map_join(" ", &render_attr/1)

    component_attrs =
      for {:component, name, value, opts} <- merged,
          do: {to_snake_case(name), attr_options(name, value, opts)}

    {~s(<svg #{rendered}>#{inner}</svg>), component_attrs}
  end

  defp with_global_attrs(merged, false), do: merged
  defp with_global_attrs(merged, _global_attrs), do: [:global | merged]

  def render_global_attr(false), do: ""

  def render_global_attr(opts) when opts in [true, []],
    do: "\n  attr :rest, :global"

  def render_global_attr(opts) when is_list(opts) do
    "\n  attr :rest, :global, " <> render_attr_options(opts)
  end

  # specs and merged attributes share the shape {kind, name, value, options}
  defp normalize_attrs(attrs) do
    Enum.map(attrs, fn
      name when is_binary(name) ->
        {:component, name, :none, []}

      {name, opts} when is_binary(name) and is_list(opts) ->
        case Keyword.fetch(opts, :fixed) do
          {:ok, value} ->
            {:fixed, name, value, []}

          :error ->
            {:component, name, Keyword.get(opts, :default, :none),
             component_opts(opts)}
        end
    end)
  end

  defp component_opts(opts) do
    Enum.reject(
      [
        values: Keyword.get(opts, :values),
        required: Keyword.get(opts, :required)
      ],
      fn {_, value} -> value in [nil, false] end
    )
  end

  defp merge_attrs(svg_attrs, specs) do
    {aria_attr, svg_attrs} = pop_attr(svg_attrs, "aria-hidden")
    {aria_spec, specs} = pop_spec(specs, "aria-hidden")

    from_file =
      Enum.map(svg_attrs, fn {name, value} ->
        case find_spec(specs, name) do
          nil -> {:fixed, name, value, []}
          {kind, _, :none, opts} -> {kind, name, value, opts}
          {kind, _, override, opts} -> {kind, name, override, opts}
        end
      end)

    added =
      Enum.filter(specs, fn {_kind, name, value, opts} ->
        (value != :none or opts != []) and find_attr(svg_attrs, name) == nil
      end)

    from_file ++ added ++ [aria_hidden(aria_spec, aria_attr)]
  end

  defp attr_options(name, value, opts) do
    values = Keyword.get(opts, :values)
    values_opt = if values, do: [values: values], else: []

    cond do
      Keyword.get(opts, :required, false) or value == :none ->
        values_opt ++ [required: true]

      is_nil(values) or value in values ->
        values_opt ++ [default: value]

      true ->
        raise ArgumentError, """
        invalid default value for the #{inspect(name)} attribute

        The value #{inspect(value)} is not one of #{inspect(values)}.

        If it comes from an SVG file, either add it to the :values option, or
        set a :default that is one of them.
        """
    end
  end

  defp aria_hidden(spec, file_attr) do
    {kind, spec_name, value, opts} = spec || {:fixed, nil, :none, []}
    {file_name, file_value} = file_attr || {nil, nil}
    name = file_name || spec_name || "aria-hidden"

    {kind, name, aria_hidden_value(value, file_value, opts), opts}
  end

  defp aria_hidden_value(value, file_value, opts) do
    cond do
      value != :none -> value
      not is_nil(file_value) -> file_value
      opts == [] -> "true"
      true -> :none
    end
  end

  defp render_attr(:global), do: "{@rest}"

  defp render_attr({:component, name, _value, _opts}) do
    "#{name}={@#{to_snake_case(name)}}"
  end

  defp render_attr({:fixed, name, value, _opts}) do
    ~s(#{name}="#{ExIcon.SVG.escape_attribute(value)}")
  end

  defp find_attr(attrs, name) do
    name = String.downcase(name)
    Enum.find(attrs, fn {k, _} -> String.downcase(k) == name end)
  end

  defp find_spec(specs, name) do
    name = String.downcase(name)
    Enum.find(specs, fn {_, k, _, _} -> String.downcase(k) == name end)
  end

  defp pop_attr(attrs, name) do
    case find_attr(attrs, name) do
      nil -> {nil, attrs}
      attr -> {attr, List.delete(attrs, attr)}
    end
  end

  defp pop_spec(specs, name) do
    case find_spec(specs, name) do
      nil -> {nil, specs}
      spec -> {spec, List.delete(specs, spec)}
    end
  end

  def render_attr_options(opts) do
    Enum.map_join(opts, ", ", fn {key, value} ->
      "#{key}: #{inspect(value)}"
    end)
  end

  # converts HTML attributes and icon names to snake case; ignores casing
  def to_snake_case(v) when is_binary(v) do
    v
    |> String.downcase()
    |> String.replace("-", "_")
  end
end
