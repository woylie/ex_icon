defmodule ExIcon.Providers.SimpleIconsTest do
  use ExUnit.Case, async: true

  alias ExIcon.Providers.SimpleIcons

  describe "release_url/1" do
    test "returns the url of the tagged release archive" do
      assert SimpleIcons.release_url("16.15.0") ==
               "https://github.com/simple-icons/simple-icons/archive/refs/tags/16.15.0.zip"
    end
  end

  describe "svg_folder/1" do
    test "returns the folder that contains the svg files" do
      assert SimpleIcons.svg_folder("16.15.0") ==
               "simple-icons-16.15.0/icons"
    end
  end

  test "does not implement the optional variants callback" do
    refute function_exported?(SimpleIcons, :variants, 1)
  end
end
