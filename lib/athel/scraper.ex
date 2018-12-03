defmodule Athel.Scraper do
  use GenServer
  import Ecto.Query
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
    {:ok, session} = Nntp.Client.connect(state.foreigner.hostname, state.foreigner.port)
    Enum.each state.groups, fn group -> scrape_articles(session, group) end

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

  defp scrape_articles(session, group) do
    :ok = Nntp.Client.set_group(session, group)
    {:ok, ids} = Nntp.Client.xover(session)
    id_set = MapSet.new ids
    existing_ids = MapSet.new Repo.all(
      from article in Article,
      select: article.id)
    new_ids = MapSet.difference(id_set, existing_ids)
    new_id_count = MapSet.size(new_ids)
    if new_id_count > 0 do
      Logger.info fn -> "Found #{new_id_count} new messages for group #{group}" end
      Enum.each new_ids, fn id -> fetch_id(session, id) end
    end
  end

  defp fetch_id(session, id) do
    {:ok, {headers, body}} = Nntp.Client.get_article(session, id)
    case NntpService.take_article(headers, body) do
      {:error, changeset} -> Logger.error "Failed to take article #{id}: #{changeset}"
      ok -> Logger.info fn -> "Took article #{id}" end
    end
  end
end
