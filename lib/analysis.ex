defmodule Analysis do
  use GenServer

  @type item :: %{
          name: String.t(),
          symbol: String.t(),
          price: float(),
          timestamp: DateTime.t()
        }

  @type state :: %{
          id: atom(),
          items: %{first: item() | nil, last: item() | nil}
        }

  @spec start_link(%{id: atom()}) :: GenServer.on_start()
  def start_link(args) do
    id = Map.get(args, :id)
    init_state = Map.put(args, :items, %{})
    GenServer.start_link(__MODULE__, init_state, name: id)
  end

  @spec init(state()) :: {:ok, state()}
  def init(state) do
    path = get_path(state)

    items =
      File.read!(path)
      |> String.split("\n")
      |> Enum.map(&String.split(&1, ","))
      |> Enum.drop(1)
      |> Enum.filter(&(&1 != [""]))
      |> Enum.map(fn [name, symbol, price, timestamp] ->
        {:ok, t, _} = DateTime.from_iso8601(timestamp)

        %{
          name: name,
          symbol: symbol,
          price: String.to_float(price),
          timestamp: t
        }
      end)

    first = Enum.at(items, 0)
    last = Enum.at(items, -1)
    updated_state = Map.put(state, :items, %{first: first, last: last})
    {:ok, updated_state}
  end

  @spec handle_cast({:update, item()}, state()) :: {:noreply, state()}
  def handle_cast({:update, last}, state) do
    id = get_id(state)
    items = Map.get(state, :items)
    first = Map.get(items, :first)
    IO.puts("Coin: #{id} has variation: #{first.price - last.price}")

    updated_items = %{first: first, last: last}
    updated_state = Map.put(state, :items, updated_items)
    {:noreply, updated_state}
  end

  @spec get_id(state()) :: String.t()
  defp get_id(state) do
    Map.get(state, :id)
    |> Atom.to_string()
    |> String.replace("_analysis", "")
  end

  @spec get_path(state()) :: String.t()
  defp get_path(state) do
    id = get_id(state)
    "logs/" <> id <> "_log.txt"
  end
end
