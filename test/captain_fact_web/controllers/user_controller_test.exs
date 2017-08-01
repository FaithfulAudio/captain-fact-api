defmodule CaptainFactWeb.UserControllerTest do
  use CaptainFactWeb.ConnCase
  import CaptainFact.Factory

  alias CaptainFact.Accounts.User

  describe "GET /api/users/:username" do
    test "displays sensitive info (email...) when requesting /me" do
      user = insert(:user)
      returned_user =
        build_authenticated_conn(user)
        |> get("/api/users/me")
        |> json_response(:ok)

      assert Map.has_key?(returned_user, "email")
    end

    test "displays limited info if someone else" do
      requesting_user = insert(:user)
      requested_user = insert(:user)
      returned_user =
        build_authenticated_conn(requesting_user)
        |> get("/api/users/#{requested_user.username}")
        |> json_response(:ok)

      refute Map.has_key?(returned_user, "email")
    end
  end

  describe "create account" do
    test "must work if joined a valid invitation" do
      invit = insert(:invitation_request)
      user =
        build(:user)
        |> Map.take([:email, :username])
        |> Map.put(:password, "dsad888-!")

      response =
        build_conn()
        |> post("/api/users", %{user: user, invitation_token: invit.token})
        |> json_response(:created)

      Guardian.decode_and_verify!(response["token"])
    end

    test "must not work without an invitation" do
      user =
        build(:user)
        |> Map.take([:email, :username])
        |> Map.put(:password, "dsad888-!")

      response =
        build_conn()
        |> post("/api/users", %{user: user})
        |> json_response(:bad_request)

      assert response == %{"error" => "invalid_invitation_token"}
    end
  end

  test "confirm email" do
    user = insert(:user)
    refute user.email_confirmed

    build_authenticated_conn(user)
    |> put("/api/users/me/confirm_email/#{user.email_confirmation_token}")
    |> response(:no_content)

    assert Repo.get(User, user.id).email_confirmed
  end

  test "GET /api/users/me/available_flags" do
    user = build(:user) |> Map.put(:reputation, 4200) |> insert()
    available =
      build_authenticated_conn(user)
      |> get("/api/users/me/available_flags")
      |> json_response(:ok)
      |> Map.get("flags_available")

    assert is_number(available) and available > 0
  end

  test "must be authenticated to update, delete, admin_logout, confirm_email and available_flags" do
    response(get(build_conn(), "/api/users/me"), 401) =~ "unauthorized"
    response(put(build_conn(), "/api/users/me"), 401) =~ "unauthorized"
    response(put(build_conn(), "/api/users/me/confirm_email/xxx"), 401) =~ "unauthorized"
    response(get(build_conn(), "/api/users/me/available_flags"), 401) =~ "unauthorized"
    response(delete(build_conn(), "/api/users/me"), 401) =~ "unauthorized"
    response(delete(build_conn(), "/jouge42/logout"), 401) =~ "unauthorized"
  end
end