defmodule Athel.Event.ModerationHandler do
  use GenStage

  alias Athel.{Article, Group}
  alias Athel.Event.NntpBroadcaster

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  @impl true
  def init(:ok) do
    {:consumer, :ok, subscribe_to: [{NntpBroadcaster, selector: &article_selector/1}]}
  end

  defp article_selector(%Article{groups: groups}) do
    case groups do
      [%Group{name: "ctl"}] -> true
      _ -> false
    end
  end

  @impl true
  def handle_events(events, _from, state) do
    for event <- events do
      IO.inspect(event)
    end

    {:noreply, [], state}
  end
end
