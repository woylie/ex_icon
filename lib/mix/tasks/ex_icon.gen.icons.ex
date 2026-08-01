defmodule Mix.Tasks.ExIcon.Gen.Icons do
  @shortdoc "Downloads icon libraries and generates the icon modules"

  @moduledoc """
  Downloads the configured icon libraries and generates the icon modules.

      $ mix ex_icon.gen.icons

  For every icon set in the configuration file, a module with a function
  component per icon is generated. An icon set either names a provider and a
  version, in which case the release of the icon library is downloaded, or a
  folder that already holds the SVG files.

  Releases are cached, so regenerating the icons does not download them again.
  Paths in the configuration file are relative to the folder the task is run in.

  ## Command line options

    * `--cache-dir` - the folder to cache the downloaded releases in, defaults
      to the Mix cache folder
    * `--config` - the path of the configuration file, defaults to
      `.ex_icon.exs` in the folder the task is run in
    * `--force` - overwrites the generated modules without asking
    * `--icon-set` - only generates the given icon set, which must be one of
      the top level keys in the configuration file
    * `--refresh` - discards the cached releases and downloads them again

  The task fails if a module was not written, so that a pipeline that
  regenerates the icons does not pass with modules that are out of date. Pass
  `--force` to write them without being asked.

  ## Examples

  Generate all configured icon sets:

      $ mix ex_icon.gen.icons

  Generate a single icon set and download its release again:

      $ mix ex_icon.gen.icons --icon-set lucide --refresh

  Regenerate the icons in a pipeline:

      $ mix ex_icon.gen.icons --force

  Read the configuration from a different path:

      $ mix ex_icon.gen.icons --config config/icons.exs
  """

  use Mix.Task

  alias Mix.Tasks.Format

  @switches [
    strict: [
      cache_dir: :string,
      config: :string,
      icon_set: :string,
      force: :boolean,
      refresh: :boolean
    ]
  ]

  @default_config_path ".ex_icon.exs"
  @cache_dir "ex_icon"

  @impl Mix.Task
  def run(args) do
    {opts, []} = OptionParser.parse!(args, @switches)
    config_path = opts[:config] || @default_config_path

    case ExIcon.read_config(config_path) do
      {:ok, config} ->
        cache_dir =
          opts[:cache_dir] || Path.join(Mix.Utils.mix_cache(), @cache_dir)

        refresh = opts[:refresh] == true
        force = opts[:force] == true

        icon_sets =
          config
          |> Keyword.fetch!(:icon_sets)
          |> select_icon_sets(opts[:icon_set])

        results =
          download_and_generate_all(icon_sets, cache_dir, refresh, force: force)

        IO.puts("Done.")
        if Enum.any?(icon_sets, &downloaded?/1), do: report_cache(cache_dir)

        # a module that was not written makes the task fail, so that a check in
        # a pipeline does not pass with modules that are out of date
        if :skipped in results, do: exit({:shutdown, 1})

      {:error, reason} ->
        IO.puts(config_error(config_path, reason))
        exit({:shutdown, 1})
    end
  end

  defp config_error(path, %{__exception__: true} = error) do
    """
    #{path} is not valid.

    #{Exception.message(error)}
    """
  end

  defp config_error(path, posix) do
    """
    Could not read #{path}.

    #{:file.format_error(posix)}
    """
  end

  defp select_icon_sets(icon_sets, nil), do: icon_sets

  defp select_icon_sets(icon_sets, name) when is_binary(name) do
    key = String.to_atom(name)

    case Keyword.fetch(icon_sets, key) do
      {:ok, opts} ->
        [{key, opts}]

      :error ->
        IO.puts("""
        Icon set #{key} not found in configuration.

        Available icon sets:

            #{inspect(Keyword.keys(icon_sets))}
        """)

        exit({:shutdown, 1})
    end
  end

  defp downloaded?({_name, opts}), do: Keyword.has_key?(opts, :provider)

  defp report_cache(cache_dir) do
    IO.puts("""

    Downloaded releases are cached in:

        #{cache_dir}

    Pass --refresh to download them again.
    """)
  end

  defp download_and_generate_all(config, cache_dir, refresh?, write_opts) do
    Enum.each(config, fn {_name, opts} -> ExIcon.Target.targets(opts) end)

    config
    |> with_refresh_flags(refresh?)
    |> Enum.flat_map(fn {icon_set, refresh_release?} ->
      download_and_generate(icon_set, cache_dir, refresh_release?, write_opts)
    end)
  end

  defp with_refresh_flags(config, refresh?) do
    {icon_sets, _seen} =
      Enum.map_reduce(config, MapSet.new(), fn {_name, opts} = icon_set, seen ->
        release = {Keyword.get(opts, :provider), Keyword.get(opts, :version)}

        refresh_release? = refresh? and not MapSet.member?(seen, release)
        {{icon_set, refresh_release?}, MapSet.put(seen, release)}
      end)

    icon_sets
  end

  defp download_and_generate(
         {config_name, opts},
         cache_dir,
         refresh?,
         write_opts
       ) do
    IO.puts("Processing #{config_name}...")

    targets = ExIcon.Target.targets(opts)
    icon_dir = ExIcon.Source.icon_dir(cache_dir, opts, force: refresh?)

    Enum.map(targets, fn {svg_folder, module_name, module_path} ->
      generate(
        Path.join(icon_dir, svg_folder),
        module_name,
        module_path,
        opts,
        write_opts
      )
    end)
  end

  defp generate(svg_dir, module_name, module_path, opts, write_opts) do
    IO.puts("Generating #{inspect(module_name)}...")

    assigns =
      svg_dir
      |> ExIcon.prepare_assigns(opts)
      |> Keyword.put(:module_name, module_name)

    {formatter, _opts} = Format.formatter_for_file(module_path)

    contents =
      ExIcon.template_path()
      |> EEx.eval_file(assigns: assigns)
      |> formatter.()

    ExIcon.verify_module!(contents)
    write_module(module_path, contents, write_opts)
  end

  defp write_module(module_path, contents, write_opts) do
    relative_path = Path.relative_to_cwd(module_path)
    create_opts = [quiet: true] ++ Keyword.take(write_opts, [:force])

    cond do
      File.read(module_path) == {:ok, contents} ->
        IO.puts("* #{relative_path} is unchanged")
        :unchanged

      Mix.Generator.create_file(module_path, contents, create_opts) ->
        IO.puts("* writing #{relative_path}")
        :written

      true ->
        IO.puts("* skipping #{relative_path}")
        :skipped
    end
  end
end
