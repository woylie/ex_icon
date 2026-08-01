defmodule Mix.Tasks.ExIcon.Gen.Icons do
  @shortdoc "Downloads icon libraries and generates the icon modules"

  @moduledoc """
  Downloads the configured icon libraries and generates the icon modules.

      $ mix ex_icon.gen.icons

  For every icon set in the configuration file, the release of the icon library
  is downloaded and a module with a function component per icon is generated.

  Releases are cached, so regenerating the icons does not download them again.
  Paths in the configuration file are relative to the folder the task is run in.

  ## Command line options

    * `--cache-dir` - the folder to cache the downloaded releases in, defaults
      to the Mix cache folder
    * `--config` - the path of the configuration file, defaults to
      `.ex_icon.exs` in the folder the task is run in
    * `--force` - discards the cached releases and downloads them again
    * `--icon-set` - only generates the given icon set, which must be one of
      the top level keys in the configuration file

  ## Examples

  Generate all configured icon sets:

      $ mix ex_icon.gen.icons

  Generate a single icon set and download its release again:

      $ mix ex_icon.gen.icons --icon-set lucide --force

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
      force: :boolean
    ]
  ]

  @default_config_path ".ex_icon.exs"
  @cache_dir "ex_icon"

  @impl Mix.Task
  def run(args) do
    {opts, []} = OptionParser.parse!(args, @switches)

    case ExIcon.read_config(opts[:config] || @default_config_path) do
      {:ok, config} ->
        cache_dir =
          opts[:cache_dir] || Path.join(Mix.Utils.mix_cache(), @cache_dir)

        do_run(config, cache_dir, opts[:icon_set], opts[:force] == true)

        IO.puts("""
        Done.

        Downloaded releases are cached in:

            #{cache_dir}

        Pass --force to download them again.
        """)

      {:error, reason} ->
        IO.puts("""
        An error occurred.

        #{inspect(reason, pretty: true)}
        """)

        exit({:shutdown, 1})
    end
  end

  defp do_run(config, cache_dir, nil, force?) do
    download_and_generate_all(config, cache_dir, force?)
  end

  defp do_run(config, cache_dir, icon_set, force?) when is_binary(icon_set) do
    icon_set = String.to_atom(icon_set)

    if opts = Keyword.get(config, icon_set) do
      download_and_generate({icon_set, opts}, cache_dir, force?)
    else
      IO.puts("""
      Icon set #{icon_set} not found in configuration.

      Available icon sets:

          #{inspect(Keyword.keys(config))}
      """)

      exit({:shutdown, 1})
    end
  end

  defp download_and_generate_all(config, cache_dir, force?) do
    config
    |> with_force_flags(force?)
    |> Enum.each(fn {icon_set, force_release?} ->
      download_and_generate(icon_set, cache_dir, force_release?)
    end)
  end

  defp with_force_flags(config, force?) do
    {icon_sets, _seen} =
      Enum.map_reduce(config, MapSet.new(), fn {_name, opts} = icon_set, seen ->
        release =
          {Keyword.fetch!(opts, :provider), Keyword.fetch!(opts, :version)}

        force_release? = force? and not MapSet.member?(seen, release)
        {{icon_set, force_release?}, MapSet.put(seen, release)}
      end)

    icon_sets
  end

  defp download_and_generate({config_name, opts}, cache_dir, force?) do
    IO.puts("Processing #{config_name}...")

    targets = ExIcon.targets(opts)
    icon_dir = ExIcon.download(cache_dir, opts, force: force?)

    Enum.each(targets, fn {svg_folder, module_name, module_path} ->
      generate(Path.join(icon_dir, svg_folder), module_name, module_path, opts)
    end)
  end

  defp generate(svg_dir, module_name, module_path, opts) do
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
    write_module(module_path, contents)
  end

  defp write_module(module_path, contents) do
    relative_path = Path.relative_to_cwd(module_path)

    cond do
      File.read(module_path) == {:ok, contents} ->
        IO.puts("* #{relative_path} is unchanged")

      Mix.Generator.create_file(module_path, contents, quiet: true) ->
        IO.puts("* writing #{relative_path}")

      true ->
        IO.puts("* skipping #{relative_path}")
    end
  end
end
