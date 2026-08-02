defmodule ExIcon.Source do
  @moduledoc false

  # Answers where the SVG files of an icon set are: a folder given in the
  # configuration, or a release downloaded and unpacked into the cache.

  # an icon set is either downloaded from a provider URL or read from a folder
  def resolve!(opts) do
    case {Keyword.get(opts, :path), Keyword.get(opts, :provider)} do
      {nil, nil} ->
        raise ArgumentError, """
        icon set without a source

        Set either :path, or :provider and :version.
        """

      {path, nil} when is_binary(path) ->
        {:path, path}

      {nil, provider} ->
        {:release, provider, fetch_version!(opts, provider)}

      {_path, _provider} ->
        raise ArgumentError, """
        icon set with two sources

        Set either :path, or :provider and :version, but not both.
        """
    end
  end

  defp fetch_version!(opts, provider) do
    case Keyword.get(opts, :version) do
      version when is_binary(version) ->
        version

      nil ->
        raise ArgumentError, """
        icon set without a version

        #{inspect(provider)} needs a :version to know which release to download.
        """
    end
  end

  def icon_dir(cache_dir, opts, refresh? \\ false) do
    case resolve!(opts) do
      {:path, path} ->
        path = existing_dir!(path)
        IO.puts("Reading #{Path.relative_to_cwd(path)}...")
        path

      {:release, provider, version} ->
        cached_release(cache_dir, provider, version, refresh?)
    end
  end

  def existing_dir!(path) do
    if File.dir?(path) do
      path
    else
      raise ArgumentError, """
      #{inspect(path)} is not a folder

      The :path must be relative to the folder the task is run in.
      """
    end
  end

  defp cached_release(cache_dir, provider, version, refresh?) do
    version = validate_version!(version)
    icon_dir = Path.join([cache_dir, cache_key(provider), version])

    if refresh?, do: File.rm_rf!(icon_dir)

    if File.dir?(icon_dir) do
      IO.puts("Using cached #{provider_name(provider)} #{version}...")
    else
      fill_cache!(icon_dir, provider, version)
    end

    icon_dir
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

  # a release is fetched over https, except from the local machine, so that a
  # provider can be developed against a local server
  @loopback_hosts ~w(localhost 127.0.0.1 ::1 [::1])

  defp validate_url!(url, provider) do
    case URI.parse(url) do
      %URI{scheme: "https"} ->
        url

      %URI{scheme: "http", host: host} when host in @loopback_hosts ->
        url

      _uri ->
        raise ArgumentError, """
        invalid release URL #{inspect(url)}

        #{inspect(provider)} has to return an https URL, or an http URL of a
        server on the local machine.
        """
    end
  end

  # an archive decides the modes of the files it is unpacked into, and the cache
  # is shared between projects and users on the machine
  defp normalize_modes!(dir) do
    for path <- Path.wildcard(Path.join(dir, "**"), match_dot: true) do
      File.chmod!(path, if(File.dir?(path), do: 0o755, else: 0o644))
    end

    File.chmod!(dir, 0o755)
  end

  defp download_icons!(provider, version) do
    url =
      version
      |> provider.release_url()
      |> validate_url!(provider)
      |> String.to_charlist()

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

  @max_release_size 250 * 1024 * 1024

  def unpack_archive!(zip, path, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, @max_release_size)
    entries = list_entries!(zip)

    refuse_unsafe_entries!(entry_names(entries) ++ local_names!(zip, entries))
    refuse_above!(declared_size(entries), max_size)

    case :zip.extract(zip, [{:cwd, String.to_charlist(path)}]) do
      {:ok, _} ->
        check_unpacked_size!(path, max_size)
        normalize_modes!(path)

      result ->
        raise """
        Unable to unpack zip archive

        #{inspect(result, pretty: true)}
        """
    end
  end

  defp list_entries!(zip) do
    case :zip.list_dir(zip) do
      {:ok, entries} ->
        entries

      result ->
        raise """
        Unable to read zip archive

        #{inspect(result, pretty: true)}
        """
    end
  end

  # an entry is named in the central directory and again in the local file
  # header, and only the latter decides where :zip.extract writes it
  defp local_names!(zip, entries) do
    for {:zip_file, _name, _info, _comment, offset, _size} <- entries,
        do: local_name!(zip, offset)
  end

  defp local_name!(zip, offset) do
    case zip do
      <<_::binary-size(^offset), 0x50, 0x4B, 0x03, 0x04, _::binary-size(22),
        length::little-16, _extra::little-16, name::binary-size(length),
        _::binary>> ->
        name

      _zip ->
        raise """
        Unable to read zip archive

        The archive has no local file header at offset #{offset}.
        """
    end
  end

  # a path that climbs above the target only in total passes Erlang's own check,
  # so `../icons/arrow-left.svg` nets out at zero and lands outside it
  defp refuse_unsafe_entries!(names) do
    case Enum.filter(names, &unsafe_path?/1) do
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
  end

  defp entry_names(entries) do
    for {:zip_file, name, _info, _comment, _offset, _size} <- entries,
        do: List.to_string(name)
  end

  defp unsafe_path?(name) do
    Path.type(name) != :relative or ".." in Path.split(name)
  end

  defp declared_size(entries) do
    Enum.reduce(entries, 0, fn
      {:zip_file, _name, info, _comment, _offset, _size}, total ->
        total + elem(info, 1)

      _entry, total ->
        total
    end)
  end

  defp check_unpacked_size!(path, max_size) do
    path
    |> Path.join("**")
    |> Path.wildcard(match_dot: true)
    |> Enum.reduce(0, fn entry, total -> total + File.stat!(entry).size end)
    |> refuse_above!(max_size)
  end

  defp refuse_above!(total, max_size) when total <= max_size, do: :ok

  defp refuse_above!(_total, max_size) do
    raise """
    Refusing to unpack zip archive

    The archive unpacks to more than #{div(max_size, 1024 * 1024)} MB.
    """
  end

  defp provider_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp cache_key(module) do
    module |> Module.split() |> Enum.map_join("_", &Macro.underscore/1)
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
end
