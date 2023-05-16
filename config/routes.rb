Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  get '/test', to: 'general#test'
  get '/gnaf', to: 'general#gnaf'
  post '/payment', to: 'general#securepay_payment'
  get '/getcampaigns', to: 'general#get_campaigns'
  post '/applepay/initiatesession', to: 'general#apple_pay_initiate_session'
  get '/nb_oauth_callback', to: 'nboauths#redirect_code'
end
