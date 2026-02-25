# frozen_string_literal: true

Rails.application.routes.draw do
  mount SolidOps::Engine => "/solid_ops"
end
