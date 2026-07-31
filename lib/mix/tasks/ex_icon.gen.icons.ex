defmodule Mix.Tasks.ExIcon.Gen.Icons do
  @shortdoc "Downloads and generates all icons"

  @moduledoc """
  Downloads and generates all icons.

  By default, the task attempts to read the configuration file `.ex_icon.exs`
  in folder it is run in. You can choose a different path with the `--config`
  argument.

  ## Usage

  Download and generate icons for all configured providers:

      mix ex_icon.gen.icons

  Download and generate icons for a single named provider:

      mix ex_icon.gen.icons --icon-set lucide

  The value must reference one of the top level keys in your configuration
  file.

  Releases are only downloaded once. To discard the cached release and download
  it again, run:

      mix ex_icon.gen.icons --force

  Both flags can be combined to only refresh a single icon set.

  To read the configuration from a different file, run:

      mix ex_icon.gen.icons --config config/icons.exs

  Paths in the configuration file stay relative to the folder the task is run
  in.

  Releases are cached in the Mix cache folder. Set the `EX_ICON_CACHE_DIR`
  environment variable to cache them in a different folder.
  """

  use Mix.Task

  @switches [
    strict: [
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
        cache_dir = cache_dir()
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

  @doc false
  def cache_dir do
    case System.get_env("EX_ICON_CACHE_DIR") do
      nil -> Path.join(Mix.Utils.mix_cache(), @cache_dir)
      dir -> dir
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
    Enum.each(config, &download_and_generate(&1, cache_dir, force?))
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

    Mix.Generator.copy_template(ExIcon.template_path(), module_path, assigns)

    Mix.Task.run("format", [module_path])
    Mix.Task.reenable("format")
  end
end
