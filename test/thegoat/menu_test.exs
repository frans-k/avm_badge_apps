defmodule Badge.App.Thegoat.MenuTest do
  use ExUnit.Case, async: true

  alias Badge.App.Thegoat.Menu

  @width 320
  @height 240
  @info %{
    wifi: "Wifi: connected",
    relay: "Relay: online, 3 playing",
    badge: "Badge: A0F262EE6F6C"
  }

  defp items(menu, info \\ @info), do: Menu.items(menu, info, @width, @height)

  defp texts(menu, info \\ @info) do
    for {:text, _x, _y, _font, _fg, _bg, text} <- items(menu, info), do: text
  end

  defp press(menu, labels),
    do: Enum.reduce(labels, menu, fn label, m -> elem(Menu.handle_key(m, label), 1) end)

  describe "the first screen" do
    test "offers the game, the controls and the status" do
      assert texts(Menu.new()) |> Enum.take(4) == [
               "GOAT GAME",
               "> Play",
               "  Controls",
               "  Status"
             ]
    end

    test "Up and Down (or W and S) move the cursor, and it wraps" do
      menu = Menu.new()
      assert press(menu, ["Down"]).cursor == 1
      assert press(menu, ["Down", "Down", "Down"]).cursor == 0
      assert press(menu, ["Up"]).cursor == 2
      assert press(menu, ["S", "S", "W"]).cursor == 1
    end

    test "Enter or Space on the game starts it" do
      assert Menu.handle_key(Menu.new(), "Enter") == :play
      assert Menu.handle_key(Menu.new(), "Space") == :play
    end

    test "Enter on the controls or the status opens that screen" do
      assert {:ok, %{screen: :controls}} =
               Menu.handle_key(press(Menu.new(), ["Down"]), "Enter")

      assert {:ok, %{screen: :status}} =
               Menu.handle_key(press(Menu.new(), ["Down", "Down"]), "Space")
    end

    test "Esc does nothing here: the menu is where a badge is when it is out of the game" do
      assert Menu.handle_key(Menu.new(), "Esc") == {:ok, Menu.new()}
    end

    test "keys it has no use for change nothing" do
      menu = Menu.new()

      for label <- ["Q", "Tab", "Fn", "1", "Left"],
          do: assert(Menu.handle_key(menu, label) == {:ok, menu})
    end
  end

  describe "the other screens" do
    test "the controls say how to move, and how to get back" do
      lines = texts(%{Menu.new() | screen: :controls})
      assert "CONTROLS" in lines
      assert Enum.any?(lines, &(&1 =~ "Arrows or WASD"))
      assert Enum.any?(lines, &(&1 =~ "Esc"))
    end

    test "the status shows what it is told, on one line each" do
      lines = texts(%{Menu.new() | screen: :status})
      assert "STATUS" in lines
      for line <- Map.values(@info), do: assert(line in lines)
    end

    test "a long line is cut to the screen, not drawn off it" do
      long = %{@info | wifi: "Wifi: " <> String.duplicate("x", 60)}
      shown = texts(%{Menu.new() | screen: :status}, long)
      assert Enum.all?(shown, &(byte_size(&1) <= 34))
    end

    test "Esc, Enter, Space or Left go back to the first screen, keeping the cursor" do
      menu = %{press(Menu.new(), ["Down", "Enter"]) | screen: :controls}
      assert menu.cursor == 1

      for label <- ["Esc", "Enter", "Space", "Left"] do
        assert {:ok, %{screen: :main, cursor: 1}} = Menu.handle_key(menu, label)
      end
    end

    test "Esc on a sub screen goes back even when a game is going, and does not resume it" do
      assert {:ok, %{screen: :main}} = Menu.handle_key(%{Menu.new() | screen: :status}, "Esc")
    end
  end

  describe "the display list" do
    test "has the background last, so everything else is drawn over it" do
      for screen <- [:main, :controls, :status] do
        assert {:rect, 0, 0, @width, @height, _colour} =
                 List.last(items(%{Menu.new() | screen: screen}))
      end
    end

    test "the selected entry has a band behind it, under its text" do
      list = items(Menu.new())
      text = Enum.find_index(list, &match?({:text, _, _, _, _, _, "> Play"}, &1))
      band = Enum.find_index(list, &match?({:rect, _, _, 200, _, _}, &1))
      assert text < band
    end

    test "every item is on the screen" do
      for screen <- [:main, :controls, :status] do
        for item <- items(%{Menu.new() | screen: screen}) do
          case item do
            {:text, x, y, _font, _fg, _bg, text} ->
              assert x >= 0 and x + byte_size(text) * 8 <= @width
              assert y >= 0 and y + 16 <= @height

            {:rect, x, y, w, h, _colour} ->
              assert x >= 0 and y >= 0 and x + w <= @width and y + h <= @height
          end
        end
      end
    end
  end
end
