class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:refresh_access_token]

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
        @start = nil
        @finish = nil
        if !params[:start].nil? && !params[:finish].nil?
            @start = Time.new(params[:start][0..3].to_i,params[:start][4..5].to_i,params[:start][6..7].to_i)
            @finish = Time.new(params[:finish][0..3].to_i,params[:finish][4..5].to_i,params[:finish][6..7].to_i)
            @donations = Donation.where(created_at: @start..(@finish+1.day))
            @load_more = false
        else
            n = params[:n].nil? ? 10 : params[:n]
            @donations = Donation.last(n).reverse
            @load_more = true
        end
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

    def test_pdf
        #html = "<h1>Hey!</h1><p>Here is a test</p>"
        #kit = PDFKit.new(html, :page_size => 'Letter')
        #send_data(kit.to_pdf, filename: SecureRandom.alphanumeric+'.pdf', type: 'application/pdf')
        pdf = Prawn::Document.new(page_size: 'A4')
        phtml = Prawn::Document.new(page_size: 'A4')
        render json: {
            success: true
        }.to_json
    end
end
