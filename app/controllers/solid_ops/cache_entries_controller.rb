# frozen_string_literal: true

module SolidOps
  class CacheEntriesController < ApplicationController
    before_action :require_solid_cache!

    def index
      @total_entries = SolidCache::Entry.count
      @total_bytes = begin
        SolidCache::Entry.sum(:byte_size)
      rescue ActiveRecord::StatementInvalid
        nil
      end

      @entries = paginate(SolidCache::Entry.order(created_at: :desc))
    end

    def show
      @entry = SolidCache::Entry.find(params[:id])
    end

    def destroy
      entry = SolidCache::Entry.find(params[:id])
      key = entry.key
      entry.destroy
      redirect_to cache_entries_path, notice: "Cache key '#{key}' deleted."
    end

    def clear_all
      count = SolidCache::Entry.count
      loop do
        deleted = SolidCache::Entry.limit(1_000).delete_all
        break if deleted.zero?
      end
      redirect_to cache_entries_path, notice: "#{count} cache entries cleared."
    end
  end
end
