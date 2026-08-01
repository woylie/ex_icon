defmodule ExIcon do
  @moduledoc """
  Refer to the readme for usage instructions.

  All functions of this module are internal. They are only used by
  `mix ex_icon.gen.icons`.
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
    exclude: [
      type: {:list, :string},
      required: false,
      default: [],
      doc: """
      Icon names to skip, which is mostly useful in combination with
      `icons: :all`. Example: `["1password"]`.
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

  @doc false
  @spec transform_svg(svg, attrs) :: {svg, component_attrs}
        when svg: binary,
             attrs: [binary | {binary, keyword}],
             component_attrs: [{binary, keyword}]
  def transform_svg(svg, attrs \\ [])
      when is_binary(svg) and is_list(attrs) do
    case ExIcon.SVG.parse(svg) do
      {:ok, parsed} ->
        transform_parsed(parsed, attrs)

      {:error, reason} ->
        raise ArgumentError, "invalid SVG: #{reason}"
    end
  end

  defp transform_parsed({svg_attrs, inner}, attrs) do
    merged = merge_attrs(svg_attrs, normalize_attrs(attrs))
    rendered = Enum.map_join(merged, " ", &render_attr/1)

    component_attrs =
      for {:component, name, value, opts} <- merged,
          do: {to_snake_case(name), attr_options(name, value, opts)}

    {~s(<svg #{rendered}>#{inner}</svg>), component_attrs}
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

  defp render_attr({:fixed, name, value, _values}) do
    ~s(#{name}="#{ExIcon.SVG.escape_attribute(value)}")
  end

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

    exclude = MapSet.new(Keyword.get(opts, :exclude, []))

    icon_names =
      case Keyword.fetch!(opts, :icons) do
        :all -> list_svgs(path)
        icon_names -> icon_names
      end

    icons =
      icon_names
      |> Enum.reject(&MapSet.member?(exclude, &1))
      |> Enum.map(fn icon_name ->
        with {:ok, function_name} <- function_name(icon_name),
             svg when is_binary(svg) <- read_icon(path, icon_name),
             {:ok, parsed} <- parse_icon(icon_name, svg) do
          {function_name, transform_parsed(parsed, attrs)}
        else
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> ensure_unique_names!()

    [icons: icons, module_name: module_name]
  end

  # Icon names end up as function names in the generated module, so they are
  # restricted to characters that can produce one. HEEx only accepts component
  # names that start with a lowercase letter, so names starting with a digit
  # get an `icon_` prefix.
  @icon_name_regex ~r/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/

  defp function_name(icon_name) do
    if Regex.match?(@icon_name_regex, icon_name) do
      {:ok, icon_name |> to_snake_case() |> prefix_digit()}
    else
      IO.puts(
        "Skipping #{inspect(icon_name)}: icon names must match " <>
          inspect(@icon_name_regex.source)
      )

      :error
    end
  end

  defp prefix_digit(<<char, _::binary>> = name) when char in ?0..?9,
    do: "icon_" <> name

  defp prefix_digit(name), do: name

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

  @doc false
  def download(cache_dir, opts, download_opts \\ []) do
    provider = Keyword.fetch!(opts, :provider)
    version = validate_version!(Keyword.fetch!(opts, :version))
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

  # the version ends up in the release URL and in the cache path
  @version_regex ~r/^[A-Za-z0-9][A-Za-z0-9._-]*$/

  defp validate_version!(version) do
    if Regex.match?(@version_regex, version) do
      version
    else
      raise ArgumentError, """
      invalid version #{inspect(version)}

      A version may only contain letters, digits, dots, hyphens and
      underscores, and has to start with a letter or a digit.
      """
    end
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
  # A generated module should only contain a moduledoc, a use, attr calls, and
  # one component per icon. If there is a bug in the parser that results in
  # anything else being added to the module, generation is aborted.
  def verify_module!(contents) do
    with {:ok, {:defmodule, _, [_alias, [do: body]]}} <-
           Code.string_to_quoted(contents),
         [] <- Enum.reject(module_body(body), &allowed_node?/1) do
      :ok
    else
      _ ->
        raise """
        Refusing to write the generated module

        It contains code that does not belong to an icon component. This is a
        bug in ExIcon. Please report it.
        """
    end
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

  @doc false
  def template_path do
    Path.join([:code.priv_dir(:ex_icon), "templates", "icon.ex.eex"])
  end
end
