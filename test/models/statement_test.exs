defmodule CaptainFact.StatementTest do
  use CaptainFact.ModelCase, async: true

  alias CaptainFact.Statement

  @valid_attrs %{
    text: Faker.Lorem.sentence(%Range{first: 1, last: 10}),
    time: 42,
    speaker_id: 3,
    video_id: 2
  }
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Statement.changeset(%Statement{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Statement.changeset(%Statement{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "time cannot be negative" do
    attrs = Map.put(@valid_attrs, :time, -1)
    changeset = Statement.changeset(%Statement{}, attrs)
    refute changeset.valid?
  end

  test "text cannot be empty" do
    assert {:text, "can't be blank"} in errors_on(%Statement{}, %{text: ""})
  end
end
