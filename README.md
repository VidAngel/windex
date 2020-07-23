# Windex

Elixir (and optional HTTP) API for ad hoc VNC servers.
Useful for viewing observer on a remote machine and
monitoring other GUI processes managed by Erlang/Elixir.

## Requirements

- Xvfb
- x11vnc
- (optional) xorg-twm

Make sure you have the latest version of rebar (`mix local.rebar`).

Add the Windex dependency to your mix.exs file

```elixir
defp deps do
  [
    {:windex, git: "git://github.com/vidangel/windex.git", tag: "0.1.0"},
  ]
end
```

## Usage

Use `Windex.spawn_server/1` to spawn Xvfb and x11vnc servers

Options:

```elixir
:port
:password
:run
:args
:display
:viewonly
```

Visit the displayed URL to select your application and connect over [NoVNC](https://github.com/novnc/noVNC)

Available commands can be retrieved from `/index.json`, and a server
can be spawned by submitting a querystring of `id=...` to `/run.json`,
which will return a password and port.

### Examples

```elixir
# start observer
{port, password} = Windex.spawn_server

# Start xeyes on an existing X server
{port, password} = Windex.spawn_server([run: "xeyes", display: ":0"])

# Display a non-interactive clock
{port, password} = Windex.spawn_server([run: "xclock", args: ["-digital", "-brief"], viewonly: true])

# Specify a predetermined port and password (limited to 8 characters)
Windex.spawn_server([password: "abcd1234", port: 5900])

# Or work with the VNC GenServer directly...
{:ok, pid} = Windex.VNC.start_link([run: "xterm"])
port = GenServer.call(pid, :get_port)
password = GenServer.call(pid, :get_password)
```

## Configuration

In your config.exs file:

```elixir
config :windex, [
  # VNC server ports will be randomly chosen from this range
  start_port: 49152,
  end_port: 65535,

  # how long the VNC client has to initiate a connection with the VNC server
  connection_timeout_seconds: 10,

  # HTTP options
  http_enabled: true,
  http_bind_address: '0.0.0.0',
  http_port: 0,
  hmac_key: "90F2455AC45591...",
  command_ttl_seconds: 10*60, # how long a user has to select a command
  # a module defining a `commands/0` method that returns a list of keyword lists
  # as would be passed to `Windex.spawn_server`.
  command_module: Windex.CommandList.Default,

]

  # example command_module
  defmodule MyOwnCommands do
    use Windex.CommandList

    @impl true
    def commands do
      [
        [run: :observer], # the :observer atom will connect to the current node
        [run: "xterm"],
        [display: ":1", viewonly: true]
      ]
    end
  end
```
