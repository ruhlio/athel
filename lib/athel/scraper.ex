defmodule Athel.Scraper do
  use GenServer
  require Logger
  import Ecto.Query

  alias Athel.{Nntp, NntpService, Repo, Article}

  def start_link(foreigner) do
    GenServer.start_link(__MODULE__, foreigner, [])
  end

  @impl true
  def init(foreigner) do
    {:ok, session} = Nntp.Client.connect(foreigner.hostname, foreigner.port)
    groups = find_groups(session)
    Nntp.Client.quit(session)
    # groups = MapSet.new ["gmane.discuss"]
    Logger.info "Found groups #{MapSet.to_list groups} at #{foreigner.hostname}:#{foreigner.port}"
    Process.send_after(self(), :run, 0)

    {:ok, %{groups: groups, foreigner: foreigner}}
  end

  defp find_groups(session) do
    local_groups = Athel.Group |> Athel.Repo.all |> Enum.map(&(&1.name)) |> MapSet.new
    {:ok, foreign_group_resp} = Nntp.Client.list_groups(session)
    foreign_groups = MapSet.new foreign_group_resp
    MapSet.intersection(local_groups, foreign_groups)
  end

  @impl true
  def handle_info(:run, state) do
    {:ok, session} = Nntp.Client.connect(state.foreigner.hostname, state.foreigner.port)
    Enum.each state.groups, fn group -> scrape_articles(session, group) end

    # Process.send_after(self(), :run, state.foreigner.interval)
  end

  defp scrape_articles(session, group) do
    :ok = Nntp.Client.set_group(session, group)
    {:ok, ids} = Nntp.Client.xover(session, 1)
    Logger.info "Got #{inspect(ids)}"
    id_set = MapSet.new ids
    existing_ids = MapSet.new Repo.all(
      from article in Article,
      select: article.message_id)
    new_ids = MapSet.difference(id_set, existing_ids)
    new_id_count = MapSet.size(new_ids)
    if new_id_count > 0 do
      Logger.info "Found #{new_id_count} new messages for group #{group}"
      Enum.each new_ids, fn id -> fetch_id(session, id) end
    end
  end

  defp fetch_id(session, id) do
    {:ok, {headers, body}} = Nntp.Client.get_article(session, id)
    case NntpService.take_article(headers, body) do
      {:error, changeset} -> Logger.error "Failed to take article #{id}: #{changeset}"
      _ -> Logger.info "Took article #{id}"
    end
  end
end
