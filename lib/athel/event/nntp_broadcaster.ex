defmodule Athel.Event.NntpBroadcaster do
  use GenStage

  # API

  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def new_article(article) do
    GenStage.cast(__MODULE__, {:new_article, article})
  end

  # Callbacks

  @impl true
  def init(:ok) do
    {:producer, :ok, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def handle_cast({:new_article, article}, state) do
    {:noreply, [article], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

end
