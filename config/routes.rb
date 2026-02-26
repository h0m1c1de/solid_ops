# frozen_string_literal: true

SolidOps::Engine.routes.draw do
  root to: "dashboard#index"
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dashboard/jobs", to: "dashboard#jobs", as: :dashboard_jobs
  get "dashboard/cache", to: "dashboard#cache", as: :dashboard_cache
  get "dashboard/cable", to: "dashboard#cable", as: :dashboard_cable

  # Queue management (Solid Queue)
  resources :queues, only: %i[index show] do
    member do
      post :pause
      post :resume
    end
  end
  resources :jobs, only: %i[show destroy] do
    member do
      post :retry
      post :discard
    end
    collection do
      get :running
      get :failed
      post :retry_all
      post :discard_all
      post :clear_finished
    end
  end
  resources :recurring_tasks, only: [:index], path: "recurring-tasks"
  resources :processes, only: [:index]

  # Cache management (Solid Cache)
  resources :cache_entries, only: %i[index show destroy], path: "cache" do
    collection do
      post :clear_all
    end
  end

  # Cable management (Solid Cable)
  resources :channels, only: %i[index show] do
    collection do
      post :trim
    end
  end

  # Event explorer
  resources :events, only: %i[index show]
end
