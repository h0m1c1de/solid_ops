# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SolidOps::CacheEntriesController", type: :request do
  before do
    SolidOps.configure { |c| c.auth_check = nil }
    %i[@@_sq_available @@_sc_available @@_scb_available].each do |cv|
      SolidOps::ApplicationController.remove_class_variable(cv) if SolidOps::ApplicationController.class_variable_defined?(cv)
    end
  end

  let!(:entry) do
    SolidCache::Entry.create!(
      key: "views/products/index",
      value: "cached-html-content",
      byte_size: 256,
      created_at: Time.current
    )
  end

  describe "GET /solid_ops/cache" do
    it "lists cache entries with totals" do
      get "/solid_ops/cache"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("views/products/index")
    end

    context "with multiple entries" do
      it "renders all entries for client-side filtering" do
        SolidCache::Entry.create!(key: "views/users/show", value: "data", byte_size: 100, created_at: Time.current)
        get "/solid_ops/cache"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("products")
        expect(response.body).to include("users/show")
        expect(response.body).to include("data-solid-search")
      end
    end
  end

  describe "GET /solid_ops/cache/:id" do
    it "shows entry details" do
      get "/solid_ops/cache/#{entry.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("views/products/index")
    end
  end

  describe "DELETE /solid_ops/cache/:id" do
    it "deletes entry and redirects with notice" do
      delete "/solid_ops/cache/#{entry.id}"
      expect(response).to redirect_to("/solid_ops/cache")
      expect(flash[:notice]).to match(/deleted/)
      expect(SolidCache::Entry.exists?(entry.id)).to be false
    end
  end

  describe "POST /solid_ops/cache/clear_all" do
    it "clears all cache entries in batches and redirects" do
      3.times { |i| SolidCache::Entry.create!(key: "key_#{i}", value: "v", byte_size: 10, created_at: Time.current) }
      post "/solid_ops/cache/clear_all"
      expect(response).to redirect_to("/solid_ops/cache")
      expect(flash[:notice]).to match(/cache entries cleared/)
      expect(SolidCache::Entry.count).to eq(0)
    end
  end
end
