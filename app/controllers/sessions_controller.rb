class SessionsController < ApplicationController
    def new
        if logged_in?
            redirect_to root_url
        end
    end

    def create
        user = User.find_by(email: params[:session][:email].downcase)
        if !user.nil?
            if user.authenticate(params[:session][:password])
                log_in(user)
                redirect_to '/index'
            else
                flash[:danger] = "Failed to log in"
                redirect_to '/login'
            end
        else
            flash[:danger] = "Failed to log in"
            redirect_to '/login'
        end
    end

    def destroy
        if logged_in?
            log_out
            redirect_to root_url
        end
    end

    def index
        n = params[:n].nil? ? 10 : params[:n]
        @donations = Donation.last(n).reverse
    end

    def show_donation
        @donation = Donation.find_by(order_spid: params[:order_spid])
        if @donation.nil?
            flash[:danger] = "Donation not found."
            redirect_to '/index'
        end
        @test_token = General.test_token
    end

    def refresh_access_token
        if Digest::SHA256.base64digest(params[:token]) != "vg1aJVAe9FZfITG9YptD9LIh4VUa7YQcCocxlL9NUyY="
            render plain: {error: "Forbidden"}.to_json, status: 400
            return nil
        end
        General.refresh_access_token
        render json: {
            expires_at: General.find_by(name: "NB_EXPIRES_AT").value
        }.to_json
    end
end
