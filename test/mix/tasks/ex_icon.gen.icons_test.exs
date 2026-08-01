defmodule Mix.Tasks.ExIcon.Gen.IconsTest do
  use ExUnit.Case, async: true

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
    cache_dir = cache_dir(tmp_dir)

    svg_dir =
      Path.join([
        cache_dir,
        "mix_tasks_ex_icon_gen_icons_test_test_provider",
        "1.0.0",
        "icons"
      ])

    File.mkdir_p!(Path.join(svg_dir, "nested"))
    File.write!(Path.join(svg_dir, "arrow-left.svg"), svg())
    File.write!(Path.join([svg_dir, "nested", "bell.svg"]), svg())

    %{cache_dir: cache_dir}
  end

  defp svg do
    ~s(<svg stroke="currentColor"><path d="M19 12H5" /></svg>)
  end

  defp cache_dir(tmp_dir), do: Path.join(tmp_dir, "cache")
  defp config_path(tmp_dir), do: Path.join(tmp_dir, "icons.exs")

  defp write_config(tmp_dir, icon_sets) do
    path = config_path(tmp_dir)
    File.write!(path, inspect(icon_sets: icon_sets))
    path
  end

  defp args(tmp_dir, extra \\ []) do
    ["--config", config_path(tmp_dir), "--cache-dir", cache_dir(tmp_dir)] ++
      extra
  end

  defp icon_set(tmp_dir, extra \\ []) do
    Keyword.merge(
      [
        icons: ["arrow-left"],
        provider: TestProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "output/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ],
      extra
    )
  end

  defp run(tmp_dir, extra \\ []) do
    capture_io(fn ->
      Mix.Task.rerun("ex_icon.gen.icons", args(tmp_dir, extra))
    end)
  end

  test "generates the configured module", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set(tmp_dir))

    output = run(tmp_dir)

    assert output =~ "Processing icons..."
    assert output =~ "Generating MyAppWeb.Components.Icons..."
    assert output =~ "Done."

    generated = File.read!(Path.join(tmp_dir, "output/icons.ex"))
    assert generated =~ "defmodule MyAppWeb.Components.Icons do"
    assert generated =~ "def arrow_left(assigns) do"
  end

  test "generates a module per variant", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir, icons: :all, variants: [:plain, :nested])
    )

    output = run(tmp_dir)

    assert output =~ "Generating MyAppWeb.Components.Icons.Plain..."
    assert output =~ "Generating MyAppWeb.Components.Icons.Nested..."

    assert File.read!(Path.join(tmp_dir, "output/icons/plain.ex")) =~
             "def arrow_left(assigns) do"

    assert File.read!(Path.join(tmp_dir, "output/icons/nested.ex")) =~
             "def bell(assigns) do"
  end

  test "does not write modules that are unchanged", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set(tmp_dir))

    assert run(tmp_dir) =~ "* writing"

    output = run(tmp_dir)

    assert output =~ "is unchanged"
    refute output =~ "* writing"
  end

  test "keeps a changed module and fails if the overwrite is declined", %{
    tmp_dir: tmp_dir
  } do
    write_config(tmp_dir, icons: icon_set(tmp_dir))
    run(tmp_dir)

    module_path = Path.join(tmp_dir, "output/icons.ex")
    File.write!(module_path, "# edited by hand\n")

    output =
      capture_io("n\n", fn ->
        assert catch_exit(Mix.Task.rerun("ex_icon.gen.icons", args(tmp_dir))) ==
                 {:shutdown, 1}
      end)

    assert output =~ "skipping"
    assert File.read!(module_path) == "# edited by hand\n"
  end

  test "overwrites a changed module with --force", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set(tmp_dir))
    run(tmp_dir)

    module_path = Path.join(tmp_dir, "output/icons.ex")
    File.write!(module_path, "# edited by hand\n")

    assert run(tmp_dir, ["--force"]) =~ "* writing"
    assert File.read!(module_path) =~ "def arrow_left(assigns) do"
  end

  test "discards a cached release only once per run with --refresh", %{
    tmp_dir: tmp_dir
  } do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir),
      same_release:
        icon_set(tmp_dir,
          module_path: Path.join(tmp_dir, "output/same_release.ex"),
          module_name: SameRelease
        )
    )

    assert_raise RuntimeError, ~r/unable to fetch icons/, fn ->
      run(tmp_dir, ["--refresh"])
    end
  end

  test "generates from a local folder", %{tmp_dir: tmp_dir} do
    svg_dir = Path.join(tmp_dir, "assets/icons")
    File.mkdir_p!(svg_dir)
    File.write!(Path.join(svg_dir, "arrow-left.svg"), svg())

    write_config(tmp_dir,
      custom: [
        path: svg_dir,
        icons: :all,
        module_path: Path.join(tmp_dir, "output/custom.ex"),
        module_name: MyAppWeb.Components.Custom
      ]
    )

    output = run(tmp_dir)

    assert output =~ "Reading #{Path.relative_to_cwd(svg_dir)}..."
    assert output =~ "* writing"

    assert File.read!(Path.join(tmp_dir, "output/custom.ex")) =~
             "def arrow_left(assigns) do"
  end

  test "fails if the path of an icon set is not a folder", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir),
      custom: [
        path: Path.join(tmp_dir, "nope"),
        icons: :all,
        module_path: Path.join(tmp_dir, "output/custom.ex"),
        module_name: MyAppWeb.Components.Custom
      ]
    )

    assert_raise ArgumentError, ~r/is not a folder/, fn -> run(tmp_dir) end

    refute File.exists?(Path.join(tmp_dir, "output/icons.ex"))
  end

  test "checks every icon set before writing anything", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir),
      broken:
        icon_set(tmp_dir,
          provider: NoSuchProvider,
          module_path: Path.join(tmp_dir, "output/broken.ex"),
          module_name: Broken
        )
    )

    assert_raise ArgumentError, ~r/could not load the provider/, fn ->
      run(tmp_dir)
    end

    refute File.exists?(Path.join(tmp_dir, "output/icons.ex"))
  end

  test "generates only the named icon set", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir),
      other:
        icon_set(tmp_dir,
          module_path: Path.join(tmp_dir, "output/other.ex"),
          module_name: Other
        )
    )

    output = run(tmp_dir, ["--icon-set", "other"])

    refute output =~ "Processing icons..."
    assert output =~ "Processing other..."
    assert File.exists?(Path.join(tmp_dir, "output/other.ex"))
    refute File.exists?(Path.join(tmp_dir, "output/icons.ex"))
  end

  test "reports the cache folder", %{tmp_dir: tmp_dir, cache_dir: cache_dir} do
    write_config(tmp_dir, icons: icon_set(tmp_dir))

    assert run(tmp_dir) =~ cache_dir
  end

  test "does not report the cache folder for a local only configuration", %{
    tmp_dir: tmp_dir,
    cache_dir: cache_dir
  } do
    svg_dir = Path.join(tmp_dir, "assets/icons")
    File.mkdir_p!(svg_dir)
    File.write!(Path.join(svg_dir, "arrow-left.svg"), svg())

    write_config(tmp_dir,
      custom: [
        path: svg_dir,
        icons: :all,
        module_path: Path.join(tmp_dir, "output/custom.ex"),
        module_name: MyAppWeb.Components.Custom
      ]
    )

    output = run(tmp_dir)

    assert output =~ "Done."
    refute output =~ cache_dir
  end

  test "does not report the cache folder when only a local set is selected", %{
    tmp_dir: tmp_dir,
    cache_dir: cache_dir
  } do
    svg_dir = Path.join(tmp_dir, "assets/icons")
    File.mkdir_p!(svg_dir)
    File.write!(Path.join(svg_dir, "arrow-left.svg"), svg())

    write_config(tmp_dir,
      icons: icon_set(tmp_dir),
      custom: [
        path: svg_dir,
        icons: :all,
        module_path: Path.join(tmp_dir, "output/custom.ex"),
        module_name: MyAppWeb.Components.Custom
      ]
    )

    refute run(tmp_dir, ["--icon-set", "custom"]) =~ cache_dir
  end

  test "exits if the named icon set does not exist", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir, icons: icon_set(tmp_dir))

    output =
      capture_io(fn ->
        assert catch_exit(
                 Mix.Task.rerun(
                   "ex_icon.gen.icons",
                   args(tmp_dir, ["--icon-set", "nope"])
                 )
               ) == {:shutdown, 1}
      end)

    assert output =~ "Icon set nope not found in configuration."
    assert output =~ "[:icons]"
  end

  test "exits if the configuration file does not exist", %{tmp_dir: tmp_dir} do
    output =
      capture_io(fn ->
        assert catch_exit(Mix.Task.rerun("ex_icon.gen.icons", args(tmp_dir))) ==
                 {:shutdown, 1}
      end)

    assert output =~ "Could not read #{config_path(tmp_dir)}."
    assert output =~ "no such file or directory"
  end

  test "exits if the configuration file is not valid", %{tmp_dir: tmp_dir} do
    write_config(tmp_dir,
      icons: icon_set(tmp_dir, attrs: [{"stroke", default: "a", fixed: "b"}])
    )

    output =
      capture_io(fn ->
        assert catch_exit(Mix.Task.rerun("ex_icon.gen.icons", args(tmp_dir))) ==
                 {:shutdown, 1}
      end)

    assert output =~ "#{config_path(tmp_dir)} is not valid."
    assert output =~ "sets both :default and :fixed"
  end

  test "caches releases in the given folder", %{
    tmp_dir: tmp_dir,
    cache_dir: cache_dir
  } do
    write_config(tmp_dir, icons: icon_set(tmp_dir))

    assert run(tmp_dir) =~ "* writing"

    assert File.dir?(
             Path.join([
               cache_dir,
               "mix_tasks_ex_icon_gen_icons_test_test_provider",
               "1.0.0"
             ])
           )
  end
end
