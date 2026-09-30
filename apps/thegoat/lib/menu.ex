defmodule Badge.App.Thegoat.Menu do
  @moduledoc """
  The menu the page starts in, and that Esc leaves the game for.

  Pure, like `Badge.App.Thegoat.GameOver`: `handle_key/2` says what a key does and `items/4`
  is the display list to draw, so it is checked on the laptop. The page owns the screen.

  Up and Down (or W and S) move, Enter or Space picks, Esc goes back to the first screen;
  on the first screen the page lets Esc go home. Being in the menu means being out of the
  game: the page leaves the relay's room when Esc opens it, and Play starts a new life in
  a room.

  Three entries: the game, the keys, and where the badge stands with wifi and the relay.
  """

  # The default font is 8 pixels to a character, and 16 high.
  @char 8
  @high 16

  @back 0x101820
  @band 0x24507A
  @title 0xFFFF00
  @text 0xFFFFFF
  @dim 0x9AA8B8
  @good 0x60E080

  # The widest entry, "> Controls", so the block of them sits in the middle.
  @entry_chars 10
  @rows [:play, :controls, :status]
  @first_y 84
  @pitch 32

  @doc "A menu on its first screen."
  def new, do: %{screen: :main, cursor: 0}

  @doc """
  What a key label does: `:play` when the game should be shown, otherwise `{:ok, menu}`
  with whatever changed. Keys it has no use for change nothing.
  """
  def handle_key(%{screen: :main} = menu, label) do
    cond do
      member?(label, ["Up", "W"]) ->
        {:ok, %{menu | cursor: rem(menu.cursor + length(@rows) - 1, length(@rows))}}

      member?(label, ["Down", "S"]) ->
        {:ok, %{menu | cursor: rem(menu.cursor + 1, length(@rows))}}

      member?(label, ["Enter", "Space"]) ->
        pick(menu, :lists.nth(menu.cursor + 1, @rows))

      true ->
        {:ok, menu}
    end
  end

  def handle_key(menu, label) do
    if member?(label, ["Esc", "Enter", "Space", "Left", "Bksp"]),
      do: {:ok, %{menu | screen: :main}},
      else: {:ok, menu}
  end

  # AtomVM has no Enum to speak of, so the lists here are :lists and plain recursion.
  defp member?(label, labels), do: :lists.member(label, labels)

  defp pick(_menu, :play), do: :play
  defp pick(menu, screen), do: {:ok, %{menu | screen: screen}}

  @doc """
  The display list. `info` is what the status screen says: `%{wifi: text, relay: text,
  badge: text}`, each already short enough for a line.
  """
  def items(menu, info, width, height),
    do: screen(menu, info, width, height) ++ [back(width, height)]

  defp screen(%{screen: :main} = menu, _info, width, height) do
    [text(width, 24, @title, "GOAT GAME")] ++
      rows(@rows, 0, menu, width) ++ [text(width, height - 24, @dim, "Up Down  Enter")]
  end

  defp screen(%{screen: :controls}, _info, width, height) do
    lines = [
      "Arrows or WASD  move, turn",
      "Q and E         strafe",
      "Esc             menu"
    ]

    [text(width, 24, @title, "CONTROLS")] ++
      lines(lines, 84, @text, width) ++ [text(width, height - 24, @dim, "Esc  back")]
  end

  defp screen(%{screen: :status}, info, width, height) do
    [text(width, 24, @title, "STATUS")] ++
      lines([info.wifi, info.relay, info.badge], 84, @text, width) ++
      [text(width, height - 24, @dim, "Esc  back")]
  end

  defp name(:play), do: "Play"
  defp name(:controls), do: "Controls"
  defp name(:status), do: "Status"

  # One entry a row, the selected one marked and with a band behind it.
  defp rows([], _index, _menu, _width), do: []

  defp rows([row | rest], index, menu, width) do
    y = @first_y + index * @pitch
    selected = index == menu.cursor
    label = if selected, do: "> " <> name(row), else: "  " <> name(row)
    colour = if selected, do: @text, else: @dim
    band = if selected, do: [band(width, y)], else: []

    [entry(width, y, colour, label)] ++ band ++ rows(rest, index + 1, menu, width)
  end

  # Left aligned lines, one under the other, in the middle of the screen.
  defp lines(lines, y, colour, width), do: lines(lines, y, colour, div(width - 34 * @char, 2), [])

  defp lines([], _y, _colour, _left, acc), do: :lists.reverse(acc)

  defp lines([line | rest], y, colour, left, acc) do
    item = {:text, left, y, :default16px, colour(line, colour), :transparent, clip(line)}
    lines(rest, y + @high + 8, colour, left, [item | acc])
  end

  # A line that says something good is green; the rest are plain.
  defp colour("Relay: online" <> _rest, _colour), do: @good
  defp colour(_line, colour), do: colour

  # Forty characters is the width of the screen.
  defp clip(line), do: binary_part(line, 0, min(byte_size(line), 34))

  defp text(width, y, colour, text) do
    x = div(width - byte_size(text) * @char, 2)
    {:text, x, y, :default16px, colour, :transparent, text}
  end

  # The entries share a left edge, so the marker is the only thing that moves.
  defp entry(width, y, colour, text),
    do: {:text, div(width - @entry_chars * @char, 2), y, :default16px, colour, :transparent, text}

  # Behind the selected entry, under its text.
  defp band(width, y), do: {:rect, div(width, 2) - 100, y - 4, 200, @high + 8, @band}

  defp back(width, height), do: {:rect, 0, 0, width, height, @back}
end
