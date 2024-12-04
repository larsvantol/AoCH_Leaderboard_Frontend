defmodule AoCH do
  @moduledoc """
  AoCH keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def get_raw_data() do
    ConCache.get_or_store(:cache, :raw_data, &request_raw_data/0)
  end

  def get_leaderboard_today() do
    now = now()
    day = if now.month < 12, do: 25, else: now.day

    data_per_member =
      get_raw_data()
      |> Map.get("members", [])
      |> Enum.map(fn {id, data} -> {id, extract_day_data(data, day)} end)
      |> Map.new()

    sort_by_first =
      Enum.sort_by(data_per_member, fn {_id, data} -> data[:unix_first_star] end)
      |> Enum.with_index()

    sort_by_second =
      Enum.sort_by(data_per_member, fn {_id, data} -> data[:unix_second_star] end)
      |> Enum.with_index()

    total = length(sort_by_first)

    data_per_member =
      Enum.reduce(sort_by_first, data_per_member, fn {{id, data}, index}, acc ->
        if data[:unix_first_star] do
          Map.update!(acc, id, fn data ->
            Map.update!(data, :score, &(total - index + &1))
          end)
        else
          acc
        end
      end)

    Enum.reduce(sort_by_second, data_per_member, fn {{id, data}, index}, acc ->
      if data[:unix_second_star] do
        Map.update!(acc, id, fn data ->
          Map.update!(data, :score, &(total - index + &1))
        end)
      else
        acc
      end
    end)
    |> Enum.map(fn {_id, data} -> data end)
    |> Enum.reject(&(&1[:score] == 0))
    |> Enum.sort_by(& &1[:score], :desc)
  end

  def now() do
    DateTime.utc_now() |> DateTime.shift_zone!("America/New_York")
  end

  def start_of_day(day) do
    now = now()

    %DateTime{
      now
      | month: 12,
        day: day,
        hour: 0,
        minute: 0,
        second: 0,
        microsecond: {0, 0}
    }
  end

  defp extract_day_data(data, day) do
    start_of_day = start_of_day(day) |> DateTime.to_unix()

    unix_time_first_star =
      data["completion_day_level"][Integer.to_string(day)]["1"]["get_star_ts"]

    unix_time_second_star =
      data["completion_day_level"][Integer.to_string(day)]["2"]["get_star_ts"]

    time_first_star =
      if unix_time_first_star do
        unix_time_first_star - start_of_day
      end

    time_second_star =
      if unix_time_second_star do
        unix_time_second_star - unix_time_first_star
      end

    %{
      name: data["name"],
      first_star: time_first_star,
      second_star: time_second_star,
      unix_first_star: unix_time_first_star,
      unix_second_star: unix_time_second_star,
      score: 0
    }
  end

  defp request_raw_data() do
    now = now()
    year = if now.month < 12, do: now.year - 1, else: now.year
    url = "https://adventofcode.com/#{year}/leaderboard/private/view/954860.json"

    {:ok, res} =
      Req.get(url,
        headers: [
          {"cookie", "session=#{Application.get_env(:aoch, :aoc_session_cookie)}"},
          {"User-Agent", "https://github.com/kaspervaessen/aoch, kasperv@ch.tudelft.nl"}
        ]
      )

    res.body
  end
end
