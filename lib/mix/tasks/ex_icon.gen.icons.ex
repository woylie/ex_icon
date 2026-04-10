defmodule Mix.Tasks.ExIcon.Gen.Icons do
  @shortdoc "Downloads and generates all icons"

  @moduledoc """
  Downloads and generates all icons.

  The task expects the configuration file `.ex_icon.exs` to exist.

  ## Usage

      mix ex_icon.gen
  """

  use Mix.Task

  @tmp_dir "ex_icon"

  @impl Mix.Task
  def run(_) do
    case ExIcon.read_config() do
      {:ok, config} ->
        tmp_dir = Path.join([System.tmp_dir!(), @tmp_dir])
        download_and_generate_all(config, tmp_dir)

        IO.puts("Done.")

      {:error, reason} ->
        IO.puts("""
        An error occurred.

        #{inspect(reason, pretty: true)}
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

    Mix.Generator.copy_template(template_path, module_path, assigns,
      format_elixir: true
    )
  end
end
