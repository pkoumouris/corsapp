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
                        "payment_type_id"=>"1"
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
