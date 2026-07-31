defmodule Mix.Tasks.ExIcon.Gen.IconsTest do
  # async: false because the config is read from the current working directory
  # and tests need to change the folder
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  defmodule TestProvider do
    @moduledoc false
    @behaviour ExIcon.Provider

    @impl true
    def release_url(_), do: "http://127.0.0.1:1/unused.zip"

    @impl true
    def svg_folder(_), do: "icons"

    @impl true
    def variants(_), do: %{plain: "icons", nested: "icons/nested"}
  end

  setup %{tmp_dir: tmp_dir} do
    cache_dir = Path.join(tmp_dir, "cache")
    svg_dir = Path.join([cache_dir, "test_provider", "1.0.0", "icons"])
    File.mkdir_p!(Path.join(svg_dir, "nested"))
    File.write!(Path.join(svg_dir, "arrow-left.svg"), svg())
    File.write!(Path.join([svg_dir, "nested", "bell.svg"]), svg())

    System.put_env("EX_ICON_CACHE_DIR", cache_dir)
    on_exit(fn -> System.delete_env("EX_ICON_CACHE_DIR") end)

    %{cache_dir: cache_dir}
  end

  defp svg do
    ~s(<svg stroke="currentColor"><path d="M19 12H5" /></svg>)
  end

  defp write_config(tmp_dir, config) do
    File.write!(Path.join(tmp_dir, ".ex_icon.exs"), inspect(config))
  end

  defp icon_set(extra \\ []) do
    Keyword.merge(
      [
        icons: ["arrow-left"],
        provider: TestProvider,
        version: "1.0.0",
        module_path: "output/icons.ex",
        module_name: MyAppWeb.Components.Icons
      ],
      extra
    )
  end

  defp run(tmp_dir, args) do
    File.cd!(tmp_dir, fn ->
      capture_io(fn -> Mix.Task.rerun("ex_icon.gen.icons", args) end)
    end)
  end

  test "generates the configured module", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set())

    output = run(tmp_dir, [])

    assert output =~ "Processing icons..."
    assert output =~ "Generating MyAppWeb.Components.Icons..."
    assert output =~ "Done."

    generated = File.read!(Path.join(tmp_dir, "output/icons.ex"))
    assert generated =~ "defmodule MyAppWeb.Components.Icons do"
    assert generated =~ "def arrow_left(assigns) do"
  end

  test "generates a module per variant", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(icons: :all, variants: [:plain, :nested])
    )

    output = run(tmp_dir, [])

    assert output =~ "Generating MyAppWeb.Components.Icons.Plain..."
    assert output =~ "Generating MyAppWeb.Components.Icons.Nested..."

    assert File.read!(Path.join(tmp_dir, "output/icons/plain.ex")) =~
             "def arrow_left(assigns) do"

    assert File.read!(Path.join(tmp_dir, "output/icons/nested.ex")) =~
             "def bell(assigns) do"
  end

  test "generates only the named icon set", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(),
      other: icon_set(module_path: "output/other.ex", module_name: Other)
    )

    output = run(tmp_dir, ["--icon-set", "other"])

    refute output =~ "Processing icons..."
    assert output =~ "Processing other..."
    assert File.exists?(Path.join(tmp_dir, "output/other.ex"))
    refute File.exists?(Path.join(tmp_dir, "output/icons.ex"))
  end

  test "reports the cache folder", %{tmp_dir: tmp_dir, cache_dir: cache_dir} do
    write_config(tmp_dir, icons: icon_set())

    assert run(tmp_dir, []) =~ cache_dir
  end

  describe "cache_dir/0" do
    test "defaults to the mix cache folder" do
      System.delete_env("EX_ICON_CACHE_DIR")

      assert Mix.Tasks.ExIcon.Gen.Icons.cache_dir() ==
               Path.join(Mix.Utils.mix_cache(), "ex_icon")
    end

    test "can be overridden with an environment variable" do
      System.put_env("EX_ICON_CACHE_DIR", "/tmp/ex_icon_cache")

      assert Mix.Tasks.ExIcon.Gen.Icons.cache_dir() == "/tmp/ex_icon_cache"
    end
  end

  test "exits if the named icon set does not exist", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set())

    output =
      capture_io(fn ->
        assert catch_exit(
                 File.cd!(tmp_dir, fn ->
                   Mix.Task.rerun("ex_icon.gen.icons", ["--icon-set", "nope"])
                 end)
               ) == {:shutdown, 1}
      end)

    assert output =~ "Icon set nope not found in configuration."
    assert output =~ "[:icons]"
  end

  test "exits if the configuration file is missing", %{tmp_dir: tmp_dir} do
    output =
      capture_io(fn ->
        assert catch_exit(
                 File.cd!(tmp_dir, fn ->
                   Mix.Task.rerun("ex_icon.gen.icons", [])
                 end)
               ) == {:shutdown, 1}
      end)

    assert output =~ "An error occurred."
    assert output =~ ":enoent"
  end
end
