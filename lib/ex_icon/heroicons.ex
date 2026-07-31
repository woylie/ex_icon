defmodule ExIcon.Heroicons do
  @moduledoc """
  ExIcon provider for Heroicons.

  https://heroicons.com

  The library has four variants, which can be selected with the `variants`
  configuration option:

  - `:outline` - outlined icons on a 24x24 viewbox
  - `:solid` - filled icons on a 24x24 viewbox
  - `:mini` - filled icons on a 20x20 viewbox
  - `:micro` - filled icons on a 16x16 viewbox

  Note that the variants differ in their attributes. The outlined icons have
  `stroke` and `stroke-width` attributes and a `fill` of `none`, while the
  filled ones only have a `fill` of `currentColor`. Attributes that a variant
  does not have are ignored, so a single `attrs` option can cover all of them.

  Not every icon is available in every variant.
  """

  @behaviour ExIcon.Provider

  @impl true
  def release_url(version) when is_binary(version) do
    "https://github.com/tailwindlabs/heroicons/archive/refs/tags/v#{version}.zip"
  end

  @impl true
  def svg_folder(version), do: variants(version).outline

  @impl true
  def variants(version) when is_binary(version) do
    %{
      outline: optimized(version, "24/outline"),
      solid: optimized(version, "24/solid"),
      mini: optimized(version, "20/solid"),
      micro: optimized(version, "16/solid")
    }
  end

  defp optimized(version, path) do
    Path.join(["heroicons-#{version}", "optimized", path])
  end
end
