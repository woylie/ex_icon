defmodule ExIcon.Provider do
  @moduledoc """
  Behaviour for icon providers.
  """

  @doc """
  Returns the download URL for the release with the given version.

  The URL must point to a zip file.
  """
  @callback release_url(version) :: url
            when version: String.t(), url: String.t()

  @doc """
  Returns the folder that contains the SVG files in the unpacked release.
  """
  @callback svg_folder(version) :: String.t() when version: String.t()
end
