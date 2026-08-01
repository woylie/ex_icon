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
      required: false,
      doc: """
      A module implementing the `ExIcon.Provider` behaviour. Required with
      `version`, unless `path` is set.
      """
    ],
    version: [
      type: :string,
      required: false,
      doc: "The release version of the icon library."
    ],
    path: [
      type: :string,
      required: false,
      doc: """
      Path to a folder that contains SVG files. Cannot be used together with
      `provider` and `version`.
      """
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

      Not supported if `path` is set.
      """
    ],
    global_attrs: [
      type:
        {:or,
         [
           :boolean,
           keyword_list: [
             default: [type: {:map, :string, :string}],
             include: [type: {:list, :string}]
           ]
         ]},
      required: false,
      default: false,
      doc: """
      Adds an `attr :rest, :global` to the generated components, so that they
      accept the global HTML attributes, such as `id`, `class`, `phx-click` and
      `data-*`.

      Set to `true`, or to a keyword list with the `default` and `include`
      options of `attr`. Example:
      `[default: %{"class" => "size-6"}, include: ["fill"]]`.

      The attributes that are passed to a component are written before the ones
      of the SVG file, so that they take precedence.
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
                   icon_sets: [
                     type: :keyword_list,
                     required: true,
                     keys: [*: [type: :keyword_list, keys: @options_schema]],
                     doc: """
                     The icon sets to generate, keyed by a name of your choice.
                     """
                   ]
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

    [icons: icons, module_name: module_name, global_attrs: global_attrs]
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
  # restricted to characters that can produce one. HEEx only accepts component
  # names that start with a lowercase letter, so names starting with a digit
  # get an `icon_` prefix.
  @icon_name_regex ~r/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/

  defp function_name(icon_name) do
    if Regex.match?(@icon_name_regex, icon_name) do
      {:ok, icon_name |> ExIcon.Attrs.to_snake_case() |> prefix_digit()}
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
  def targets(opts) do
    module_name = Keyword.fetch!(opts, :module_name)
    module_path = Keyword.fetch!(opts, :module_path)

    case ExIcon.Source.resolve!(opts) do
      {:path, path} ->
        no_variants!(opts)
        ExIcon.Source.existing_dir!(path)
        [{"", module_name, module_path}]

      {:release, provider, version} ->
        load_provider!(provider)
        release_targets(opts, provider, version, module_name, module_path)
    end
  end

  defp release_targets(opts, provider, version, module_name, module_path) do
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

  defp no_variants!(opts) do
    if Keyword.get(opts, :variants, []) == [] do
      :ok
    else
      raise ArgumentError, """
      variants are not supported for an icon set with a :path

      Variants are the style folders of a release. Configure one icon set per
      folder instead.
      """
    end
  end

  defp load_provider!(provider) do
    if Code.ensure_loaded?(provider) do
      :ok
    else
      raise ArgumentError, """
      could not load the provider #{inspect(provider)}

      Make sure the module exists and is compiled.
      """
    end
  end

  defp available_variants!(provider, version) do
    if function_exported?(provider, :variants, 1) do
      provider.variants(version)
    else
      raise ArgumentError, """
      the :variants option is not supported by #{inspect(provider)}

      Only providers that implement the optional variants/1 callback of the
      ExIcon.Provider behaviour have variants to choose from.
      """
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
