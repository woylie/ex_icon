defmodule ExIcon do
  @moduledoc """
  Refer to the readme for usage instructions.

  This module only contains helper functions that you probably don't need to
  use directly.
  """

  @options_schema [
    icons: [
      type: {:or, [{:list, :string}, {:in, [:all]}]},
      required: true,
      doc: """
      Either a list of icon names you want to generate (e.g. `["arrow-left"]`),
      or `:all` if you want to generate all available icons.
      """
    ],
    provider: [
      type: :atom,
      required: true,
      doc: "A module implementing the `ExIcon.Provider` behaviour."
    ],
    version: [
      type: :string,
      required: true,
      doc: "The release version of the icon library."
    ],
    module_path: [
      type: :string,
      required: true,
      doc: """
      The destination path of the icon module that ExIcon will generate
      for you. Example: `"lib/my_app_web/components/lucide.ex"`.
      """
    ],
    module_name: [
      type: :atom,
      required: true,
      doc:
        "The name of the generated module. Example: `MyApp.Components.Lucide`."
    ],
    variants: [
      type: {:list, :atom},
      required: false,
      default: [],
      doc: """
      The variants of the icon library to generate, for providers that
      implement `c:ExIcon.Provider.variants/1`. Example: `[:outline, :solid]`.

      Each variant is generated into a separate module, with the variant
      appended to `module_name` and `module_path`.

      Example:

      - `module_name`: `MyApp.Components.Heroicons`
      - `module_path`: `"lib/my_app_web/components/heroicons.ex"`
      - generated module name for the `:outline` variant:
        `MyApp.Components.Heroicons.Outline`
      - path of the module for the `:outline` variant:
        `lib/my_app_web/components/heroicons/outline.ex`

      Defaults to an empty list, which generates a single module from
      `c:ExIcon.Provider.svg_folder/1`.
      """
    ],
    attrs: [
      type: {:custom, __MODULE__, :validate_attrs, []},
      type_doc: "list of `t:String.t/0` or `{t:String.t/0, keyword}`",
      required: false,
      default: [],
      doc: """
      Configures the attributes of the `<svg>` element. Each entry is either an
      attribute name, or a tuple with the attribute name and options.

      If a list entry is a string (e.g. `"stroke"`), the value is replaced with
      a HEEx variable and a component attribute is added.

      If a list entry is a tuple, the following options are supported:

      - `default` (`{"stroke-width", default: "1.5"}`) - Sets the `default`
        option on `attr`.
      - `values` (`{"stroke-linecap", values: ["square", "round"]}`) - Sets the
        `values` option on `attr`. Generation fails if the value in an SVG file
        is not among the values.
      - `required` (`{"stroke-width", required: true}`) - Sets the `required`
        option on `attr`.
      - `fixed` (`{"fill", fixed: "none"}`) - Sets a fixed value for the
        SVG attribute without adding a component attribute.

      Attributes that are not present in the original SVG file are added, as
      long as a `:default`, `:fixed`, `:values` or `:required` is given.
      Attribute names are matched case-insensitively, and each attribute may
      only be configured once.

      If an attribute is added but neither the SVG file nor `:default` provides
      a value, `required: true` is added to the component attribute.

      An `aria-hidden` attribute is always added, and can be configured like
      any other attribute. Without configuration, the value of the SVG file is
      kept, or `"true"` is used if it does not have the attribute.
      """
    ]
  ]

  @config_schema NimbleOptions.new!(
                   *: [type: :keyword_list, keys: @options_schema]
                 )

  @attr_options_schema NimbleOptions.new!(
                         default: [type: {:or, [:string, nil]}],
                         fixed: [type: :string],
                         required: [type: :boolean],
                         values: [type: {:list, {:or, [:string, nil]}}]
                       )

  @typedoc """
  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc """
  Takes an SVG as a string, extracts the attributes, and replaces the
  attributes with HEEx variables.

  The second argument configures the attributes of the `<svg>` element. See
  `t:options/0` for details.

  ## Examples

      iex> svg = \"\"\"
      ...>  <svg
      ...>    xmlns="http://www.w3.org/2000/svg"
      ...>    width="24"
      ...>    height="24"
      ...>    viewBox="0 0 24 24"
      ...>    stroke="currentColor"
      ...>    stroke-width="2"
      ...>  >
      ...>    <path d="m12 19-7-7 7-7" />
      ...>    <path d="M19 12H5" />
      ...>  </svg>
      ...>  \"\"\"
      iex> ExIcon.transform_svg(svg)
      {\"\"\"
       <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" aria-hidden="true">
         <path d="m12 19-7-7 7-7" />
         <path d="M19 12H5" />
       </svg>\\
       \"\"\", []}

      iex> svg = \"\"\"
      ...>  <svg
      ...>    xmlns="http://www.w3.org/2000/svg"
      ...>    width="24"
      ...>    height="24"
      ...>    viewBox="0 0 24 24"
      ...>    stroke="currentColor"
      ...>    stroke-width="2"
      ...>  >
      ...>    <path d="m12 19-7-7 7-7" />
      ...>    <path d="M19 12H5" />
      ...>  </svg>
      ...>  \"\"\"
      iex> ExIcon.transform_svg(svg, ["stroke", "stroke-width"])
      {\"\"\"
       <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width} aria-hidden="true">
         <path d="m12 19-7-7 7-7" />
         <path d="M19 12H5" />
       </svg>\\
       \"\"\", [{"stroke", [default: "currentColor"]}, {"stroke_width", [default: "2"]}]}

  Overriding the default value of a component attribute:

      iex> svg = ~s(<svg stroke-width="2"><path d="M19 12H5" /></svg>)
      iex> ExIcon.transform_svg(svg, [{"stroke-width", default: "1.5"}])
      {~s(<svg stroke-width={@stroke_width} aria-hidden="true"><path d="M19 12H5" /></svg>),
       [{"stroke_width", [default: "1.5"]}]}

  Restricting a component attribute to a set of values:

      iex> svg = ~s(<svg stroke-linecap="round"><path d="M19 12H5" /></svg>)
      iex> ExIcon.transform_svg(svg, [{"stroke-linecap", values: ["square", "round"]}])
      {~s(<svg stroke-linecap={@stroke_linecap} aria-hidden="true"><path d="M19 12H5" /></svg>),
       [{"stroke_linecap", [values: ["square", "round"], default: "round"]}]}

  If the SVG file does not have the attribute and no default is given, the
  component attribute is required:

      iex> svg = ~s(<svg><path d="M19 12H5" /></svg>)
      iex> ExIcon.transform_svg(svg, [{"stroke-linecap", values: ["square", "round"]}])
      {~s(<svg stroke-linecap={@stroke_linecap} aria-hidden="true"><path d="M19 12H5" /></svg>),
       [{"stroke_linecap", [values: ["square", "round"], required: true]}]}

  Setting a fixed attribute, and adding an attribute that the SVG file does not
  have:

      iex> svg = ~s(<svg stroke="currentColor"><path d="M19 12H5" /></svg>)
      iex> ExIcon.transform_svg(svg, [{"stroke", fixed: "red"}, {"fill", fixed: "none"}])
      {~s(<svg stroke="red" fill="none" aria-hidden="true"><path d="M19 12H5" /></svg>),
       []}
  """
  @spec transform_svg(svg, attrs) :: {svg, component_attrs}
        when svg: binary,
             attrs: [binary | {binary, keyword}],
             component_attrs: [{binary, keyword}]
  def transform_svg(svg, attrs \\ [])
      when is_binary(svg) and is_list(attrs) do
    case extract_svg(svg) do
      {:ok, {svg_attrs, inner}} ->
        merged = merge_attrs(svg_attrs, normalize_attrs(attrs))
        rendered = Enum.map_join(merged, " ", &render_attr/1)

        component_attrs =
          for {:component, name, value, opts} <- merged,
              do: {to_snake_case(name), attr_options(name, value, opts)}

        {~s(<svg #{rendered}>#{inner}</svg>), component_attrs}

      :error ->
        {String.trim(svg), []}
    end
  end

  defp normalize_attrs(attrs) do
    Enum.map(attrs, fn
      name when is_binary(name) ->
        {name, :component, :none, []}

      {name, opts} when is_binary(name) and is_list(opts) ->
        case Keyword.fetch(opts, :fixed) do
          {:ok, value} ->
            {name, :fixed, value, []}

          :error ->
            {name, :component, Keyword.get(opts, :default, :none),
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
          {_, kind, :none, opts} -> {kind, name, value, opts}
          {_, kind, override, opts} -> {kind, name, override, opts}
        end
      end)

    added =
      for {name, kind, value, opts} <- specs,
          value != :none or opts != [],
          find_attr(svg_attrs, name) == nil,
          do: {kind, name, value, opts}

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
    {spec_name, kind, value, opts} =
      case spec do
        nil -> {nil, :fixed, :none, []}
        {name, kind, value, opts} -> {name, kind, value, opts}
      end

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

  defp render_attr({:component, name, _value, _values}) do
    "#{name}={@#{to_snake_case(name)}}"
  end

  defp render_attr({:fixed, name, value, _values}), do: ~s(#{name}="#{value}")

  defp find_attr(attrs, name) do
    name = String.downcase(name)
    Enum.find(attrs, fn {k, _} -> String.downcase(k) == name end)
  end

  defp find_spec(specs, name) do
    name = String.downcase(name)
    Enum.find(specs, fn {k, _, _, _} -> String.downcase(k) == name end)
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

  defp extract_svg(svg) do
    case Regex.run(~r/<svg\s*(.*?)>(.*)<\/svg>/s, svg) do
      [_, raw_attrs, inner] ->
        attrs =
          ~r/([\w-]+)="(.*?)"/
          |> Regex.scan(raw_attrs)
          |> Enum.map(fn [_, key, val] -> {key, val} end)

        {:ok, {attrs, inner}}

      nil ->
        :error
    end
  end

  @doc false
  def validate_attrs(attrs) when is_list(attrs) do
    with :ok <- validate_each_attr(attrs),
         :ok <- validate_unique_attrs(attrs) do
      {:ok, attrs}
    end
  end

  def validate_attrs(attrs) do
    {:error, "expected a list of attributes, got: #{inspect(attrs)}"}
  end

  defp validate_each_attr(attrs) do
    Enum.find_value(attrs, :ok, fn attr ->
      case validate_attr(attr) do
        :ok -> nil
        {:error, _} = error -> error
      end
    end)
  end

  defp validate_unique_attrs(attrs) do
    names = Enum.map(attrs, &String.downcase(attr_name(&1)))

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [name | _] ->
        {:error, "attribute #{inspect(name)} is configured more than once"}
    end
  end

  defp attr_name(name) when is_binary(name), do: name
  defp attr_name({name, _}) when is_binary(name), do: name

  defp validate_attr(name) when is_binary(name), do: :ok

  defp validate_attr({name, opts}) when is_binary(name) and is_list(opts) do
    case NimbleOptions.validate(opts, @attr_options_schema) do
      {:ok, opts} ->
        validate_attr_options(name, opts)

      {:error, error} ->
        {:error, "attribute #{inspect(name)}: #{Exception.message(error)}"}
    end
  end

  defp validate_attr(attr) do
    {:error,
     "expected an attribute name or a {name, options} tuple, got: " <>
       inspect(attr)}
  end

  defp validate_attr_options(name, opts) do
    with :ok <- validate_fixed_option(name, opts),
         :ok <- validate_required_option(name, opts) do
      validate_values_option(name, opts)
    end
  end

  defp validate_fixed_option(name, opts) do
    cond do
      not Keyword.has_key?(opts, :fixed) ->
        :ok

      Keyword.has_key?(opts, :default) ->
        {:error, "attribute #{inspect(name)} sets both :default and :fixed"}

      Keyword.has_key?(opts, :values) ->
        {:error, "attribute #{inspect(name)} sets both :values and :fixed"}

      Keyword.has_key?(opts, :required) ->
        {:error, "attribute #{inspect(name)} sets both :required and :fixed"}

      true ->
        :ok
    end
  end

  defp validate_required_option(name, opts) do
    if Keyword.get(opts, :required, false) and Keyword.has_key?(opts, :default) do
      {:error, "attribute #{inspect(name)} sets both :default and :required"}
    else
      :ok
    end
  end

  defp validate_values_option(name, opts) do
    default = Keyword.get(opts, :default, :none)
    values = Keyword.get(opts, :values)

    cond do
      values == [] ->
        {:error, "attribute #{inspect(name)} has an empty :values list"}

      is_list(values) and default != :none and default not in values ->
        {:error,
         "attribute #{inspect(name)} has the default value " <>
           "#{inspect(default)}, which is not one of #{inspect(values)}"}

      true ->
        :ok
    end
  end

  @doc false
  def prepare_assigns(path, opts) do
    module_name = Keyword.fetch!(opts, :module_name)
    attrs = Keyword.get(opts, :attrs, [])

    icon_names =
      case Keyword.fetch!(opts, :icons) do
        :all -> list_svgs(path)
        icon_names -> icon_names
      end

    icons =
      icon_names
      |> Enum.map(fn icon_name ->
        if svg = read_icon(path, icon_name) do
          {to_snake_case(icon_name), transform_svg(svg, attrs)}
        end
      end)
      |> Enum.reject(&is_nil/1)

    [icons: icons, module_name: module_name]
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

  @doc false
  def download(cache_dir, opts, download_opts \\ []) do
    provider = Keyword.fetch!(opts, :provider)
    version = Keyword.fetch!(opts, :version)
    provider_name = provider_name(provider)

    icon_dir = Path.join([cache_dir, provider_name, version])

    if Keyword.get(download_opts, :force, false), do: File.rm_rf!(icon_dir)
    if !File.dir?(icon_dir), do: fill_cache!(icon_dir, provider, version)

    icon_dir
  end

  @doc false
  def targets(opts) do
    provider = Keyword.fetch!(opts, :provider)
    version = Keyword.fetch!(opts, :version)
    module_name = Keyword.fetch!(opts, :module_name)
    module_path = Keyword.fetch!(opts, :module_path)

    case Keyword.get(opts, :variants, []) do
      [] ->
        [{provider.svg_folder(version), module_name, module_path}]

      variants ->
        available = available_variants!(provider, version)

        Enum.map(variants, fn variant ->
          {fetch_variant!(available, variant, provider),
           Module.concat(module_name, variant_alias(variant)),
           variant_module_path(module_path, variant)}
        end)
    end
  end

  defp available_variants!(provider, version) do
    cond do
      not Code.ensure_loaded?(provider) ->
        raise ArgumentError, """
        could not load the provider #{inspect(provider)}

        Make sure the module exists and is compiled.
        """

      not function_exported?(provider, :variants, 1) ->
        raise ArgumentError, """
        the :variants option is not supported by #{inspect(provider)}

        Only providers that implement the optional variants/1 callback of the
        ExIcon.Provider behaviour have variants to choose from.
        """

      true ->
        provider.variants(version)
    end
  end

  defp fetch_variant!(available, variant, provider) do
    case Map.fetch(available, variant) do
      {:ok, folder} ->
        folder

      :error ->
        raise ArgumentError, """
        unknown variant #{inspect(variant)} for #{inspect(provider)}

        Available variants: #{inspect(Enum.sort(Map.keys(available)))}
        """
    end
  end

  defp variant_alias(variant) do
    variant |> Atom.to_string() |> Macro.camelize()
  end

  defp variant_module_path(module_path, variant) do
    extension = Path.extname(module_path)

    Path.join(
      Path.rootname(module_path, extension),
      "#{variant}#{extension}"
    )
  end

  defp fill_cache!(icon_dir, provider, version) do
    staging_dir = "#{icon_dir}.download-#{:erlang.unique_integer([:positive])}"

    File.mkdir_p!(staging_dir)

    try do
      IO.puts("Downloading #{provider_name(provider)} #{version}...")

      provider
      |> download_icons!(version)
      |> unpack_archive!(staging_dir)

      File.mkdir_p!(Path.dirname(icon_dir))

      case File.rename(staging_dir, icon_dir) do
        :ok ->
          :ok

        {:error, reason} ->
          if !File.dir?(icon_dir) do
            raise """
            Unable to move the downloaded icons into the cache

            Tried moving '#{staging_dir}' to '#{icon_dir}', got:

            #{inspect(reason)}
            """
          end
      end
    after
      File.rm_rf(staging_dir)
    end
  end

  defp download_icons!(provider, version) do
    url = version |> provider.release_url() |> String.to_charlist()

    http_opts = [
      connect_timeout: :timer.seconds(30),
      timeout: :timer.minutes(5),
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    opts = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_opts, opts) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      result ->
        raise """
        unable to fetch icons

        Tried fetching icons from '#{url}', got:

        #{inspect(result, pretty: true)}
        """
    end
  end

  @doc false
  def unpack_archive!(zip, path) do
    reject_unsafe_entries!(zip)

    case :zip.extract(zip, [{:cwd, String.to_charlist(path)}]) do
      {:ok, _} ->
        :ok

      result ->
        raise """
        Unable to unpack zip archive

        #{inspect(result, pretty: true)}
        """
    end
  end

  defp reject_unsafe_entries!(zip) do
    case :zip.list_dir(zip) do
      {:ok, entries} ->
        case Enum.filter(entry_names(entries), &unsafe_path?/1) do
          [] ->
            :ok

          unsafe_entries ->
            raise """
            Refusing to unpack zip archive

            The archive contains entries that would be written outside the
            target folder:

            #{Enum.map_join(unsafe_entries, "\n", &"    #{&1}")}
            """
        end

      result ->
        raise """
        Unable to read zip archive

        #{inspect(result, pretty: true)}
        """
    end
  end

  defp entry_names(entries) do
    for {:zip_file, name, _info, _comment, _offset, _comp_size} <- entries do
      List.to_string(name)
    end
  end

  defp unsafe_path?(name) do
    Path.type(name) != :relative or ".." in Path.split(name)
  end

  @doc false
  def render_attr_options(opts) do
    Enum.map_join(opts, ", ", fn {key, value} ->
      "#{key}: #{inspect(value)}"
    end)
  end

  @doc false
  def indent(text, spaces) do
    pad = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> pad <> line
    end)
  end

  defp provider_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  # converts HTML attributes and icon names to snake case; ignores casing
  defp to_snake_case(v) when is_binary(v) do
    v
    |> String.downcase()
    |> String.replace("-", "_")
  end

  @doc false
  def read_config(path) when is_binary(path) do
    with {:ok, file} <- File.read(path) do
      {config, _} = Code.eval_string(file)
      validate_config(config)
    end
  end

  @doc false
  def validate_config(config) do
    NimbleOptions.validate(config, @config_schema)
  end

  @doc false
  def template_path do
    Path.join([:code.priv_dir(:ex_icon), "templates", "icon.ex.eex"])
  end
end
