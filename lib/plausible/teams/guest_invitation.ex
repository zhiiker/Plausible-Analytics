defmodule Plausible.Teams.GuestInvitation do
  @moduledoc """
  Guest invitation schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "guest_invitations" do
    field :invitation_id, :string
    field :role, Ecto.Enum, values: [:viewer, :editor]

    belongs_to :site, Plausible.Site
    belongs_to :team_invitation, Plausible.Teams.Invitation

    timestamps()
  end

  def changeset(team_invitation, site, role) do
    %__MODULE__{invitation_id: Nanoid.generate()}
    |> cast(%{role: role}, [:role])
    |> validate_required(:role)
    |> put_assoc(:team_invitation, team_invitation)
    |> put_assoc(:site, site)
  end
end
