defmodule ExIcon do
  @moduledoc """
  Refer to the readme for usage instructions.

  This module only contains helper functions that you probably don't need to
  use directly.
  """

  @default_config_path ".ex_icon.exs"

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
    attrs: [
      type: {:list, :string},
      required: false,
      default: [],
      doc: """
      ExIcon substitutes all listed attributes of the `<svg>` element with HEEx
      variables and adds the corresponding attributes to the HEEx components.
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

  The second argument is a list of attributes to turn into component attributes.
  It must be a list of lowercase strings. Attributes not present in the original
  SVG file are ignored.

  The function returns a tuple with the updated SVG string as the first element
  and a list of substituted attributes with their values as a second element.
  The attribute name is converted to snake case.

  An `aria-hidden="true"` attribute is added if not already present.

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
       \"\"\", [{"stroke", "currentColor"}, {"stroke_width", "2"}]}
  """
  @spec transform_svg(svg, attrs) :: {svg, attrs}
        when svg: binary, attrs: [binary], attrs: [{binary, binary}]
  def transform_svg(svg, substitute_attrs \\ [])
      when is_binary(svg) and is_list(substitute_attrs) do
    case extract_svg(svg) do
      {:ok, {attrs, inner}} ->
        svg_attrs = build_attrs(attrs, substitute_attrs)

        substituted_attrs =
          attrs
          |> Enum.filter(fn {k, _} -> substitute_attr?(k, substitute_attrs) end)
          |> Enum.map(fn {k, v} -> {to_snake_case(k), v} end)

        svg = ~s(<svg #{svg_attrs} aria-hidden="true">#{inner}</svg>)
        {svg, substituted_attrs}

      :error ->
        # original SVG has no attributes
        svg =
          svg
          |> String.trim()
          |> String.replace("<svg>", ~s(<svg aria-hidden="true">))

        {svg, []}
    end
  end

  defp substitute_attr?(attr, substitute_attrs) do
    String.downcase(attr) in substitute_attrs
  end

  defp build_attrs(attrs, []) do
    attrs
    |> Enum.reject(fn {k, _} -> k == "aria-hidden" end)
    |> Enum.map_join(" ", fn {k, v} ->
      ~s(#{k}="#{v}")
    end)
  end

  defp build_attrs(attrs, substitute_attrs) do
    attrs
    |> Enum.reject(fn {k, _} -> k == "aria-hidden" end)
    |> Enum.map_join(" ", fn {k, v} ->
      if substitute_attr?(k, substitute_attrs) do
        "#{k}={@#{to_snake_case(k)}}"
      else
        ~s(#{k}="#{v}")
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
    substitute_attrs = Keyword.get(opts, :attrs, [])

    icon_names =
      case Keyword.fetch!(opts, :icons) do
        :all -> list_svgs(path)
        icon_names -> icon_names
      end

    icons =
      icon_names
      |> Enum.map(fn icon_name ->
        if svg = read_icon(path, icon_name) do
          {to_snake_case(icon_name), transform_svg(svg, substitute_attrs)}
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
  def download(cache_dir, opts, download_opts \\ []) do
    provider = Keyword.fetch!(opts, :provider)
    version = Keyword.fetch!(opts, :version)
    provider_name = provider_name(provider)

    icon_dir = Path.join([cache_dir, provider_name, version])
    svg_dir = Path.join(icon_dir, provider.svg_folder(version))

    if Keyword.get(download_opts, :force, false), do: File.rm_rf!(icon_dir)
    if !File.dir?(icon_dir), do: fill_cache!(icon_dir, provider, version)

    svg_dir
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
