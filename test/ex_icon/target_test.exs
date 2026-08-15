defmodule ExIcon.TargetTest do
  use ExUnit.Case, async: true

  defmodule WithoutSvgFolder do
    @moduledoc false
    def release_url(version), do: "https://example.com/#{version}.zip"
  end

  defmodule WithoutReleaseUrl do
    @moduledoc false
    def svg_folder(_version), do: "icons"
  end

  describe "Target.targets/1" do
    test "returns a single target without variants" do
      assert ExIcon.Target.targets(
               icons: :all,
               provider: ExIcon.Providers.Lucide,
               version: "1.8.0",
               module_path: "lib/components/lucide.ex",
               module_name: MyAppWeb.Components.Lucide
             ) ==
               [
                 {"icons", MyAppWeb.Components.Lucide,
                  "lib/components/lucide.ex"}
               ]
    end

    test "returns a target per configured variant" do
      assert ExIcon.Target.targets(
               icons: :all,
               provider: ExIcon.Providers.Heroicons,
               version: "2.2.0",
               module_path: "lib/components/heroicons.ex",
               module_name: MyAppWeb.Components.Heroicons,
               variants: [:outline, :mini]
             ) ==
               [
                 {"heroicons-2.2.0/optimized/24/outline",
                  MyAppWeb.Components.Heroicons.Outline,
                  "lib/components/heroicons/outline.ex"},
                 {"heroicons-2.2.0/optimized/20/solid",
                  MyAppWeb.Components.Heroicons.Mini,
                  "lib/components/heroicons/mini.ex"}
               ]
    end

    test "raises for an unknown variant" do
      assert_raise Mix.Error, ~r/unknown variant :outlined/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          provider: ExIcon.Providers.Heroicons,
          version: "2.2.0",
          module_path: "lib/components/heroicons.ex",
          module_name: MyAppWeb.Components.Heroicons,
          variants: [:outlined]
        )
      end
    end

    test "raises if the provider cannot be loaded" do
      assert_raise Mix.Error, ~r/could not load the provider/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          provider: NoSuchProvider,
          version: "1.0.0",
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if the provider is missing a required callback" do
      for {provider, missing} <- [
            {Enum, "release_url/1 and svg_folder/1"},
            {WithoutSvgFolder, "svg_folder/1"},
            {WithoutReleaseUrl, "release_url/1"}
          ] do
        error =
          assert_raise Mix.Error, fn ->
            ExIcon.Target.targets(
              icons: :all,
              provider: provider,
              version: "1.0.0",
              module_path: "lib/components/icons.ex",
              module_name: MyAppWeb.Components.Icons
            )
          end

        assert Exception.message(error) =~
                 "#{inspect(provider)} is not a provider"

        assert Exception.message(error) =~ "does not implement #{missing} of"
      end
    end

    test "returns the folder itself for an icon set with a path" do
      assert ExIcon.Target.targets(
               icons: :all,
               path: "test/ex_icon",
               module_path: "lib/components/icons.ex",
               module_name: MyAppWeb.Components.Icons
             ) == [{"", MyAppWeb.Components.Icons, "lib/components/icons.ex"}]
    end

    test "raises if the path of an icon set is not a folder" do
      assert_raise Mix.Error, ~r/is not a folder/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          path: "does/not/exist",
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if an icon set has no source" do
      assert_raise Mix.Error, ~r/icon set without a source/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if an icon set has both a path and a provider" do
      assert_raise Mix.Error, ~r/icon set with two sources/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          path: "assets/icons",
          provider: ExIcon.Providers.Lucide,
          version: "1.8.0",
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if a provider is given without a version" do
      assert_raise Mix.Error, ~r/icon set without a version/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          provider: ExIcon.Providers.Lucide,
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if an icon set with a path configures variants" do
      assert_raise Mix.Error, ~r/variants are not supported/, fn ->
        ExIcon.Target.targets(
          icons: :all,
          path: "assets/icons",
          variants: [:outline],
          module_path: "lib/components/icons.ex",
          module_name: MyAppWeb.Components.Icons
        )
      end
    end

    test "raises if the provider has no variants" do
      assert_raise Mix.Error,
                   ~r/not supported by ExIcon.Providers.Lucide/,
                   fn ->
                     ExIcon.Target.targets(
                       icons: :all,
                       provider: ExIcon.Providers.Lucide,
                       version: "1.8.0",
                       module_path: "lib/components/lucide.ex",
                       module_name: MyAppWeb.Components.Lucide,
                       variants: [:outline]
                     )
                   end
    end
  end
end
