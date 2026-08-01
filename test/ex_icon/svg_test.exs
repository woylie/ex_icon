defmodule ExIcon.SVGTest do
  use ExUnit.Case, async: true

  alias ExIcon.SVG

  describe "parse/1" do
    test "returns the root attributes and the body" do
      assert SVG.parse(
               ~s|<svg xmlns="x" viewBox="0 0 24 24"><path d="M1 1" /></svg>|
             ) ==
               {:ok,
                {[{"xmlns", "x"}, {"viewBox", "0 0 24 24"}],
                 ~s|<path d="M1 1" />|}}
    end

    test "handles a self-closing root element" do
      assert SVG.parse(~s|<svg xmlns="x" />|) == {:ok, {[{"xmlns", "x"}], ""}}
    end

    test "keeps nested elements and text" do
      assert SVG.parse(~s|<svg xmlns="x"><g><title>Hi</title></g></svg>|) ==
               {:ok, {[{"xmlns", "x"}], ~s|<g><title>Hi</title></g>|}}
    end

    test "keeps single quoted attributes" do
      assert SVG.parse(~s|<svg xmlns='x'><path d='M1 1' /></svg>|) ==
               {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "keeps namespaced attribute names" do
      assert {:ok, {[{"xmlns", "x"}, {"xmlns:xlink", "y"}], _}} =
               SVG.parse(~s|<svg xmlns="x" xmlns:xlink="y"></svg>|)
    end

    test "keeps the casing of names" do
      assert {:ok, {[{"viewBox", "0 0 1 1"}, {"WIDTH", "24"}], _}} =
               SVG.parse(~s|<svg viewBox="0 0 1 1" WIDTH="24"></svg>|)
    end

    test "resolves entities and writes them back out" do
      assert {:ok, {_, ~s|<title>Caf&amp;é</title>|}} =
               SVG.parse(~s|<svg xmlns="x"><title>Caf&amp;&#233;</title></svg>|)
    end

    test "resolves the predefined entities and hexadecimal references" do
      assert {:ok, {_, body}} =
               SVG.parse(
                 ~s|<svg xmlns="x"><title>&lt;&gt;&quot;&apos;&#x41;</title></svg>|
               )

      assert body == ~s|<title>&lt;&gt;&quot;'A</title>|
    end

    test "rejects a malformed closing tag" do
      assert SVG.parse(~s|<svg xmlns="x"><g></g bad></svg>|) ==
               {:error, "malformed closing tag for <g>"}
    end

    test "rejects a file that ends in the middle of text" do
      assert SVG.parse(~s|<svg xmlns="x">abc|) ==
               {:error, "<svg> is never closed"}
    end

    test "escapes text that would end the heredoc of the generated component" do
      assert {:ok, {_, body}} =
               SVG.parse(~s|<svg xmlns="x"><title>a"""b</title></svg>|)

      refute body =~ ~s(""")
      assert body == ~s|<title>a&quot;&quot;&quot;b</title>|
    end

    test "escapes text that HEEx would read as an expression" do
      assert {:ok, {_, ~s|<title>&lbrace;1 + 1&rbrace;</title>|}} =
               SVG.parse(~s|<svg xmlns="x"><title>{1 + 1}</title></svg>|)
    end

    test "escapes attribute values" do
      assert {:ok, {_, ~s|<path d="a&quot;b&amp;c" />|}} =
               SVG.parse(~s|<svg xmlns="x"><path d='a"b&amp;c' /></svg>|)
    end

    test "rejects elements that are not allowed" do
      assert SVG.parse(~s|<svg xmlns="x"><script>alert(1)</script></svg>|) ==
               {:error, "the <script> element is not allowed in an icon"}
    end

    test "rejects attributes that are not allowed" do
      assert SVG.parse(~s|<svg xmlns="x"><path onclick="x" /></svg>|) ==
               {:error, "the onclick attribute is not allowed in an icon"}
    end

    test "allows data and aria attributes" do
      assert {:ok, {_, ~s|<path data-slot="icon" aria-label="a" />|}} =
               SVG.parse(
                 ~s|<svg xmlns="x"><path data-slot="icon" aria-label="a" /></svg>|
               )
    end

    test "rejects a root element that is not svg" do
      assert SVG.parse(~s|<path d="M1 1" />|) ==
               {:error, "expected <svg> as the root element, got <path>"}
    end

    test "rejects content after the root element" do
      assert SVG.parse(~s|<svg xmlns="x"></svg><svg xmlns="y"></svg>|) ==
               {:error, "unexpected content after the root element"}
    end

    test "skips an xml declaration, doctype and comments before the root" do
      svg = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/svg11.dtd">
      <!-- Generator: some design tool -->
      <svg xmlns="x"><path d="M1 1" /></svg>
      """

      assert SVG.parse(svg) == {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "drops comments inside the body" do
      assert SVG.parse(
               ~s|<svg xmlns="x"><!-- hi --><path d="M1 1" /><!-- bye --></svg>|
             ) == {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "skips a trailing comment" do
      assert SVG.parse(~s|<svg xmlns="x"></svg><!-- bye -->|) ==
               {:ok, {[{"xmlns", "x"}], ""}}
    end

    test "rejects a doctype with an internal subset" do
      svg = ~s|<!DOCTYPE svg [<!ENTITY x "y">]><svg xmlns="x"></svg>|

      assert SVG.parse(svg) ==
               {:error, "a doctype with an internal subset is not allowed"}
    end

    test "rejects a prologue that is never closed" do
      assert SVG.parse(~s|<?xml version="1.0"|) ==
               {:error, "the xml declaration is never closed"}

      assert SVG.parse(~s|<!-- hi|) == {:error, "a comment is never closed"}

      assert SVG.parse(~s|<!DOCTYPE svg|) ==
               {:error, "the doctype is never closed"}
    end

    test "rejects a comment in the body that is never closed" do
      assert SVG.parse(~s|<svg xmlns="x"><!-- hi</svg>|) ==
               {:error, "a comment is never closed"}
    end

    test "rejects an unclosed element" do
      assert SVG.parse(~s|<svg xmlns="x"><g></svg>|) ==
               {:error, "</svg> closes an element that is not open"}
    end

    test "rejects a missing closing tag" do
      assert SVG.parse(~s|<svg xmlns="x">|) == {:error, "<svg> is never closed"}
    end

    test "drops elements in a namespace other than svg" do
      svg =
        ~s|<svg xmlns="x"><sodipodi:namedview inkscape:zoom="1">| <>
          ~s|<inkscape:grid />raw & text</sodipodi:namedview>| <>
          ~s|<path d="M1 1" /></svg>|

      assert SVG.parse(svg) == {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "drops metadata" do
      svg =
        ~s|<svg xmlns="x"><metadata><rdf:RDF>x</rdf:RDF></metadata>| <>
          ~s|<path d="M1 1" /></svg>|

      assert SVG.parse(svg) == {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "keeps elements in the svg namespace" do
      assert SVG.parse(~s|<svg xmlns="x"><svg:path d="M1 1" /></svg>|) ==
               {:ok, {[{"xmlns", "x"}], ~s|<path d="M1 1" />|}}
    end

    test "rejects a file whose root element is dropped" do
      assert SVG.parse(~s|<metadata>x</metadata>|) ==
               {:error, "expected <svg> as the root element"}
    end

    test "keeps a style attribute" do
      assert {:ok, {_, ~s|<path style="fill:#000" />|}} =
               SVG.parse(~s|<svg xmlns="x"><path style="fill:#000" /></svg>|)
    end

    test "rejects a style that loads a resource" do
      assert SVG.parse(
               ~s|<svg xmlns="x"><path style="background:URL(https://x/t)" /></svg>|
             ) == {:error, "style may not load a resource"}
    end

    test "keeps font attributes" do
      svg =
        ~s|<svg xmlns="x"><text font-size="12" text-anchor="middle">A</text></svg>|

      assert {:ok, {_, ~s|<text font-size="12" text-anchor="middle">A</text>|}} =
               SVG.parse(svg)
    end

    test "skips a byte order mark" do
      assert SVG.parse("﻿" <> ~s|<svg xmlns="x"></svg>|) ==
               {:ok, {[{"xmlns", "x"}], ""}}
    end

    test "accepts a root element in any casing" do
      assert SVG.parse(~s|<SVG xmlns="x"><PATH d="M1 1" /></SVG>|) ==
               {:ok, {[{"xmlns", "x"}], ~s|<PATH d="M1 1" />|}}
    end

    test "keeps a reference into the same file" do
      assert {:ok, {_, ~s|<use href="#a" />|}} =
               SVG.parse(~s|<svg xmlns="x"><use href="#a" /></svg>|)

      assert {:ok, {_, ~s|<use xlink:href="#a" />|}} =
               SVG.parse(~s|<svg xmlns="x"><use xlink:href="#a" /></svg>|)
    end

    test "rejects a reference to another document" do
      assert SVG.parse(
               ~s|<svg xmlns="x"><use href="https://x/y.svg#a" /></svg>|
             ) ==
               {:error, "href may only point into the same file"}
    end

    test "rejects cdata sections" do
      assert SVG.parse(~s|<svg xmlns="x"><![CDATA[<script>]]></svg>|) ==
               {:error, "malformed element name"}
    end

    test "rejects a malformed attribute" do
      assert SVG.parse(~s|<svg xmlns=x></svg>|) ==
               {:error, "malformed attribute"}
    end

    test "rejects a character reference that is not a character" do
      assert SVG.parse(~s|<svg xmlns="x"><title>&#xD800;</title></svg>|) ==
               {:error, "malformed entity reference"}

      assert SVG.parse(~s|<svg xmlns="x"><title>&#99999999999;</title></svg>|) ==
               {:error, "malformed entity reference"}
    end

    test "rejects a malformed entity reference" do
      assert SVG.parse(~s|<svg xmlns="x"><title>a & b</title></svg>|) ==
               {:error, "malformed entity reference"}
    end

    test "rejects text that is not an element" do
      assert SVG.parse("not an svg") == {:error, "expected an element"}
    end
  end
end
