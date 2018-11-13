defmodule Athel.Scraper do
  use GenServer
  require Logger
  alias Athel.Nntp

  def start_link(foreigner) do
    GenServer.start_link(__MODULE__, foreigner, [])
  end

  def init(foreigner) do
    {:ok, session} = Nntp.Client.connect(foreigner.hostname, foreigner.port)
    groups = find_groups(session)
    Nntp.Client.quit(session)
    Process.send_after(self(), :run, foreigner.interval)
    {:ok, %{groups: groups, foreigner: foreigner}}
  end

  def handle_info(:run, state) do
    scrape_articles(state.groups, state.foreigner)

    Process.send_after(self(), :run, state.foreigner.interval)
  end

  defp find_groups(session) do
    local_groups = Athel.Group |> Athel.Repo.all |> Enum.map(&(&1.name)) |> MapSet.new
    {:ok, foreign_group_resp} = session |> Nntp.Client.groups
    foreign_groups = MapSet.new foreign_group_resp
    matching_groups = MapSet.intersection(local_groups, foreign_groups)
    Logger.info fn -> "Found matching groups: #{MapSet.to_list matching_groups}" end
    matching_groups
  end

  defp scrape_articles(groups, foreigner) do
    
  end
end
