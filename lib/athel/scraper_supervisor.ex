defmodule Athel.ScraperSupervisor do
  use Supervisor

  import Supervisor.Spec

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    foreigners = Athel.Repo.all(Athel.Foreigner)
    children = Enum.map foreigners, fn foreigner ->
      worker(Athel.Scraper, [foreigner], id: foreigner.hostname)
    end

    Supervisor.init(children, strategy: :one_for_one)
  end


end
