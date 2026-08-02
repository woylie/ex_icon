defmodule ExIcon.Provider do
  @moduledoc """
  Behaviour for icon providers.
  """

  @doc """
  Returns the download URL for the release with the given version.

  The URL must point to a zip file, and must use https unless it points at the
  local machine. Only this URL is checked: the HTTP client follows redirects,
  which may lead to another host or to plain http.
  """
  @callback release_url(version) :: url
            when version: String.t(), url: String.t()

  @doc """
  Returns the folder that contains the SVG files in the unpacked release.

  For a provider with variants, this is the folder of the variant to use when
  the configuration does not select any.
  """
  @callback svg_folder(version) :: String.t() when version: String.t()

  @doc """
  Returns the folder of each variant of the icon library.

  Some icon libraries ship the same icons in multiple styles, such as outlined
  and filled. Providers for such libraries implement this callback, which allows
  the `variants` configuration option to select them. Each variant is generated
  into a module of its own.

  This callback is optional. Without it, the library has a single variant, and
  the `variants` option cannot be used.

  ## Example

      def variants(version) do
        %{
          outline: "heroicons-\#{version}/optimized/24/outline",
          solid: "heroicons-\#{version}/optimized/24/solid"
        }
      end
  """
  @callback variants(version) :: %{atom => Path.t()} when version: String.t()

  @optional_callbacks variants: 1
end
