defmodule CaptainFact.SpeakerView do
  use CaptainFact.Web, :view

  def render("show.json", %{speaker: speaker}) do
    render_one(speaker, CaptainFact.SpeakerView, "speaker.json")
  end

  def render("speaker.json", %{speaker: speaker}) do
    %{
      id: speaker.id,
      full_name: speaker.full_name,
      title: speaker.title
    }
  end
end