# Windex

Elixir API for ad hoc VNC servers.
Useful for viewing observer on a remote machine and
monitoring other GUI processes managed by Erlang/Elixir.

HTTP plug at https://github.com/VidAngel/windex_plug

## Requirements

- Xvfb
- x11vnc
- (optional) xorg-twm

Make sure you have the latest version of rebar (`mix local.rebar`).

Add the Windex dependency to your mix.exs file

```elixir
defp deps do
  [
    {:windex, git: "git@github.com:VidAngel/windex.git", tag: "0.3.7"},
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

### Examples

```elixir
# start observer
{port, password} = Windex.spawn_server

# start observer for separate node (note that the run: value is an atom when spawning the observer!)
{port, password} = Windex.spawn_server(run: :observer, args: ["nodename@nodehost", "cookie"])

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
]
```
