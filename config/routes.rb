Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      post "webhooks/crm", to: "webhooks#create"
      get "metrics", to: "metrics#show"
      resources :syncs, only: %i[index show] do
        collection { get :failed }
        member do
          get :events
          post :replay
        end
      end
    end
  end

  namespace :erp do
    namespace :v1 do
      resources :customers, param: :external_id, only: %i[create show update]
      resources :companies, param: :external_id, only: %i[create update]
    end
  end
end
