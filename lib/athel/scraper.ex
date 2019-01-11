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
    if Enum.empty?(groups) do
      Logger.warn "No common groups found at #{foreigner.hostname}:#{foreigner.port}"
      :ignore
    else
      message_id_index = find_message_id_index(session)
      Nntp.Client.quit(session)
      Logger.info "Found common groups #{inspect groups} at #{foreigner.hostname}:#{foreigner.port}"
      Process.send_after(self(), :run, 0)

      {:ok, %{groups: groups, message_id_index: message_id_index, foreigner: foreigner}}
    end
  end

  defp find_groups(session) do
    local_groups = Athel.Group |> Athel.Repo.all |> Enum.map(&(&1.name)) |> MapSet.new
    {:ok, foreign_group_resp} = Nntp.Client.list(session)
    foreign_groups = MapSet.new Enum.map(foreign_group_resp, fn line -> line |> String.split |> List.first end)
    MapSet.intersection(local_groups, foreign_groups)
  end

  defp find_message_id_index(session) do
    {:ok, format} = Nntp.Client.list(session, ["OVERVIEW.FMT"])
    # add one to skip leading listing number in XOVER
    Enum.find_index(format, &("Message-ID:" == &1)) + 1
  end

  @impl true
  def handle_info(:run, state) do
    {:ok, session} = Nntp.Client.connect(state.foreigner.hostname, state.foreigner.port)
    Enum.each state.groups, fn group -> scrape_articles(state, session, group) end

    # Process.send_after(self(), :run, state.foreigner.interval)
  end

  defp scrape_articles(state, session, group) do
    :ok = Nntp.Client.set_group(session, group)
    {:ok, overviews} = Nntp.Client.xover(session, 1)
    ids = extract_ids(overviews, state.message_id_index)
    id_set = MapSet.new ids
    existing_ids = Repo.all(
      from article in Article,
      select: article.message_id) |> MapSet.new
    new_ids = MapSet.difference(id_set, existing_ids)
    new_id_count = MapSet.size(new_ids)
    if new_id_count > 0 do
      Logger.info "Found #{new_id_count} new messages for group #{group}"
      Enum.each new_ids, fn id -> fetch_id(session, id) end
    end
  end

  defp extract_ids(overviews, message_id_index) do
    Enum.map(overviews, fn line ->
      raw_id = line
      |> String.splitter("\t")
      |> Enum.take(message_id_index + 1)
      |> Enum.at(message_id_index)
      # remove surrounding angle brackets
      String.slice(raw_id, 1, String.length(raw_id) - 2)
    end)
  end

  defp fetch_id(session, id) do
    Logger.debug fn -> "Taking article #{id}" end
    case Nntp.Client.get_article(session, id) do
      {:ok, {headers, body}} ->
        case NntpService.take_article(headers, body, true) do
          {:error, %Ecto.Changeset{:errors => errors}} -> Logger.error "Failed to take article #{id}: #{inspect errors}"
          {:error, reason} ->
            # Failed parse, can't recover
            Logger.error "Failed to parse article #{id}: #{inspect reason}"
            Nntp.Client.quit(session)
            throw {:stop, :bad_parse}
          _ -> Logger.info "Took article #{id}"
        end
      {:error, error} -> Logger.error "Failed to take article #{id}: #{inspect error}"
    end
  end
end
