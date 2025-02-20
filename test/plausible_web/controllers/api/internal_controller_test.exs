defmodule PlausibleWeb.Api.InternalControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test

  describe "GET /api/sites" do
    setup [:create_user, :log_in]

    test "returns a list of site domains for the current user", %{conn: conn, user: user} do
      site = new_site(owner: user)
      site2 = new_site(owner: user)
      conn = get(conn, "/api/sites")

      %{"data" => sites} = json_response(conn, 200)

      assert %{"domain" => site.domain} in sites
      assert %{"domain" => site2.domain} in sites
    end

    test "returns a list of max 9 site domains for the current user, putting pinned first", %{
      conn: conn,
      user: user
    } do
      inserted =
        for i <- 1..10 do
          i = to_string(i)
          new_site(owner: user, domain: "site#{String.pad_leading(i, 2, "0")}.example.com")
        end

      _rogue = new_site(domain: "site00.example.com")

      inviter = new_user()
      site = new_site(owner: inviter, domain: "friend.example.com")
      invite_guest(site, user, inviter: inviter, role: :viewer)
      invite_guest(List.first(inserted), user, inviter: inviter, role: :viewer)

      {:ok, _} =
        Plausible.Sites.toggle_pin(user, Plausible.Sites.get_by_domain!("site07.example.com"))

      {:ok, _} =
        Plausible.Sites.toggle_pin(user, Plausible.Sites.get_by_domain!("site05.example.com"))

      conn = get(conn, "/api/sites")

      %{"data" => sites} =
        json_response(conn, 200)

      assert Enum.count(sites) == 9

      assert [
               %{"domain" => "site05.example.com"},
               %{"domain" => "site07.example.com"},
               %{"domain" => "site01.example.com"} | _
             ] = sites

      assert %{"domain" => "site09.example.com"} in sites
      refute %{"domain" => "sites10.example.com"} in sites
    end
  end

  describe "GET /api/sites - user not logged in" do
    test "returns 401 unauthorized", %{conn: conn} do
      conn = get(conn, "/api/sites")

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in to request a list of sites"
             }
    end
  end

  describe "PUT /api/:domain/disable-feature" do
    setup [:create_user, :log_in]

    test "when the logged-in user is an admin of the site", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 200) == "ok"
      assert %{conversions_enabled: false} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "can disable conversions, funnels, and props with admin access", %{
      conn: conn,
      user: user
    } do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})
      put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "funnels"})
      put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "props"})

      assert %{conversions_enabled: false, funnels_enabled: false, props_enabled: false} =
               Plausible.Sites.get_by_domain(site.domain)
    end

    test "when the logged-in user is an owner of the site", %{conn: conn, user: user} do
      site = new_site(owner: user)
      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 200) == "ok"
      assert %{conversions_enabled: false} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "returns 401 when the logged-in user is a viewer of the site", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "returns 401 when the logged-in user doesn't have site access at all", %{conn: conn} do
      site = new_site()

      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end
  end

  describe "PUT /api/:domain/disable-feature - user not logged in" do
    test "returns 401 unauthorized", %{conn: conn} do
      site = insert(:site)

      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end
  end
end
