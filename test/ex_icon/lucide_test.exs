defmodule ExIcon.LucideTest do
  use ExUnit.Case, async: true

  alias ExIcon.Lucide

  describe "release_url/1" do
    test "returns the url of the release archive" do
      assert Lucide.release_url("1.8.0") ==
               "https://github.com/lucide-icons/lucide/releases/download/1.8.0/lucide-icons-1.8.0.zip"
    end
  end

  describe "svg_folder/1" do
    test "returns the folder that contains the svg files" do
      assert Lucide.svg_folder("1.8.0") == "icons"
    end
  end

  test "does not implement the optional variants callback" do
    refute function_exported?(Lucide, :variants, 1)
  end
end
