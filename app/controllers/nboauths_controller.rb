class NboauthsController < ApplicationController

    def redirect_code
        site_path = 'https://acl.nationbuilder.com'
        redirect_uri = 'https://localhost:3000/nb_oauth_callback'
        client = Donation.get_client
        code = params[:code]
        begin
            Donation.save_access_token(code)
        rescue
            render json: {
                success: false
            }.to_json
        else
            render json: {
                success: true
            }.to_json
        end
    end
end
