defmodule Windex.HTTP do
  require Record
  Record.defrecordp :httpd, Record.extract(:mod, from_lib: "inets/include/httpd.hrl")

  @hmac_key Application.get_env(:windex, :hmac_key, :crypto.strong_rand_bytes(32) |> Base.encode16)
  @command_ttl Application.get_env(:windex, :command_ttl_seconds, 10*60)

  def unquote(:do)(req) do
    case httpd(req, :method) do
      'GET' -> do_get(req)
      'POST' -> do_post(req)
      _ -> {:break, response: {405, :httpd_util.reason_phrase(405)}}
    end
  end

  defp do_post(req) do
    form = req |> httpd(:entity_body) |> :httpd.parse_query |> Map.new
    command = validate!(form['id'])
    {port, password} = Windex.spawn_server(command)
    case httpd(req, :request_uri) do
      '/run.json' ->
          json = Jason.encode!(%{port: port, password: password})
          response = [code: 200, content_type: 'application/json', content_length: "#{byte_size(json)}" |> String.to_charlist]
          {:break, response: {response, json |> String.to_charlist}}
      _ -> {:break, response: {200, Windex.HTTP.Template.vnc(port, password) |> String.to_charlist}}
    end
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

  def command_id(term) do
    encoded = term |> :erlang.term_to_binary |> Base.encode16
    creation = DateTime.utc_now |> DateTime.to_unix
    hmac = :crypto.hmac(:sha256, @hmac_key, "#{encoded}.#{creation}") |> Base.encode16
    "#{encoded}.#{creation}.#{hmac}"
  end

  def validate!(id) do
    IO.inspect(id)
    [term, creation, hmac] = "#{id}" |> String.split(".")
    IO.inspect(term)
    now = DateTime.utc_now |> DateTime.to_unix
    creation = creation |> String.to_integer
    true = (now - creation) < @command_ttl
    ^hmac = :crypto.hmac(:sha256, @hmac_key, "#{term}.#{creation}") |> Base.encode16
    term |> Base.decode16! |> :erlang.binary_to_term
  end
end

defmodule Windex.HTTP.Template do
  require EEx

  def index(:json) do
    json = Jason.encode!(commands())
    {:response, [code: 200, content_type: 'application/json', content_length: "#{byte_size(json)}" |> String.to_charlist], json |> String.to_charlist}
  end

  def index(:html) do
    {200, index(commands()) |> String.to_charlist}
  end

  defp commands() do
    IO.inspect(Windex.available_opts() |> Enum.map(fn cmd ->
      %{label: inspect(cmd), id: Windex.HTTP.command_id(cmd)}
    end))
  end
  
  EEx.function_from_file(:def, :index, "#{:code.priv_dir(:windex)}/index.eex", [:commands])
  EEx.function_from_file(:def,  :vnc,  "#{:code.priv_dir(:windex)}/vnc.eex",  [:port, :password])
end
