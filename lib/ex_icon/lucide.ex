defmodule ExIcon.Lucide do
  @moduledoc """
  ExIcon provider for Lucide icons.

  https://lucide.dev
  """

  @behaviour ExIcon.Provider

  @impl true
  def release_url(version) when is_binary(version) do
    "https://github.com/lucide-icons/lucide/releases/download/#{version}/lucide-icons-#{version}.zip"
  end

  @impl true
  def svg_folder(_) do
    "icons"
  end
end
