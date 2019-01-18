defmodule Athel.Scraper do
  use GenServer
  require Logger
  import Ecto.Query

  alias Athel.{Nntp, NntpService, Repo, Article}

  def start_link(foreigner = %Athel.Foreigner{}) do
    GenServer.start_link(__MODULE__, foreigner, [])
  end

  @impl true
  def init(foreigner) do
    {:ok, %{foreigner: foreigner, groups: [], message_id_index: nil}, {:continue, :initialize_session}}
  end

  @impl true
  def handle_continue(:initialize_session, state = %{foreigner: foreigner}) do
    {:ok, session} = connect(foreigner)
    groups = find_groups(session)
    if Enum.empty?(groups) do
      Nntp.Client.quit(session)
      Logger.warn "No common groups found at #{foreigner.hostname}:#{foreigner.port}"
      {:noreply, state}
    else
      message_id_index = find_message_id_index(session)
      Nntp.Client.quit(session)
      Logger.info "Found common groups #{inspect groups} at #{foreigner.hostname}:#{foreigner.port}"
      Process.send_after(self(), :run, 0)

      {:noreply, %{state | groups: groups, message_id_index: message_id_index}}
    end
  end

  defp find_groups(session) do
    local_groups = Athel.Group |> Athel.Repo.all |> Enum.map(&(&1.name)) |> MapSet.new
    {:ok, foreign_group_resp} = Nntp.Client.list(session)
    foreign_groups = foreign_group_resp
    |> Enum.map(fn line -> line |> String.split |> List.first end)
    |> MapSet.new()

    MapSet.intersection(local_groups, foreign_groups) |> MapSet.to_list()
  end

  defp find_message_id_index(session) do
    {:ok, format} = Nntp.Client.list(session, ["OVERVIEW.FMT"])
    # add one to skip leading listing number in XOVER
    Enum.find_index(format, &("Message-ID:" == &1)) + 1
  end

  @impl true
  def handle_info(:run, state = %{foreigner: foreigner,
                                  groups: groups,
                                  message_id_index: message_id_index}) do
    stream = Task.async_stream(groups, Athel.Scraper, :scrape_group, [foreigner, message_id_index],
      timeout: 120_000, on_timeout: :kill_task, ordered: false)
    Stream.run(stream)

    #Process.send_after(self(), :run, state.foreigner.interval + timeout)
    {:noreply, state}
  end

  @impl true
  def handle_info(type, _state) do
    Logger.info "Received: #{inspect type}"
  end

  def scrape_group(group, foreigner, message_id_index) do
    {:ok, session} = connect(foreigner)
    :ok = Nntp.Client.set_group(session, group)
    {:ok, overviews} = Nntp.Client.xover(session, 1)

    ids = extract_ids(overviews, message_id_index)
    id_set = MapSet.new(ids)
    existing_ids = Repo.all(
      from article in Article,
      select: article.message_id) |> MapSet.new
    new_ids = MapSet.difference(id_set, existing_ids) |> MapSet.to_list()
    Logger.info "Found #{length new_ids} new messages for group #{group}"
    fetch_ids(new_ids, session, group, foreigner)
  end

  defp fetch_ids([id | rest], session, group, foreigner) do
    case fetch_id(session, id) do
      true -> fetch_ids(rest, session, group, foreigner)
      false ->
        Nntp.Client.quit(session)
        {:ok, new_session} = connect(foreigner)
        :ok = Nntp.Client.set_group(new_session, group)
        fetch_ids(rest, new_session, group, foreigner)
    end
  end
  defp fetch_ids([], session, _, _) do
    Nntp.Client.quit(session)
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
    Logger.debug fn -> "Taking #{id}" end
    case Nntp.Client.get_article(session, id) do
      {:ok, {headers, body}} ->
        case NntpService.take_article(headers, body, true) do
          {:error, %Ecto.Changeset{:errors => errors}} ->
            Logger.warn "Failed to take #{id}: #{inspect errors}"
          {:error, reason} ->
            Logger.warn "Skipping #{id} due to #{inspect reason}"
          _ ->
            Logger.info "Took #{id}"
        end
        true
      {:error, {code, message}} when is_number(code) ->
        Logger.warn "Server rejected request for #{id}: #{message}"
        true
      {:error, reason} ->
        # Failed parse, can't recover
        Logger.error "Failed to parse #{id}: #{inspect reason}"
        false
    end
  end

  defp connect(foreigner) do
    Nntp.Client.connect(foreigner.hostname, foreigner.port)
  end
end
