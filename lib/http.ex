defmodule Windex.HTTP do
  require Record
  Record.defrecordp :httpd, Record.extract(:mod, from_lib: "inets/include/httpd.hrl")

  def unquote(:do)(req) do
    case httpd(req, :method) do
      'GET' -> do_get(req)
      'POST' -> do_post(req)
      _ -> {:proceed, response: {405, ''}}
    end
  end

  defp do_post(req) do
  end

  defp do_get(req) do
    cond do
      is_root(httpd(req, :request_uri)) -> {:proceed, response: {200, Windex.HTTP.Template.index() |> String.to_charlist}}
      true -> {:proceed, response: {404, ''}}
    end
  end

  defp is_root('/'), do: true
  defp is_root('/index.html'), do: true
  defp is_root(_), do: false

  def child_spec(_ignored_opts \\ []) do
    root = "#{:code.priv_dir(:windex)}/public" |> String.to_charlist
    args = [:httpd,[
      server_name:   'WINDEX',
      server_root:   root,
      document_root: root,
      bind_address: Application.get_env(:windex, :http_bind_address, Mix.env() == :prod && '0.0.0.0' || '127.0.0.1'),
      port: Application.get_env(:windex, :http_port, 0),
      modules: [:mod_get, __MODULE__],
      mime_types: [{'js', 'application/javascript'}],
    ]]
    %{id: __MODULE__,
      start: {:inets, :start, args},
    }
  end
end

defmodule Windex.HTTP.Template do
  require EEx
  
  EEx.function_from_file(:def, :index, "#{:code.priv_dir(:windex)}/index.eex", [])
end
