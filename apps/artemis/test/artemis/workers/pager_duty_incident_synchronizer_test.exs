defmodule Artemis.PagerDutyIncidentSynchronizerTest do
  use Artemis.DataCase

  import Artemis.Factories

  alias Artemis.Worker.PagerDutyIncidentSynchronizer

  describe "get_start_date" do
    test "returns a default date when no records exist" do
      result = PagerDutyIncidentSynchronizer.get_start_date(Mock.system_user())

      assert result.__struct__ == DateTime
    end

    test "returns the latest resolved incident if exists" do
      insert(:incident, status: "resolved", triggered_at: create_date("2020-03-10"))
      insert(:incident, status: "resolved", triggered_at: create_date("2020-04-10"))

      result = PagerDutyIncidentSynchronizer.get_start_date(Mock.system_user())

      # Shifted one second forward to exclude record in next sync

      assert result == Timex.shift(create_date("2020-04-10"), seconds: 1)
    end

    test "returns the earliest non-resolved incident if exists" do
      insert(:incident, status: "resolved", triggered_at: create_date("2020-03-10"))
      insert(:incident, status: "resolved", triggered_at: create_date("2020-04-10"))

      insert(:incident, status: "acknowledged", triggered_at: create_date("2020-01-10"))
      insert(:incident, status: "acknowledged", triggered_at: create_date("2020-02-10"))

      result = PagerDutyIncidentSynchronizer.get_start_date(Mock.system_user())

      # Shifted one second backward to include record in next sync

      assert result == Timex.shift(create_date("2020-01-10"), seconds: -1)
    end
  end

  # Helpers

  def create_date(date) do
    Timex.parse!("#{date}T00:00:00Z", "{ISO:Extended}")
  end
end
