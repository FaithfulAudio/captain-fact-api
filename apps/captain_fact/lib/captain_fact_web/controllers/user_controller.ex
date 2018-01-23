defmodule CaptainFactWeb.UserController do
  use CaptainFactWeb, :controller

  alias DB.Schema.User

  alias CaptainFact.Accounts
  alias CaptainFact.Accounts.UserPermissions
  alias CaptainFactWeb.UserView


  action_fallback CaptainFactWeb.FallbackController

  plug Guardian.Plug.EnsureAuthenticated, [handler: CaptainFactWeb.AuthController]
  when action in [:update, :delete, :available_flags, :show_me]


  def create(conn, params = %{"user" => user_params}) do
    case Accounts.create_account(user_params, Map.get(params, "invitation_token")) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user, :token)
        conn
        |> put_status(:created)
        |> render("user_with_token.json", %{user: user, token: token})
      {:error, changeset = %Ecto.Changeset{}} ->
        conn
        |> put_status(:bad_request)
        |> render(CaptainFactWeb.ChangesetView, "error.json", changeset: changeset)
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render(CaptainFactWeb.ErrorView, "error.json", %{message: message})
    end
  end

  def show(conn, %{"username" => username}) do
    render(conn, "show_public.json", user: Repo.get_by!(User, username: username))
  end

  def show_me(conn, _params) do
    render(conn, UserView, :show, user: Guardian.Plug.current_resource(conn))
  end

  def update(conn, params) do
    Guardian.Plug.current_resource(conn)
    |> User.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        render(conn, :show, user: user)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(CaptainFactWeb.ChangesetView, :error, changeset: changeset)
    end
  end

  def available_flags(conn, _) do
    current_user = Guardian.Plug.current_resource(conn)
    case UserPermissions.check(current_user, :flag, :comment) do
      {:ok, num_available} -> json(conn, %{flags_available: num_available})
      {:error, _reason} ->
        json(conn, %{flags_available: 0})
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    try do
      Accounts.confirm_email!(token)
      send_resp(conn, :no_content, "")
    rescue
      _ -> json(put_status(conn, 404), %{error: "invalid_token"})
    end
  end

  def delete(conn, _params) do
    # TODO Soft delete, do the real delete after 1 week to avoid user mistakes
    Repo.delete!(Guardian.Plug.current_resource(conn))
    send_resp(conn, :no_content, "")
  end

  # ---- Reset password ----

  def reset_password_request(conn, %{"email" => email}) do
    try do
      Accounts.reset_password!(email, Enum.join(Tuple.to_list(conn.remote_ip), "."))
    rescue
      _ in Ecto.NoResultsError -> "I won't tell the user ;)'"
    end
    send_resp(conn, :no_content, "")
  end

  def reset_password_verify(conn, %{"token" => token}) do
    user = Accounts.check_reset_password_token!(token)
    render(conn, UserView, :show, %{user: user})
  end

  def reset_password_confirm(conn, %{"token" => token, "password" => password}) do
    user = Accounts.confirm_password_reset!(token, password)
    render(conn, UserView, :show, %{user: user})
  end

  # ---- Invitations ----

  def request_invitation(conn, %{"email" => email}) do
    case Accounts.request_invitation(email, Guardian.Plug.current_resource(conn)) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, "invalid_email"} ->
        put_status(conn, :bad_request)
        |> json(%{error: "invalid_email"})
      {:error, _} ->
        send_resp(conn, :bad_request, "")
    end
  end

  # ---- Newsletter ----

  def newsletter_unsubscribe(conn, %{"token" => token}) do
    case Repo.get_by(User, newsletter_subscription_token: token) do
      nil ->
        json(put_status(conn, :bad_request), %{error: "invalid_token"})
      user ->
        Repo.update Ecto.Changeset.change(user, newsletter: false)
        send_resp(conn, 204, "")
    end
  end
end