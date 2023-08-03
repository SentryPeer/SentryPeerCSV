defmodule SentrypeerCsv do
  NimbleCSV.define(SentryPeerParser, separator: ",", escape: "\"")
  use HTTPoison.Base

  @sentrypeer_token_url "https://authz.sentrypeer.com/oauth/token"
  @sentrypeer_api_url "https://sentrypeer.com/api/phone-numbers/"
  @sentrypeer_audience "https://sentrypeer.com/api"
  @ets_bucket :sentrypeer_access_token

  alias Jason

  @moduledoc """
  Documentation for `SentrypeerCsv`.
  """

  @doc """
  Parse a CSV file of Call Data Records (CDRs) and check each number against the SentryPeerHQ API.

  ## Examples

      iex> SentrypeerCsv.parse_csv("cdrs.csv")
      :world

  """
  def parse_csv(csv_file) do
    create_bucket_if_not_exists()

    csv_file
    |> File.stream!()
    |> SentryPeerParser.parse_stream()
    |> Stream.map(fn [
                       _tenant,
                       _caller_id,
                       number,
                       _datetime,
                       _duration,
                       _rating_duration,
                       _rating_cost,
                       _status
                     ] ->
      %{number: :binary.copy(number)}

      if String.length(number) != 4 do
        check_with_sentrypeer_api(%{number: number})
      end
    end)
    |> Stream.run()
  end

  defp normalise_number_to_uk(number) do
    if String.length(number) == 10 do
      "44" <> number
    else
      number
    end
  end

  defp create_bucket_if_not_exists do
    case :ets.info(@ets_bucket) do
      [
        id: _,
        decentralized_counters: false,
        read_concurrency: false,
        write_concurrency: false,
        compressed: false,
        memory: _,
        owner: _,
        heir: :none,
        name: :sentrypeer_access_token,
        size: _,
        node: _,
        named_table: true,
        type: :set,
        keypos: 1,
        protection: :public
      ] ->
        :ok

      :undefined ->
        create_bucket()
    end
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
      case HTTPoison.get(
             @sentrypeer_api_url <> number,
             headers(access_token),
             options()
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          IO.puts("Found: #{number}")
          body

        {:ok, %HTTPoison.Response{status_code: 404, headers: _headers}} ->
          # IO.puts("Ratelimit remaining: #{inspect(Enum.fetch!(headers, 9))}")
          IO.puts("Not found: #{number}")

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
      "client_id" =>
        System.get_env("SENTRYPEER_CLIENT_ID") ||
          raise("Missing env var SENTRYPEER_CLIENT_ID"),
      "client_secret" =>
        System.get_env("SENTRYPEER_CLIENT_SECRET") ||
          raise("Missing env var SENTRYPEER_CLIENT_SECRET"),
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
