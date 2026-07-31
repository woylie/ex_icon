defmodule ExIcon.HeroiconsTest do
  use ExUnit.Case, async: true

  alias ExIcon.Heroicons

  describe "release_url/1" do
    test "returns the url of the tagged release archive" do
      assert Heroicons.release_url("2.2.0") ==
               "https://github.com/tailwindlabs/heroicons/archive/refs/tags/v2.2.0.zip"
    end
  end

  describe "variants/1" do
    test "returns the folder of every variant" do
      assert Heroicons.variants("2.2.0") == %{
               outline: "heroicons-2.2.0/optimized/24/outline",
               solid: "heroicons-2.2.0/optimized/24/solid",
               mini: "heroicons-2.2.0/optimized/20/solid",
               micro: "heroicons-2.2.0/optimized/16/solid"
             }
    end
  end

  describe "svg_folder/1" do
    test "returns the folder of the outline variant" do
      assert Heroicons.svg_folder("2.2.0") ==
               Heroicons.variants("2.2.0").outline
    end
  end
end
