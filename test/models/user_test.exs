defmodule CaptainFact.UserTest do
  use CaptainFact.ModelCase, async: true

  alias CaptainFact.User

  @valid_attrs %{
    name: "#{Faker.Name.first_name} #{Faker.Name.last_name}",
    username: Faker.Internet.user_name,
    email: Faker.Internet.email,
    password: "@StrongP4ssword!"
  }
  @invalid_attrs %{}

  test "registration changeset with valid attributes" do
    changeset = User.registration_changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "registration changeset with invalid attributes" do
    changeset = User.registration_changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "username should be between 3 and 20 characters" do
    # Too short
    attrs = %{username: "x"}
    assert {:username, "should be at least 3 character(s)"} in errors_on(%User{}, attrs)

    # Too long
    attrs = %{username: String.duplicate("x", 21)}
    assert {:username, "should be at most 20 character(s)"} in errors_on(%User{}, attrs)
  end

  test "name must be between 2 and 30 characters" do
    # Too short
    attrs = %{name: "x"}
    assert {:name, "should be at least 2 character(s)"} in errors_on(%User{}, attrs)

    # Too long
    attrs = %{name: String.duplicate("x", 31)}
    assert {:name, "should be at most 30 character(s)"} in errors_on(%User{}, attrs)
  end

  test "password must be between 6 and 256 characters" do
    # Too short
    attrs = %{password: "x"}
    assert {:password, "should be at least 6 character(s)"} in errors_on(%User{}, attrs)

    # Too long
    attrs = %{password: String.duplicate("x", 257)}
    assert {:password, "should be at most 256 character(s)"} in errors_on(%User{}, attrs)
  end

  test "email must be a valid address" do
    changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :email, "INVALID EMAIL"))
    refute changeset.valid?
  end

  test "email must not be a temporary email (yopmail, jetable.org...etc)" do
    provider = Enum.random(ForbiddenEmailProviders.get_temporary_providers)
    attrs = %{email: "#{Faker.Internet.user_name}@#{provider}"}
    assert {:email, "this email provider is forbidden"} in errors_on(%User{}, attrs)
  end
end
