defmodule SentrypeerCsv do
  NimbleCSV.define(SentryPeerParser, separator: "\t", escape: "\"")
  use HTTPoison.Base

  @sentrypeer_token_url "https://authz.sentrypeer.com/oauth/token"
  @sentrypeer_api_url "http://127.0.0.1:4000/api/phone-numbers/"
  @sentrypeer_client_id System.get_env("SENTRYPEER_CLIENT_ID") ||
                          raise("Missing env var SENTRYPEER_CLIENT_ID")
  @sentrypeer_client_secret System.get_env("SENTRYPEER_CLIENT_SECRET") ||
                              raise("Missing env var SENTRYPEER_CLIENT_SECRET")
  @sentrypeer_audience "https://sentrypeer.com/api"
  @ets_bucket :sentrypeer_access_token

  alias Jason

  @moduledoc """
  Documentation for `SentrypeerCsv`.
  """

  @doc """
  Parse a CSV file and search for matches in the SentryPeer database.

  ## Examples

      iex> SentrypeerCsv.hello()
      :world

  """
  def parse_csv(csv_file) do
    create_bucket()

    csv_file
    |> File.stream!()
    |> SentryPeerParser.parse_stream()
    |> Stream.map(fn [
                       _area,
                       number,
                       _call_date,
                       _total_duration,
                       _talk_time,
                       _not_used,
                       _call_state
                     ] ->
      %{number: :binary.copy(number)}
      check_with_sentrypeer_api(%{number: number})
    end)
    |> Stream.run()
  end

  defp create_bucket do
    case :ets.new(@ets_bucket, [:set, :public, :named_table]) do
      @ets_bucket -> :ok
      {:error, {:already_exists, _}} -> :ok
      {:error, reason} -> raise(reason)
    end
  end

  defp set_access_token_in_bucket(access_token) do
    :ets.insert(@ets_bucket, {:access_token, access_token})
  end

  defp get_access_token_from_bucket do
    case :ets.lookup(@ets_bucket, :access_token) do
      [{:access_token, access_token}] -> access_token
      [] -> nil
    end
  end

  defp check_with_sentrypeer_api(%{number: number}) do
    with {:ok, access_token} <- get_auth_token() do
      #      IO.puts("Checking #{number}")

      case HTTPoison.get(
             @sentrypeer_api_url <> number,
             headers(access_token),
             options()
           ) do
        {:ok, %HTTPoison.Response{status_code: 302, body: body}} ->
          IO.puts("Found: #{number}")
          body

        {:ok, %HTTPoison.Response{status_code: 404, headers: headers}} ->
          IO.puts("Ratelimit remaining: #{inspect(Enum.fetch!(headers, 2))}")

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          IO.puts("Error: #{status_code} #{body}")
          body

        {:error, %{reason: reason}} ->
          IO.puts("Error: #{reason}")
          reason
      end
    end
  end

  defp get_auth_token do
    case get_access_token_from_bucket() do
      nil ->
        case get_remote_auth_token() do
          {:ok, access_token} ->
            set_access_token_in_bucket(access_token)
            {:ok, access_token}

          {:error, reason} ->
            {:error, reason}
        end

      access_token ->
        {:ok, access_token}
    end
  end

  defp get_remote_auth_token do
    IO.puts("Getting auth token...")

    case HTTPoison.post(
           @sentrypeer_token_url,
           auth_token_json(),
           json_content_type(),
           options()
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)["access_token"]}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Auth0 returned status code #{status_code} with body #{body}"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp auth_token_json do
    Jason.encode!(%{
      "client_id" => @sentrypeer_client_id,
      "client_secret" => @sentrypeer_client_secret,
      "audience" => @sentrypeer_audience,
      "grant_type" => "client_credentials"
    })
  end

  defp json_content_type do
    [{"Content-Type", "application/json"}]
  end

  defp headers(access_token) do
    [
      Authorization: "Bearer #{access_token}",
      Accept: "application/json; Charset=utf-8",
      "Content-Type": "application/json"
    ]
  end

  defp options do
    [ssl: [{:versions, [:"tlsv1.2"]}], recv_timeout: 2000]
  end
end