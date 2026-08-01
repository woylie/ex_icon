defmodule ExIcon.SVG do
  @moduledoc false

  @elements ~w(
    circle clipPath defs desc ellipse g line linearGradient mask path pattern
    polygon polyline radialGradient rect stop svg text title tspan use
  )

  @attributes ~w(
    alignment-baseline class clip-path clip-rule color cx cy d direction display
    dominant-baseline enable-background fill fill-opacity fill-rule font-family
    font-size font-stretch font-style font-variant font-weight
    gradientTransform gradientUnits height href id letter-spacing mask offset
    opacity overflow paint-order patternContentUnits patternUnits points
    preserveAspectRatio r role rx ry shape-rendering stop-color stop-opacity
    stroke stroke-dasharray stroke-dashoffset stroke-linecap stroke-linejoin
    stroke-miterlimit stroke-opacity stroke-width style text-anchor
    text-decoration transform vector-effect version viewBox visibility width
    word-spacing x x1 x2 xlink:href xml:space xmlns xmlns:xlink y y1 y2
  )

  # elements written by editors such as Inkscape
  @dropped_elements ~w(metadata)

  # attributes that can load other documents
  @references ~w(href xlink:href)

  @downcased_elements Enum.map(@elements, &String.downcase/1)
  @downcased_attributes Enum.map(@attributes, &String.downcase/1)

  @attribute_regex ~r/^([a-zA-Z_:][a-zA-Z0-9:_.-]*)\s*=\s*("[^"]*"|'[^']*')/s
  @entity_regex ~r/^(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);/

  # pattern allows namespaced prefixes like <sodipodi:namedview>
  @name_regex ~r/^[a-zA-Z][a-zA-Z0-9:._-]*/

  @doc """
  Parses an SVG file into the attributes of its root element and its body.

  The body is returned as a string that is safe to write into a `~H` sigil.
  """
  @spec parse(binary) :: {:ok, {[{binary, binary}], binary}} | {:error, binary}
  def parse(svg) when is_binary(svg) do
    with {:ok, start} <- svg |> String.trim_leading("\uFEFF") |> prologue(),
         {:ok, root_node, rest} <- element_node(start, false),
         {:ok, {attrs, children}} <- root(root_node),
         :ok <- eof(rest) do
      {:ok,
       {attrs, children |> Enum.map(&serialize/1) |> IO.iodata_to_binary()}}
    end
  end

  # skip xml declarations, doctypes and comments (commonly added by design
  # tools during export)
  defp prologue(binary) do
    case skip_whitespace(binary) do
      "<?" <> _ = rest -> skip_past(rest, "?>", "the xml declaration")
      "<!--" <> _ = rest -> skip_past(rest, "-->", "a comment")
      "<!DOCTYPE" <> _ = rest -> doctype(rest)
      rest -> {:ok, rest}
    end
  end

  defp skip_past(binary, terminator, what) do
    case :binary.match(binary, terminator) do
      {position, length} ->
        binary |> chop_at(position + length) |> prologue()

      :nomatch ->
        {:error, "#{what} is never closed"}
    end
  end

  # an internal subset is refused because it can define entities
  defp doctype(binary) do
    case :binary.match(binary, ">") do
      {position, _length} ->
        if String.contains?(binary_part(binary, 0, position), "[") do
          {:error, "a doctype with an internal subset is not allowed"}
        else
          binary |> chop_at(position + 1) |> prologue()
        end

      :nomatch ->
        {:error, "the doctype is never closed"}
    end
  end

  defp chop_at(binary, position) do
    binary_part(binary, position, byte_size(binary) - position)
  end

  defp root(nil), do: {:error, "expected <svg> as the root element"}

  defp root({name, attrs, children}) do
    if String.downcase(name) == "svg",
      do: {:ok, {attrs, children || []}},
      else: {:error, "expected <svg> as the root element, got <#{name}>"}
  end

  defp eof(rest) do
    case prologue(rest) do
      {:ok, ""} -> :ok
      _ -> {:error, "unexpected content after the root element"}
    end
  end

  # `drop?` marks a subtree that is parsed only to get past it and does not end
  # up in the generated component
  defp element_node("<" <> rest, drop?) do
    with {:ok, raw_name, rest} <- name(rest),
         {name, drop?} = element_policy(raw_name, drop?),
         {:ok, attrs, rest, closed?} <- attributes(rest, [], drop?),
         :ok <- allowed_element(name, drop?),
         {:ok, node, rest} <- subtree(rest, name, attrs, closed?, drop?) do
      {:ok, keep(node, drop?), rest}
    end
  end

  defp element_node(_binary, _drop?), do: {:error, "expected an element"}

  defp subtree(rest, name, attrs, true, _drop?),
    do: {:ok, {name, attrs, nil}, rest}

  defp subtree(rest, name, attrs, false, drop?),
    do: children(rest, name, attrs, [], drop?)

  defp element_policy(name, true), do: {name, true}

  defp element_policy(name, false) do
    case String.split(name, ":", parts: 2) do
      ["svg", local] -> {local, false}
      [_prefix, _local] -> {name, true}
      [_name] -> {name, String.downcase(name) in @dropped_elements}
    end
  end

  defp keep(_node, true), do: nil
  defp keep(node, false), do: node

  defp children("</" <> rest, name, attrs, acc, drop?) do
    with {:ok, close_name, rest} <- name(rest) do
      case {skip_whitespace(rest), element_policy(close_name, drop?)} do
        {">" <> rest, {^name, _}} ->
          {:ok, {name, attrs, Enum.reverse(acc)}, rest}

        {">" <> _rest, _} ->
          {:error, "</#{close_name}> closes an element that is not open"}

        _ ->
          {:error, "malformed closing tag for <#{name}>"}
      end
    end
  end

  defp children("<!--" <> _ = binary, name, attrs, acc, drop?) do
    with {:ok, rest} <- skip_past(binary, "-->", "a comment"),
         do: children(rest, name, attrs, acc, drop?)
  end

  defp children("<" <> _ = binary, name, attrs, acc, drop?) do
    with {:ok, child, rest} <- element_node(binary, drop?),
         do: children(rest, name, attrs, prepend(child, acc), drop?)
  end

  defp children("", name, _attrs, _acc, _drop?) do
    {:error, "<#{name}> is never closed"}
  end

  defp children(binary, name, attrs, acc, drop?) do
    {text, rest} = take_text(binary)

    if drop? do
      children(rest, name, attrs, acc, drop?)
    else
      with {:ok, decoded} <- decode(text, []),
           do: children(rest, name, attrs, [{:text, decoded} | acc], drop?)
    end
  end

  defp prepend(nil, acc), do: acc
  defp prepend(node, acc), do: [node | acc]

  defp name(binary) do
    case Regex.run(@name_regex, binary) do
      [name] -> {:ok, name, chop(binary, name)}
      nil -> {:error, "malformed element name"}
    end
  end

  defp attributes(binary, acc, drop?) do
    case skip_whitespace(binary) do
      "/>" <> rest ->
        {:ok, Enum.reverse(acc), rest, true}

      ">" <> rest ->
        {:ok, Enum.reverse(acc), rest, false}

      rest ->
        with {:ok, name, value, rest} <- attribute(rest, drop?),
             do: attributes(rest, [{name, value} | acc], drop?)
    end
  end

  defp attribute(binary, drop?) do
    case Regex.run(@attribute_regex, binary) do
      [match, name, _quoted] when drop? ->
        {:ok, name, "", chop(binary, match)}

      [match, name, quoted] ->
        with :ok <- allowed_attribute(name),
             {:ok, value} <- decode(unquote_value(quoted), []),
             :ok <- allowed_value(name, value) do
          {:ok, name, value, chop(binary, match)}
        end

      nil ->
        {:error, "malformed attribute"}
    end
  end

  defp allowed_value(name, value) do
    case String.downcase(name) do
      reference when reference in @references ->
        if String.starts_with?(value, "#"),
          do: :ok,
          else: {:error, "#{name} may only point into the same file"}

      "style" ->
        if String.contains?(String.downcase(value), "url("),
          do: {:error, "style may not load a resource"},
          else: :ok

      _name ->
        :ok
    end
  end

  defp allowed_element(_name, true), do: :ok

  defp allowed_element(name, false) do
    if String.downcase(name) in @downcased_elements,
      do: :ok,
      else: {:error, "the <#{name}> element is not allowed in an icon"}
  end

  defp allowed_attribute(name) do
    downcased = String.downcase(name)

    if downcased in @downcased_attributes or prefixed?(downcased),
      do: :ok,
      else: {:error, "the #{name} attribute is not allowed in an icon"}
  end

  defp prefixed?("data-" <> rest), do: rest != ""
  defp prefixed?("aria-" <> rest), do: rest != ""
  defp prefixed?(_name), do: false

  defp unquote_value(quoted), do: binary_part(quoted, 1, byte_size(quoted) - 2)

  defp chop(binary, prefix), do: chop_at(binary, byte_size(prefix))

  defp skip_whitespace(<<char, rest::binary>>) when char in ~c" \t\r\n",
    do: skip_whitespace(rest)

  defp skip_whitespace(binary), do: binary

  defp take_text(binary) do
    case :binary.match(binary, "<") do
      {position, _length} -> split(binary, position)
      :nomatch -> {binary, ""}
    end
  end

  defp split(binary, position) do
    {binary_part(binary, 0, position),
     binary_part(binary, position, byte_size(binary) - position)}
  end

  # entities are resolved while parsing and re-added by escape_text/1
  defp decode("&" <> rest, acc) do
    with [match, reference] <- Regex.run(@entity_regex, rest),
         {:ok, character} <- character(reference) do
      decode(chop(rest, match), [character | acc])
    else
      _ -> {:error, "malformed entity reference"}
    end
  end

  defp decode(binary, acc) do
    case :binary.match(binary, "&") do
      {position, _length} ->
        {text, rest} = split(binary, position)
        decode(rest, [text | acc])

      :nomatch ->
        {:ok, IO.iodata_to_binary([Enum.reverse(acc), binary])}
    end
  end

  defp character("amp"), do: {:ok, "&"}
  defp character("lt"), do: {:ok, "<"}
  defp character("gt"), do: {:ok, ">"}
  defp character("quot"), do: {:ok, "\""}
  defp character("apos"), do: {:ok, "'"}
  defp character("#x" <> hex), do: codepoint(String.to_integer(hex, 16))
  defp character("#" <> decimal), do: codepoint(String.to_integer(decimal))

  # the characters XML allows; without the check, a reference to a surrogate
  # would raise instead of skipping the icon
  defp codepoint(number)
       when number in [0x9, 0xA, 0xD] or
              number in 0x20..0xD7FF or
              number in 0xE000..0xFFFD or
              number in 0x10000..0x10FFFF,
       do: {:ok, <<number::utf8>>}

  defp codepoint(_number), do: :error

  defp serialize({:text, text}), do: escape_text(text)

  defp serialize({name, attrs, nil}) do
    ["<", name, Enum.map(attrs, &serialize_attribute/1), " />"]
  end

  defp serialize({name, attrs, children}) do
    [
      "<",
      name,
      Enum.map(attrs, &serialize_attribute/1),
      ">",
      Enum.map(children, &serialize/1),
      "</",
      name,
      ">"
    ]
  end

  defp serialize_attribute({name, value}) do
    [" ", name, ~s(="), escape_attribute(value), ~s(")]
  end

  # in addition to XML escapes: `{` starts a HEEx expression, and three quotes
  # in a row end the heredoc the body is written into
  defp escape_text(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("{", "&lbrace;")
    |> String.replace("}", "&rbrace;")
  end

  def escape_attribute(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
