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
  """

  use Mix.Task

  @switches [
    strict: [
      icon_set: :string
    ]
  ]

  @tmp_dir "ex_icon"

  @impl Mix.Task
  def run(args) do
    {opts, []} = OptionParser.parse!(args, @switches)

    case ExIcon.read_config() do
      {:ok, config} ->
        tmp_dir = Path.join([System.tmp_dir!(), @tmp_dir])
        do_run(config, tmp_dir, opts[:icon_set])
        IO.puts("Done.")

      {:error, reason} ->
        IO.puts("""
        An error occurred.

        #{inspect(reason, pretty: true)}
        """)

        exit({:shutdown, 1})
    end
  end

  defp do_run(config, tmp_dir, nil) do
    download_and_generate_all(config, tmp_dir)
  end

  defp do_run(config, tmp_dir, icon_set) when is_binary(icon_set) do
    icon_set = String.to_atom(icon_set)

    if opts = Keyword.get(config, icon_set) do
      download_and_generate({icon_set, opts}, tmp_dir)
    else
      IO.puts("""
      Icon set #{icon_set} not found in configuration.

      Available icon sets:

          #{inspect(Keyword.keys(config))}
      """)

      exit({:shutdown, 1})
    end
  end

  defp download_and_generate_all(config, tmp_dir) do
    Enum.each(config, &download_and_generate(&1, tmp_dir))
  after
    File.rm_rf(tmp_dir)
  end

  defp download_and_generate({config_name, opts}, tmp_dir) do
    IO.puts("Downloading icons for #{config_name}...")
    svg_dir = ExIcon.download(tmp_dir, opts)

    IO.puts("Preparing assigns for #{config_name}...")
    assigns = ExIcon.prepare_assigns(svg_dir, opts)

    IO.puts("Generating module for #{config_name}...")
    template_path = ExIcon.template_path()
    module_path = Keyword.fetch!(opts, :module_path)

    Mix.Generator.copy_template(template_path, module_path, assigns)
    Mix.Task.run("format", [module_path])
  end
end
