defmodule Mix.Tasks.ExIcon.Gen.Icons do
  @shortdoc "Downloads and generates all icons"

  @moduledoc """
  Downloads and generates all icons.

  The task expects the configuration file `.ex_icon.exs` to exist.

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
  """

  use Mix.Task

  @switches [
    strict: [
      icon_set: :string,
      force: :boolean
    ]
  ]

  @cache_dir "ex_icon"

  @impl Mix.Task
  def run(args) do
    {opts, []} = OptionParser.parse!(args, @switches)

    case ExIcon.read_config() do
      {:ok, config} ->
        cache_dir = Path.join(Mix.Utils.mix_cache(), @cache_dir)
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
    Enum.each(config, &download_and_generate(&1, cache_dir, force?))
  end

  defp download_and_generate({config_name, opts}, cache_dir, force?) do
    IO.puts("Processing #{config_name}...")
    svg_dir = ExIcon.download(cache_dir, opts, force: force?)

    IO.puts("Preparing assigns for #{config_name}...")
    assigns = ExIcon.prepare_assigns(svg_dir, opts)

    IO.puts("Generating module for #{config_name}...")
    template_path = ExIcon.template_path()
    module_path = Keyword.fetch!(opts, :module_path)

    Mix.Generator.copy_template(template_path, module_path, assigns)

    Mix.Task.run("format", [module_path])
    Mix.Task.reenable("format")
  end
end
