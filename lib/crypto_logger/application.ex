defmodule CryptoLogger.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = get_children() ++ get_analysis() ++ get_loggers()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CryptoLogger.Supervisor]
    IO.puts("Starting CryptoLogger Application")
    Supervisor.start_link(children, opts)
  end

  defp get_children do
    coins = Coin.coins() |> Enum.map(&String.to_atom/1)

    Enum.map(coins, fn i ->
      Supervisor.child_spec({CryptoLogger, %{id: i, price: 0.0, timestamp: DateTime.utc_now()}},
        id: i
      )
    end)
  end

  defp get_analysis do
    coin_analysis = Coin.coins() |> Enum.map(fn coin -> String.to_atom(coin <> "_analysis") end)

    Enum.map(coin_analysis, fn i ->
      Supervisor.child_spec({Analysis, %{id: i}}, id: i)
    end)
  end

  defp get_loggers do
    coin_loggers = Coin.coins() |> Enum.map(fn coin -> String.to_atom(coin <> "_logger") end)

    Enum.map(coin_loggers, fn i ->
      Supervisor.child_spec({Log, %{id: i}}, id: i)
    end)
  end
end
