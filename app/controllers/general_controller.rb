class GeneralController < ApplicationController
    skip_forgery_protection

    def test
        render json: {
            success: true
        }.to_json
    end

    def gnaf
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{params[:address]}",
            :headers => {"Authorization"=>ENV['GNAF_API_KEY']})
        puts response
        render json: response.to_json
    end

    def apple_pay_initiate_session
        response = HTTParty.post("https://preview.wem.io/38864/webservices/securepay/applePayInitiateSession",
            :body=>{"Requestor IP Address"=>request.remote_ip}.to_json,
            :headers=>{
                'Content-Type'=>'application/json'
            })
        render json: {
            response: response['Apple Pay Initiate Session Output']
        }.to_json
    end

    def apple_pay_wem_payment
    end

    def securepay_payment
        # 0. Check if it violates election law
        if params[:election_related] && (Donation.election_donations_email_sum(params[:email], params[:tracking_code], 9.months.ago) + params[:amount] > params[:election_total_donation_limit]*100 || params[:amount] > params[:election_single_donation_limit]*100)
            render json: {
                success: false,
                acl_error_code: 811,
                errors: ["Election law violation: can only have a maximum AUD #{params[:election_single_donation_limit]} donation for a single donation and AUD #{params[:election_total_donation_limit]} total donations for an election cycle."]
            }.to_json, status: 401
            return nil
        end
        # 1. Make the payment
        donation = Donation.make_payment(params[:amount].to_i, params[:token], request.remote_ip)
        if !donation.success
            render json: {
                success: false,
                acl_error_code: 801,
                errors: ["SecurePay error received - #{donation.gateway_response_code}: #{Donation.response_code_message(donation.gateway_response_code)}"]
            }.to_json, status: 401
            return nil
        end
        donation.fill_out_params(params)
        # 2. Make the recurring schedule (if applicable)
        recurring = nil
        if params[:recurring]
            begin
                recurring = Recurring.make_recurring_payment(params[:amount].to_i, params[:token], request.remote_ip)
            rescue
                render json: {
                    success: false,
                    acl_error_code: 802,
                    errors: ["Could not successfully execute recurring payment. Singular payment successful."]
                }.to_json, status: 401
                return nil
            end
        end
        # 3. Handle external errors
        save_failure = donation.id.nil? || (!recurring.nil? && recurring.id.nil?)
        wem_failure = false # will change as time goes on
        nb_failure = false # will change as time goes on
        # 3a. Make the calls
        
        if save_failure || wem_failure || nb_failure
            render json: {
                success: false,
                acl_error_code: General.failure_error_code(nb_failure, wem_failure, save_failure),
                errors: [nb_failure ? "Could not save to NationBuilder." : nil, wem_failure ? "Could not save to WEM." : nil, save_failure ? "Could not save to CORS database." : nil].compact
            }.to_json, status: 401
            return nil
        end
        # 4. Return success
        if params[:recurring]
            render json: {
                success: true,
                amount_in_cents: donation.amount_in_cents,
                orderId: donation.order_spid,
                scheduleId: recurring.schedule_spid,
                customerId: recurring.customer_code
            }.to_json, status: 201
        else
            render json: {
                success: true,
                orderId: donation.order_spid,
                amount_in_cents: donation.amount_in_cents
            }.to_json, status: 201
        end
    end

    def wem_payment
        response = HTTParty.post(params[:tgt_url],
            :body => params[:tgt_body].to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        #HTTParty.post("https://acl.nationbuilder.com/api/v2/donations")
        if response["Secure Pay Success"]
            nb_resp = HTTParty.post("https://acl.nationbuilder.com/api/v2/donations",:body => {
                "data"=> {
                    "type" => "donations",
                    "attributes" => {
                        "amount_in_cents"=>params[:tgt_body]["SecurePay Amount".to_sym]*100,
                        "email"=>params[:tgt_body]["SecurePay Email".to_sym],
                        "first_name"=>params[:tgt_body]["SecurePay Firstname".to_sym],
                        "last_name"=>params[:tgt_body]["SecurePay Lastname".to_sym],
                        "payment_type_id"=>"1",
                        "tracking_code_id"=>params[:tgt_body]["Nation Builder Tracking ID".to_sym]
                    }
                }
            }.to_json, :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json',
                'Authorization'=>ENV['NB_TEST_TOKEN']
            })
            render json: {
                success: true,
                response: response,
                nb_resp: nb_resp
            }.to_json
        else
            render json: {
                success: false,
                response: response
            }.to_json
        end
        #nb_resp = JSON.parse(response["NB Donation Response"])
        #puts nb_resp
        #render json: response.to_json
    end

    def get_campaigns
        response = HTTParty.post("https://preview.wem.io/38864/webservices/securepay/getCampaigns",
            :body => {}.to_json,
            :headers => {
                'Content-Type'=>'application/json',
                'Accept'=>'application/json'
            })
        render json: response.to_json
    end
end
