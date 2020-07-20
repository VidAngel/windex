defmodule Windex.HTTP do
  require Record
  Record.defrecordp :httpd, Record.extract(:mod, from_lib: "inets/include/httpd.hrl")

  def unquote(:do)(req) do
    case httpd(req, :method) do
      'GET' -> do_get(req)
      'POST' -> do_post(req)
      _ -> {:break, response: {405, :httpd_util.reason_phrase(405)}}
    end
  end

  defp do_post(req) do
    form = req |> httpd(:entity_body) |> :httpd.parse_query |> Map.new
    command_index = form['command'] |> List.to_integer
    command = Windex.available_opts |> Enum.at(command_index)
    {port, password} = Windex.spawn_server(command)
    {:break, response: {200, Windex.HTTP.Template.vnc(port, password) |> String.to_charlist}}
  end

  defp do_get(req) do
    uri = httpd(req, :request_uri)
    cond do
      '/index.json' == uri -> {:break, response: Windex.HTTP.Template.index(:json)}
      is_root(uri) -> {:break, response: Windex.HTTP.Template.index(:html)}
      true -> {:proceed, httpd(req, :data)}
    end
  end

  defp is_root('/'), do: true
  defp is_root('/index'), do: true
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
      mime_types: [{'html','text/html'},{'htm','text/html'}, {'js', 'application/javascript'}],
    ]]
    %{id: __MODULE__,
      start: {:inets, :start, args},
    }
  end
end

defmodule Windex.HTTP.Template do
  require EEx

  def index(:json) do
    {nonce, commands} = index()
    index(nonce, commands) |> String.to_charlist
    json = Jason.encode!(%{nonce: nonce, commands: Enum.map(commands, &inspect/1)})
    {:response, [code: 200, content_type: 'application/json', content_length: "#{byte_size(json)}" |> String.to_charlist], json |> String.to_charlist}
  end

  def index(:html) do
    {nonce, commands} = index()
    {200, index(nonce, commands) |> String.to_charlist}
  end

  defp index() do
    nonce = Windex.HTTP.nonce()
    commands = Windex.available_opts()
    Task.start(fn ->
      Registry.register(Windex.OptionSets, nonce, commands)
      Process.sleep(1_000*60*15)
      Registry.unregister(Windex.OptionSets, nonce)
    end)
    {nonce, commands}
  end
  
  EEx.function_from_file(:defp, :index, "#{:code.priv_dir(:windex)}/index.eex", [:nonce, :commands])
  EEx.function_from_file(:def,  :vnc,   "#{:code.priv_dir(:windex)}/vnc.eex",  [:port, :password])
end
