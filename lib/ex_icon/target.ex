defmodule ExIcon.Target do
  @moduledoc false

  # Works out which modules an icon set generates, and which folder of the
  # release each of them is built from. An icon set with variants produces one
  # target per variant.

  def targets(opts) do
    module_name = Keyword.fetch!(opts, :module_name)
    module_path = Keyword.fetch!(opts, :module_path)

    case ExIcon.Source.resolve!(opts) do
      {:path, path} ->
        no_variants!(opts)
        ExIcon.Source.existing_dir!(path)
        [{"", module_name, module_path}]

      {:release, provider, version} ->
        load_provider!(provider)
        release_targets(opts, provider, version, module_name, module_path)
    end
  end

  defp release_targets(opts, provider, version, module_name, module_path) do
    case Keyword.get(opts, :variants, []) do
      [] ->
        [{provider.svg_folder(version), module_name, module_path}]

      variants ->
        available = available_variants!(provider, version)

        Enum.map(variants, fn variant ->
          {fetch_variant!(available, variant, provider),
           Module.concat(module_name, variant_alias(variant)),
           variant_module_path(module_path, variant)}
        end)
    end
  end

  defp no_variants!(opts) do
    if Keyword.get(opts, :variants, []) == [] do
      :ok
    else
      Mix.raise("""
      variants are not supported for an icon set with a :path

      Variants are the style folders of a release. Configure one icon set per
      folder instead.
      """)
    end
  end

  defp load_provider!(provider) do
    if Code.ensure_loaded?(provider) do
      required_callbacks!(provider)
    else
      Mix.raise("""
      could not load the provider #{inspect(provider)}

      Make sure the module exists and is compiled.
      """)
    end
  end

  @required_callbacks [release_url: 1, svg_folder: 1]

  defp required_callbacks!(provider) do
    missing =
      for {name, arity} <- @required_callbacks,
          not function_exported?(provider, name, arity),
          do: "#{name}/#{arity}"

    if missing == [] do
      :ok
    else
      Mix.raise("""
      #{inspect(provider)} is not a provider

      It does not implement #{Enum.join(missing, " and ")} of the
      ExIcon.Provider behaviour.
      """)
    end
  end

  defp available_variants!(provider, version) do
    if function_exported?(provider, :variants, 1) do
      provider.variants(version)
    else
      Mix.raise("""
      the :variants option is not supported by #{inspect(provider)}

      Only providers that implement the optional variants/1 callback of the
      ExIcon.Provider behaviour have variants to choose from.
      """)
    end
  end

  defp fetch_variant!(available, variant, provider) do
    case Map.fetch(available, variant) do
      {:ok, folder} ->
        folder

      :error ->
        Mix.raise("""
        unknown variant #{inspect(variant)} for #{inspect(provider)}

        Available variants: #{inspect(Enum.sort(Map.keys(available)))}
        """)
    end
  end

  defp variant_alias(variant) do
    variant |> Atom.to_string() |> Macro.camelize()
  end

  defp variant_module_path(module_path, variant) do
    extension = Path.extname(module_path)

    Path.join(
      Path.rootname(module_path, extension),
      "#{variant}#{extension}"
    )
  end
end
