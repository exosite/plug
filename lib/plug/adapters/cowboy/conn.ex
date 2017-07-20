defmodule Plug.Adapters.Cowboy.Conn do
  @behaviour Plug.Conn.Adapter
  @moduledoc false

  def conn(req) do
    path = :cowboy_req.path req
    host = :cowboy_req.host req
    port = :cowboy_req.port req
    meth = :cowboy_req.method req
    hdrs = :cowboy_req.headers req
    qs   = :cowboy_req.qs req
    peer = :cowboy_req.peer req
    {remote_ip, _} = peer

    req = Map.put(req, :plug_read_body, false)

    %Plug.Conn{
      adapter: {__MODULE__, req},
      host: host,
      method: meth,
      owner: self(),
      path_info: split_path(path),
      peer: peer,
      port: port,
      remote_ip: remote_ip,
      query_string: qs,
      req_headers: to_headers_list(hdrs),
      request_path: path,
      scheme: String.to_atom(:cowboy_req.scheme(req))
   }
  end

  def send_resp(req, status, headers, body) do
    headers = to_headers_map(headers)
    status = Integer.to_string(status) <> " " <> Plug.Conn.Status.reason_phrase(status)
    req = :cowboy_req.reply(status, headers, body, req)
    {:ok, nil, req}
  end

  def send_file(req, status, headers, path, offset, length) do
    %File.Stat{type: :regular, size: size} = File.stat!(path)

    length =
      cond do
        length == :all -> size
        is_integer(length) -> length
      end

    body = {:sendfile, offset, length, path}

    headers = to_headers_map(headers)
    req = :cowboy_req.reply(status, headers, body, req)
    {:ok, nil, req}
  end

  def send_chunked(req, status, headers) do
    headers = to_headers_map(headers)
    req = :cowboy_req.stream_reply(status, headers, req)
    {:ok, nil, req}
  end

  def chunk(req, body) do
    :cowboy_req.stream_body(body, :nofin, req)
  end

  def read_req_body(req, opts \\ %{})
  def read_req_body(req, opts) when is_list(opts) do
    read_req_body(req, Enum.into(opts, %{}))
  end
  def read_req_body(req = %{plug_read_body: false}, opts) when is_map(opts) do
    :cowboy_req.read_body(%{req | plug_read_body: true}, opts)
  end
  def read_req_body(req, _opts) do
    {:ok, "", req}
  end

  ## Helpers

  defp split_path(path) do
    segments = :binary.split(path, "/", [:global])
    for segment <- segments, segment != "", do: segment
  end

  defp to_headers_list(headers) when is_list(headers) do
    headers
  end

  defp to_headers_list(headers) when is_map(headers) do
    :maps.to_list(headers)
  end

  defp to_headers_map(headers) when is_list(headers) do
    :maps.from_list(headers)
  end

  defp to_headers_map(headers) when is_map(headers) do
    headers
  end

end
