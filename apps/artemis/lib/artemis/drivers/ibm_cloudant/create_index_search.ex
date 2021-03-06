defmodule Artemis.Drivers.IBMCloudant.CreateIndexSearch do
  alias Artemis.Drivers.IBMCloudant

  @moduledoc """
  Enables full text search by adding search index to the database
  """

  @default_design_doc "text-search"
  @default_index "text-search-index"

  def call(schema, options \\ []) do
    cloudant_host = schema.get_cloudant_host()
    cloudant_path = schema.get_cloudant_path()
    search_fields = schema.search_fields()
    options = get_options(options)

    {:ok, document} = get_or_create_search_document(cloudant_host, cloudant_path, options)

    current_indexes = Map.get(document, "indexes", %{})
    current_index_key = Keyword.get(options, :index)
    current_search_function = Artemis.Helpers.deep_get(current_indexes, [current_index_key, "index"])
    search_function = generate_search_index(search_fields)

    case search_function == current_search_function do
      true -> {:ok, "Search index already exists"}
      false -> create_search_index(cloudant_host, cloudant_path, document, current_indexes, search_function, options)
    end
  end

  # Helpers

  defp get_options(options) do
    options
    |> Keyword.put_new(:design_doc, @default_design_doc)
    |> Keyword.put_new(:index, @default_index)
  end

  defp get_or_create_search_document(host, path, options) do
    case get_search_document(host, path, options) do
      {:error, %{"error" => "not_found"}} -> create_search_document(host, path, options)
      response -> response
    end
  end

  defp get_search_document(host, path, options) do
    IBMCloudant.Request.call(%{
      host: host,
      method: :get,
      path: "#{path}/_design/#{options[:design_doc]}"
    })
  end

  defp create_search_document(host, path, options) do
    {:ok, _} =
      IBMCloudant.Request.call(%{
        body: "{}",
        host: host,
        method: :put,
        path: "#{path}/_design/#{options[:design_doc]}"
      })

    get_search_document(host, path, options)
  end

  defp generate_search_index(fields) do
    fields_without_default = List.delete(fields, :_id)

    clauses =
      Enum.map(fields_without_default, fn field ->
        """
          if (typeof(doc.#{field}) !== 'undefined') {
            index("#{field}", doc.#{field});
          }
        """
      end)

    """
    function (doc) {
      // Warning
      //
      // Automatically generated by Dashboard Application
      // Changes will be overwritten

      index("default", doc._id);

      #{Enum.join(clauses, "\n")}
    }
    """
  end

  defp create_search_index(host, path, document, current_indexes, search_function, options) do
    search_index = Map.put(%{}, options[:index], %{"analyzer" => "standard", "index" => search_function})
    indexes = Map.merge(current_indexes, search_index)
    body = Map.put(document, "indexes", indexes)
    index_path = "#{path}/_design/#{options[:design_doc]}"

    IBMCloudant.Request.call(%{
      body: Jason.encode!(body),
      host: host,
      method: :put,
      path: index_path
    })
  end
end
