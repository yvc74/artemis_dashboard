defmodule Artemis.GetWikiRevision do
  import Ecto.Query

  alias Artemis.Repo
  alias Artemis.WikiRevision

  @default_preload [:user]

  def call!(value, _user, options \\ []) do
    get_record(value, options, &Repo.get_by!/2)
  end

  def call(value, _user, options \\ []) do
    get_record(value, options, &Repo.get_by/2)
  end

  defp get_record(value, options, get_by) when not is_list(value) do
    get_record([id: value], options, get_by)
  end

  defp get_record(value, options, get_by) do
    WikiRevision
    |> preload(^Keyword.get(options, :preload, @default_preload))
    |> get_by.(value)
  end
end
