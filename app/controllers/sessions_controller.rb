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
        @test_token = General.test_token
    end
end
