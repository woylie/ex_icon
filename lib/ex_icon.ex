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
      Either a list of icon names you want to generate, or `:all` if you want
      to generate all available icons. Example: `["arrow-left"]`.
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
    rename: [
      type: {:custom, __MODULE__, :validate_rename, []},
      type_doc: "map of `t:String.t/0` to `t:String.t/0`",
      required: false,
      default: %{},
      doc: """
      Function names for individual icons, keyed by icon name. Use it to keep
      both icons when two icon names become the same function name. Example:
      `%{"arrow_left" => "arrow_left_alt"}`.

      A function name starts with a lowercase letter, contains only lowercase
      letters, digits and underscores, and is not a reserved word. It does not
      get an `icon_` prefix.

      An icon listed here cannot be in `exclude`. If `icons` is a list, it has to
      include the icon. With `icons: :all`, an icon that the folder does not
      have is ignored, so that the variants of an icon set can share the option.
      """
    ],
    provider: [
      type: :atom,
      required: false,
      doc: """
      A module implementing the `ExIcon.Provider` behaviour. Set it together
      with `version`, or set `path` instead.
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
      The destination path of the icon module that ExIcon generates. Example:
      `"lib/my_app_web/components/lucide.ex"`.
      """
    ],
    module_name: [
      type: {:custom, __MODULE__, :validate_module_name, []},
      type_doc: "`t:module/0`",
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
      appended to `module_name` and `module_path`. For example:

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

      If a list entry is a string, such as `"stroke"`, a component attribute
      is added, and the value of the SVG attribute is taken from it.

      If a list entry is a tuple, the following options are supported:

      - `:default` (`{"stroke-width", default: "1.5"}`) - Sets the `default`
        option on `attr`.
      - `:values` (`{"stroke-linecap", values: ["square", "round"]}`) - Sets
        the `values` option on `attr`. Generation fails if the value in an SVG
        file is not among the values.
      - `:required` (`{"stroke-width", required: true}`) - Sets the `required`
        option on `attr`.
      - `:fixed` (`{"fill", fixed: "none"}`) - Sets a fixed value for the
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
  The options that every icon set in `.ex_icon.exs` takes.

  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc false
  def validate_module_name(name) do
    if is_atom(name) and String.starts_with?(Atom.to_string(name), "Elixir.") do
      {:ok, name}
    else
      {:error, "expected a module name, got: #{inspect(name)}"}
    end
  end

  @doc false
  def validate_rename(rename) when is_map(rename) do
    Enum.find_value(rename, {:ok, rename}, fn
      {icon_name, function_name}
      when is_binary(icon_name) and is_binary(function_name) ->
        if not ExIcon.Components.valid_function_name?(function_name),
          do:
            {:error,
             "icon #{inspect(icon_name)} cannot be renamed to #{inspect(function_name)}: a function name starts with a lowercase letter, contains only lowercase letters, digits and underscores, and is not a reserved word"}

      entry ->
        {:error,
         "expected an icon name and a function name, got: #{inspect(entry)}"}
    end)
  end

  def validate_rename(rename) do
    {:error,
     "expected a map of icon names to function names, got: #{inspect(rename)}"}
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
     "expected an attribute name or a {name, options} tuple, got: #{inspect(attr)}"}
  end

  defp validate_attr_options(name, opts) do
    with :ok <- validate_fixed_option(name, opts),
         :ok <- validate_required_option(name, opts) do
      validate_values_option(name, opts)
    end
  end

  defp validate_fixed_option(name, opts) do
    if Keyword.has_key?(opts, :fixed) do
      case Enum.find(
             [:default, :values, :required],
             &Keyword.has_key?(opts, &1)
           ) do
        nil ->
          :ok

        option ->
          {:error,
           "attribute #{inspect(name)} sets both #{inspect(option)} and :fixed"}
      end
    else
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
         "attribute #{inspect(name)} has the default value #{inspect(default)}, which is not one of #{inspect(values)}"}

      true ->
        :ok
    end
  end

  @doc false
  def read_config(path) when is_binary(path) do
    with {:ok, file} <- File.read(path),
         {:ok, config} <- eval_config(file, path) do
      validate_config(config)
    end
  end

  defp eval_config(file, path) do
    {config, _binding} = Code.eval_string(file, [], file: path)
    {:ok, config}
  rescue
    error -> {:error, error}
  end

  @doc false
  def validate_config(config) do
    with {:ok, config} <- NimbleOptions.validate(config, @config_schema),
         :ok <- validate_renamed_icons(config) do
      {:ok, config}
    end
  end

  # :rename is checked against :icons and :exclude here, before anything is
  # downloaded or written
  defp validate_renamed_icons(config) do
    config
    |> Keyword.fetch!(:icon_sets)
    |> Enum.find_value(:ok, fn {name, opts} ->
      with message when is_binary(message) <- renamed_icon_error(opts) do
        {:error,
         %NimbleOptions.ValidationError{
           key: :rename,
           keys_path: [:icon_sets, name],
           message: message,
           value: Keyword.fetch!(opts, :rename)
         }}
      end
    end)
  end

  defp renamed_icon_error(opts) do
    icons = Keyword.fetch!(opts, :icons)
    exclude = Keyword.fetch!(opts, :exclude)

    opts
    |> Keyword.fetch!(:rename)
    |> Map.keys()
    |> Enum.sort()
    |> Enum.find_value(fn icon_name ->
      cond do
        icon_name in exclude ->
          "icon #{inspect(icon_name)} is in both :rename and :exclude; remove it from one of them"

        is_list(icons) and icon_name not in icons ->
          "icon #{inspect(icon_name)} is in :rename but not in :icons; add it to :icons or remove it from :rename"

        true ->
          nil
      end
    end)
  end
end
