defmodule ExIcon.SourceTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule UnreachableProvider do
    @moduledoc false
    @behaviour ExIcon.Provider

    @impl true
    def release_url(_), do: "https://localhost:1/nonexistent.zip"

    @impl true
    def svg_folder(_), do: "icons"
  end

  defmodule LocalProvider do
    @behaviour ExIcon.Provider

    @impl true
    def release_url(version) do
      "#{Application.fetch_env!(:ex_icon, :test_base_url)}/#{version}.zip"
    end

    @impl true
    def svg_folder(_), do: "icons"

    @impl true
    def variants(_), do: %{plain: "icons", nested: "icons/nested"}
  end

  describe "Source.icon_dir/3 with a served release" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      {:ok, _} = Application.ensure_all_started(:inets)

      served = Path.join(tmp_dir, "served")
      File.mkdir_p!(served)

      {:ok, {_name, zip}} =
        :zip.create(
          ~c"1.0.0.zip",
          [
            {~c"icons/arrow-left.svg", "<svg></svg>"},
            {~c"icons/nested/bell.svg", "<svg></svg>"}
          ],
          [:memory]
        )

      File.write!(Path.join(served, "1.0.0.zip"), zip)

      {:ok, httpd} =
        :inets.start(:httpd,
          port: 0,
          server_name: ~c"ex_icon_test",
          server_root: String.to_charlist(served),
          document_root: String.to_charlist(served),
          bind_address: {127, 0, 0, 1}
        )

      port = Keyword.fetch!(:httpd.info(httpd), :port)
      Application.put_env(:ex_icon, :test_base_url, "http://127.0.0.1:#{port}")

      on_exit(fn ->
        :inets.stop(:httpd, httpd)
        Application.delete_env(:ex_icon, :test_base_url)
      end)

      cache_dir = Path.join(tmp_dir, "cache")

      opts = [
        icons: :all,
        provider: LocalProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      %{cache_dir: cache_dir, opts: opts}
    end

    test "downloads and unpacks the release into the cache", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      {icon_dir, output} =
        with_io(fn -> ExIcon.Source.icon_dir(cache_dir, opts) end)

      assert output =~ "Downloading local_provider 1.0.0..."

      assert icon_dir ==
               Path.join([
                 cache_dir,
                 "ex_icon_source_test_local_provider",
                 "1.0.0"
               ])

      assert File.read!(Path.join([icon_dir, "icons", "arrow-left.svg"])) ==
               "<svg></svg>"

      assert File.ls!(
               Path.join(cache_dir, "ex_icon_source_test_local_provider")
             ) == [
               "1.0.0"
             ]
    end

    test "reuses the cached release on the next call", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      capture_io(fn -> ExIcon.Source.icon_dir(cache_dir, opts) end)

      marker =
        Path.join([
          cache_dir,
          "ex_icon_source_test_local_provider",
          "1.0.0",
          "marker"
        ])

      File.write!(marker, "kept")

      assert capture_io(fn -> ExIcon.Source.icon_dir(cache_dir, opts) end) =~
               "Using cached local_provider 1.0.0"

      assert File.read!(marker) == "kept"
    end

    test "downloads again with the force option", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      capture_io(fn -> ExIcon.Source.icon_dir(cache_dir, opts) end)

      marker =
        Path.join([
          cache_dir,
          "ex_icon_source_test_local_provider",
          "1.0.0",
          "marker"
        ])

      File.write!(marker, "discarded")

      assert capture_io(fn ->
               ExIcon.Source.icon_dir(cache_dir, opts, true)
             end) =~ "Downloading local_provider 1.0.0..."

      refute File.exists?(marker)

      assert File.exists?(
               Path.join([
                 cache_dir,
                 "ex_icon_source_test_local_provider",
                 "1.0.0",
                 "icons"
               ])
             )
    end

    test "raises if the release cannot be moved into the cache", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      icon_dir =
        Path.join([cache_dir, "ex_icon_source_test_local_provider", "1.0.0"])

      File.mkdir_p!(Path.dirname(icon_dir))
      File.write!(icon_dir, "not a folder")

      capture_io(fn ->
        assert_raise RuntimeError,
                     ~r/Unable to move the downloaded icons into the cache/,
                     fn -> ExIcon.Source.icon_dir(cache_dir, opts) end
      end)

      assert File.ls!(Path.dirname(icon_dir)) == ["1.0.0"]
    end

    test "unpacks the folder of every variant from a single download", %{
      cache_dir: cache_dir,
      opts: opts
    } do
      opts = Keyword.put(opts, :variants, [:plain, :nested])

      {icon_dir, _output} =
        with_io(fn -> ExIcon.Source.icon_dir(cache_dir, opts) end)

      for {svg_folder, _module_name, _module_path} <-
            ExIcon.Target.targets(opts) do
        assert File.dir?(Path.join(icon_dir, svg_folder))
      end
    end
  end

  describe "Source.icon_dir/3" do
    @describetag :tmp_dir

    test "reuses a cached release without downloading again", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: ExIcon.Providers.Lucide,
        version: "1.8.0",
        module_path: Path.join(tmp_dir, "lib/components/lucide.ex"),
        module_name: MyAppWeb.Components.Lucide
      ]

      icon_dir = Path.join([tmp_dir, "ex_icon_providers_lucide", "1.8.0"])
      svg_dir = Path.join(icon_dir, "icons")
      File.mkdir_p!(svg_dir)
      File.write!(Path.join(svg_dir, "cached.svg"), "<svg></svg>")

      assert capture_io(fn ->
               assert ExIcon.Source.icon_dir(tmp_dir, opts) == icon_dir
             end) =~ "Using cached lucide 1.8.0"

      assert File.read!(Path.join(svg_dir, "cached.svg")) == "<svg></svg>"
    end

    test "downloads again when forced", %{tmp_dir: tmp_dir} do
      opts = [
        icons: :all,
        provider: UnreachableProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      icon_dir =
        Path.join([
          tmp_dir,
          "ex_icon_source_test_unreachable_provider",
          "1.0.0"
        ])

      svg_dir = Path.join(icon_dir, "icons")
      File.mkdir_p!(svg_dir)

      capture_io(fn ->
        assert ExIcon.Source.icon_dir(tmp_dir, opts) == icon_dir
      end)

      capture_io(fn ->
        assert_raise RuntimeError, ~r/unable to fetch icons/, fn ->
          ExIcon.Source.icon_dir(tmp_dir, opts, true)
        end
      end)

      refute File.dir?(svg_dir)
    end

    test "leaves no staging folder behind when the download fails", %{
      tmp_dir: tmp_dir
    } do
      opts = [
        icons: :all,
        provider: UnreachableProvider,
        version: "1.0.0",
        module_path: Path.join(tmp_dir, "lib/components/icons.ex"),
        module_name: MyAppWeb.Components.Icons
      ]

      capture_io(fn ->
        assert_raise RuntimeError, ~r/unable to fetch icons/, fn ->
          ExIcon.Source.icon_dir(tmp_dir, opts)
        end
      end)

      refute File.dir?(
               Path.join([
                 tmp_dir,
                 "ex_icon_source_test_unreachable_provider",
                 "1.0.0"
               ])
             )

      assert File.ls!(
               Path.join(tmp_dir, "ex_icon_source_test_unreachable_provider")
             ) ==
               []
    end
  end

  describe "Source.icon_dir/3 validation" do
    @describetag :tmp_dir

    defmodule PlainHttpProvider do
      @behaviour ExIcon.Provider
      @impl true
      def release_url(_), do: "http://example.com/icons.zip"
      @impl true
      def svg_folder(_), do: "icons"
    end

    test "raises for a version that is not a plain version", %{
      tmp_dir: tmp_dir
    } do
      for version <- ["../../etc", "1.0.0/../..", ".."] do
        opts = [provider: UnreachableProvider, version: version]

        assert_raise ArgumentError, ~r/invalid version/, fn ->
          ExIcon.Source.icon_dir(tmp_dir, opts)
        end
      end
    end

    test "raises for a release URL that is not https", %{tmp_dir: tmp_dir} do
      opts = [provider: PlainHttpProvider, version: "1.0.0"]

      capture_io(fn ->
        assert_raise ArgumentError, ~r/invalid release URL/, fn ->
          ExIcon.Source.icon_dir(tmp_dir, opts)
        end
      end)
    end

    test "keeps providers apart that share the last name segment", %{
      tmp_dir: tmp_dir
    } do
      capture_io(fn ->
        assert_raise RuntimeError, fn ->
          ExIcon.Source.icon_dir(tmp_dir,
            provider: UnreachableProvider,
            version: "1.0.0"
          )
        end
      end)

      assert File.ls!(tmp_dir) == ["ex_icon_source_test_unreachable_provider"]
    end
  end

  describe "Source.unpack_archive!/2" do
    @describetag :tmp_dir

    test "unpacks a regular archive", %{tmp_dir: tmp_dir} do
      zip = build_zip([{~c"icons/arrow-left.svg", "<svg></svg>"}])
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.Source.unpack_archive!(zip, target) == :ok

      assert File.read!(Path.join([target, "icons", "arrow-left.svg"])) ==
               "<svg></svg>"
    end

    test "raises if the archive is not a zip file", %{tmp_dir: tmp_dir} do
      assert_raise RuntimeError, ~r/Unable to read zip archive/, fn ->
        ExIcon.Source.unpack_archive!("not a zip archive", tmp_dir)
      end
    end

    test "raises if the archive cannot be unpacked", %{tmp_dir: tmp_dir} do
      target = Path.join(tmp_dir, "read-only")
      File.mkdir_p!(target)
      File.chmod!(target, 0o500)
      on_exit(fn -> File.chmod(target, 0o700) end)

      zip = build_zip([{~c"icons/arrow-left.svg", "<svg></svg>"}])

      assert_raise RuntimeError, ~r/Unable to unpack zip archive/, fn ->
        ExIcon.Source.unpack_archive!(zip, target)
      end
    end

    test "refuses an archive that declares more than the size cap", %{
      tmp_dir: tmp_dir
    } do
      zip = build_zip([{~c"icons/big.svg", String.duplicate("A", 5000)}])
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/unpacks to more than/, fn ->
        ExIcon.Source.unpack_archive!(zip, target, max_size: 1024)
      end

      assert File.ls!(target) == []
    end

    test "refuses an archive that unpacks to more than the size cap", %{
      tmp_dir: tmp_dir
    } do
      zip = build_zip_with_understated_size()
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/unpacks to more than/, fn ->
        ExIcon.Source.unpack_archive!(zip, target, max_size: 1024)
      end
    end

    test "normalizes the modes of the unpacked files", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      File.mkdir_p!(Path.join(source, "icons"))
      icon = Path.join([source, "icons", "arrow-left.svg"])
      File.write!(icon, "<svg></svg>")
      File.chmod!(icon, 0o777)

      zip_path = Path.join(tmp_dir, "modes.zip")

      {:ok, _} =
        :zip.create(String.to_charlist(zip_path), [~c"icons"],
          cwd: String.to_charlist(source)
        )

      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert ExIcon.Source.unpack_archive!(File.read!(zip_path), target) == :ok

      unpacked = Path.join([target, "icons", "arrow-left.svg"])
      assert File.stat!(unpacked).mode == 0o100644
      assert File.stat!(Path.join(target, "icons")).mode == 0o40755
    end

    test "refuses entries that escape the target folder", %{tmp_dir: tmp_dir} do
      zip =
        build_zip([
          {~c"icons/arrow-left.svg", "<svg></svg>"},
          {~c"../escaped.svg", "<svg></svg>"},
          {~c"icons/../../escaped-too.svg", "<svg></svg>"},
          {~c"./../escaped-again.svg", "<svg></svg>"}
        ])

      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.Source.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []
      assert File.ls!(tmp_dir) == ["target"]
    end

    test "refuses entries that climb back down after escaping", %{
      tmp_dir: tmp_dir
    } do
      zip =
        build_zip([
          {~c"../evil/payload.exs", "# escaped"},
          {~c"../../other_provider/1.0.0/poisoned.svg", "<svg></svg>"}
        ])

      target = Path.join([tmp_dir, "cache", "provider", "1.0.0.download-1"])
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.Source.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []

      assert File.ls!(Path.join([tmp_dir, "cache", "provider"])) ==
               ["1.0.0.download-1"]

      assert File.ls!(Path.join(tmp_dir, "cache")) == ["provider"]
    end

    test "refuses an entry the central directory names differently", %{
      tmp_dir: tmp_dir
    } do
      zip = build_zip_with_mismatched_name()
      target = Path.join([tmp_dir, "cache", "target"])
      File.mkdir_p!(target)

      assert {:ok, [_comment, {:zip_file, ~c"icons/aaaaaa.svg", _, _, _, _}]} =
               :zip.list_dir(zip)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.Source.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []
      assert File.ls!(Path.join(tmp_dir, "cache")) == ["target"]
    end

    test "refuses entries with an absolute path", %{tmp_dir: tmp_dir} do
      zip = build_zip_with_absolute_entry()
      target = Path.join(tmp_dir, "target")
      File.mkdir_p!(target)

      assert_raise RuntimeError, ~r/would be written outside/, fn ->
        ExIcon.Source.unpack_archive!(zip, target)
      end

      assert File.ls!(target) == []
    end
  end

  defp build_zip(entries) do
    {:ok, {_name, zip}} = :zip.create(~c"icons.zip", entries, [:memory])
    zip
  end

  defp build_zip_with_understated_size do
    zip = build_zip([{~c"icons/big.svg", String.duplicate("A", 5000)}])
    {position, _length} = :binary.match(zip, <<0x50, 0x4B, 0x01, 0x02>>)
    offset = position + 24

    binary_part(zip, 0, offset) <>
      <<100::little-32>> <>
      binary_part(zip, offset + 4, byte_size(zip) - offset - 4)
  end

  # only the local file header decides where the file is written; the two names
  # are the same length to keep the offsets in the archive valid
  defp build_zip_with_mismatched_name do
    benign = "icons/aaaaaa.svg"
    evil = "../evil/xxxx.svg"

    zip = build_zip([{String.to_charlist(benign), "<svg></svg>"}])
    {position, _length} = :binary.match(zip, <<0x50, 0x4B, 0x03, 0x04>>)
    offset = position + 30

    binary_part(zip, 0, offset) <>
      evil <>
      binary_part(
        zip,
        offset + byte_size(benign),
        byte_size(zip) - offset - byte_size(benign)
      )
  end

  defp build_zip_with_absolute_entry do
    ~c"_abs/escaped.svg"
    |> then(&build_zip([{&1, "<svg></svg>"}]))
    |> String.replace("_abs/escaped.svg", "/abs/escaped.svg")
  end
end
