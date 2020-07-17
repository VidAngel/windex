defmodule Windex.HTTP do
  require Record
  Record.defrecordp :httpd, Record.extract(:mod, from_lib: "inets/include/httpd.hrl")

  def unquote(:do)(req) do
    case httpd(req, :method) do
      'GET' -> do_get(req)
      'POST' -> do_post(req)
      _ -> {:proceed, response: {405, :httpd_util.reason_phrase(405)}}
    end
  end

  defp do_post(req) do
    form = req |> httpd(:entity_body) |> :httpd.parse_query |> Map.new
    command_index = form['command'] |> List.to_integer
    command = Windex.available_opts |> Enum.at(command_index)
    {port, password} = Windex.spawn_server(command)
    {:proceed, response: {200, Windex.HTTP.Template.vnc(port, password) |> String.to_charlist}}
  end

  defp do_get(req) do
    cond do
      is_root(httpd(req, :request_uri)) -> {:proceed, response: {200, Windex.HTTP.Template.index()}}
      true -> {:proceed, response: {404, ''}}
    end
  end

  defp is_root('/'), do: true
  defp is_root('/index.html'), do: true
  defp is_root(_), do: false

  def nonce(), do: :crypto.strong_rand_bytes(10) |> Base.encode16

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

  def index() do
    nonce = Windex.HTTP.nonce()
    commands = Windex.available_opts()
    index(nonce, commands) |> String.to_charlist
  end
  
  EEx.function_from_file(:defp, :index, "#{:code.priv_dir(:windex)}/index.eex", [:nonce, :commands])
  EEx.function_from_file(:def,  :vnc,   "#{:code.priv_dir(:windex)}/vnc.eex",  [:port, :password])
end
