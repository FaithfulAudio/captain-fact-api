defmodule CaptainFactWeb.UserController do
  use CaptainFactWeb, :controller

  alias CaptainFact.SendInBlueApi
  alias CaptainFactWeb.User

  plug Guardian.Plug.EnsureAuthenticated, [handler: CaptainFactWeb.AuthController]
  when action in [:update, :delete, :admin_logout, :available_flags, :show_me]


  def create(conn, user_params) do
    changeset = User.changeset(%User{}, user_params)

    case Repo.insert(changeset) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user, :token)
        conn
        |> put_status(:created)
        |> render("user_with_token.json", %{user: user, token: token})
      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> render(CaptainFactWeb.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"username" => username}) do
    render(conn, "show_public.json", user: Repo.get_by!(User, username: username))
  end

  def show_me(conn, _params) do
    render(conn, "show.json", user: Guardian.Plug.current_resource(conn))
  end

  def admin_login(conn, _) do
    render(conn, "admin_login.html")
  end

  def admin_logout(conn, _) do
    conn
      |> Guardian.Plug.current_token
      |> Guardian.revoke!
    conn
      |> Plug.Conn.configure_session(drop: true)
      |> redirect(to: "/admin/login")
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
    case CaptainFact.UserPermissions.check(current_user, :flag_comment) do
      {:ok, num_available} -> json(conn, %{flags_available: num_available})
      {:error, _reason} ->
        json(conn, %{flags_available: 0})
    end
  end

  def newsletter_subscribe(conn, %{"email" => email}) do
    case Regex.match?(~r/@/, email) do
      false -> render_invalid_email_error(conn)
      true -> case ForbiddenEmailProviders.is_forbidden(email) do
        true -> render_invalid_email_error(conn)
        false ->
          %SendInBlueApi.User{email: email}
          |> SendInBlueApi.User.create_or_update()
          |> case do
            {:ok, _} -> send_resp(conn, 200, "")
            {:error, _} -> render_invalid_email_error(conn)
          end
      end
    end
  end

  def delete(conn, _params) do
    # TODO Soft delete, do the real delete after 1 week to avaoid user mistakes
    Repo.delete!(Guardian.Plug.current_resource(conn))
    send_resp(conn, :no_content, "")
  end

  defp render_invalid_email_error(conn) do
    conn |> put_status(400) |> json(%{error: "invalid_email"})
  end
end
