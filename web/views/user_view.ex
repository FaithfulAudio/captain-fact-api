defmodule CaptainFact.UserView do
  use CaptainFact.Web, :view

  alias CaptainFact.{UserView}

  def render("show.json", %{user: user, token: token}) do
    render_one(user, UserView, "user_token.json", token: token)
  end

  def render("show.json", %{user: user}) do
    render_one(user, CaptainFact.UserView, "user.json")
  end

  # TODO: Should only render email if it is current user !

  def render("user.json", %{user: user}) do
    %{id: user.id,
      email: user.email,
      name: user.name,
      username: user.username
    }
  end

  def render("user_token.json", %{user: user, token: token}) do
    %{id: user.id,
      email: user.email,
      name: user.name,
      username: user.username,
      token: token
    }
  end
end
