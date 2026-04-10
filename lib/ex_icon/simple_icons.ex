defmodule ExIcon.SimpleIcons do
  @moduledoc """
  ExIcon provider for Simple Icons.

  https://simpleicons.org
  """

  @behaviour ExIcon.Provider

  @impl true
  def release_url(version) when is_binary(version) do
    "https://github.com/simple-icons/simple-icons/archive/refs/tags/#{version}.zip"
  end

  @impl true
  def svg_folder(version) do
    "simple-icons-#{version}/icons"
  end
end
