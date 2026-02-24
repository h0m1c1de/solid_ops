# frozen_string_literal: true

SolidOps::Engine.routes.draw do
  root to: "events#index"
  resources :events, only: [:index, :show]
end
