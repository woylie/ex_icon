defmodule ExIcon do
  @moduledoc """
  Refer to the readme for usage instructions.

  This module only contains helper functions that you probably don't need to
  use directly.
  """

  @default_config_path ".ex_icon.exs"
  @default_ignore_attrs ["xmlns", "viewbox", "width", "height"]

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
    ignore_attrs: [
      type: {:or, [{:list, :string}, {:in, [:all]}]},
      required: false,
      default: @default_ignore_attrs,
      doc: """
      ExIcon substitutes all attributes of the `<svg>` element with HEEx
      variables and adds the corresponding attributes to the HEEx
      components. Attributes in this list are not substituted.
      """
    ]
  ]

  @config_schema NimbleOptions.new!(
                   *: [type: :keyword_list, keys: @options_schema]
                 )

  @typedoc """
  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc """
  Takes an SVG as a string, extracts the attributes, and replaces the
  attributes with HEEx variables.

  The second argument is a list of attributes to ignore. It must be a list of
  lowercase strings.

  The function returns a tuple with the updated SVG string as the first element
  and a list of substituted attributes with their values as a second element.
  The attribute name is converted to snake case.

  ## Example

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
       <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke={@stroke} stroke-width={@stroke_width}>
         <path d="m12 19-7-7 7-7" />
         <path d="M19 12H5" />
       </svg>\\
       \"\"\", [{"stroke", "currentColor"}, {"stroke_width", "2"}]}
  """
  @spec transform_svg(svg, ignore_attrs) :: {svg, attrs}
        when svg: binary, ignore_attrs: [binary], attrs: [{binary, binary}]
  def transform_svg(svg, ignore_attrs \\ @default_ignore_attrs)
      when is_binary(svg) and is_list(ignore_attrs) do
    case extract_svg(svg) do
      {:ok, {attrs, inner}} ->
        svg_attrs = build_attrs(attrs, ignore_attrs)

        substituted_attrs =
          attrs
          |> Enum.reject(fn {k, _} -> ignore_attr?(k, ignore_attrs) end)
          |> Enum.map(fn {k, v} -> {to_snake_case(k), v} end)

        svg = "<svg #{svg_attrs}>#{inner}</svg>"
        {svg, substituted_attrs}

      :error ->
        {svg, []}
    end
  end

  defp ignore_attr?(attr, ignore_attrs) do
    String.downcase(attr) in ignore_attrs
  end

  defp build_attrs(attrs, ignore_attrs) do
    Enum.map_join(attrs, " ", fn {k, v} ->
      if ignore_attr?(k, ignore_attrs) do
        ~s(#{k}="#{v}")
      else
        "#{k}={@#{to_snake_case(k)}}"
      end
    end)
  end

  defp extract_svg(svg) do
    case Regex.run(~r/<svg\s+(.*?)>(.*)<\/svg>/s, svg) do
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
  def prepare_assigns(path, opts) do
    module_name = Keyword.fetch!(opts, :module_name)
    ignore_attrs = Keyword.get(opts, :ignore_attrs, default_ignore_attrs())

    icon_names =
      case Keyword.fetch!(opts, :icons) do
        :all -> list_svgs(path)
        icon_names -> icon_names
      end

    icons =
      icon_names
      |> Enum.map(fn icon_name ->
        if svg = read_icon(path, icon_name) do
          {to_snake_case(icon_name), transform_svg(svg, ignore_attrs)}
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
    |> Enum.filter(&(!File.dir?(&1) and Path.extname(&1) == ".svg"))
    |> Enum.map(&Path.basename(&1, ".svg"))
  end

  @doc false
  def download(tmp_dir, opts) do
    provider = Keyword.fetch!(opts, :provider)
    version = Keyword.fetch!(opts, :version)
    provider_name = provider_name(provider)

    tmp_dir = Path.join([tmp_dir, provider_name, version])
    tmp_svg_dir = Path.join(tmp_dir, provider.svg_folder())

    clear_folder!(tmp_dir)

    provider
    |> download_icons!(version)
    |> unpack_archive!(tmp_dir)

    tmp_svg_dir
  end

  defp download_icons!(provider, version) do
    url = version |> provider.release_url() |> String.to_charlist()

    http_opts = [
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

  defp unpack_archive!(zip, path) do
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

  defp clear_folder!(path) do
    File.rm_rf!(path)
    File.mkdir_p!(path)
  end

  @doc """
  Returns the list of default ignore attributes for `ExIcon.transform_svg/1`.
  """
  @spec default_ignore_attrs() :: [String.t()]
  def default_ignore_attrs do
    @default_ignore_attrs
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
  def read_config(path \\ @default_config_path) when is_binary(path) do
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
