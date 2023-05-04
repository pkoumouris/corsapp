class GeneralController < ApplicationController
    skip_forgery_protection

    def test
        render json: {
            success: true
        }.to_json
    end

    def gnaf
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{params[:address]}",
            :headers => {"Authorization"=>'0YONURTjk2DbMU4zKFViQb8MuqAPTOoZ'})
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
        puts response
        puts "Amount"
        puts params[:tgt_body]["SecurePay Amount".to_sym]
        if !!response["Secure Pay Success"] || true
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
                'Authorization'=>'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiIsImFsZyI6IkhTNTEyIiwia2lkIjoielhuOTRfbFBsZ1EzUXctcTE3QV9VRHU5QWx1VkFteHZZWkhELWZyWFBWMCJ9.eyJpc3MiOiJuYnVpbGQiLCJpYXQiOjE2ODI5OTkzMjgsImp0aSI6Ijg1OWE2Nzc0LTQwYWQtNGVjYS05Y2UzLTU2MTY2NmUwMDc2MyIsInBybiI6IjY0ODc2MHxhY2wiLCJ1c2VyIjp7ImlkIjo2NDg3NjAsImVtYWlsIjoicGFycmlzLmtvdW1vdXJpc0BnbWFpbC5jb20ifSwibmF0aW9uIjp7ImlkIjoiNTY5NWQ0ZWVkNTM1Y2Y2NTA1MDAwMDA0Iiwic2x1ZyI6ImFjbCJ9fQ.TSaWHQREYWUUY1LDYrdBOOWLDr_FrZrRYZWXn46T5XzSo04UgddfM-ZiJ8TNniz4evhaWvvnwoTO2Z-lvrGiHw'
            })
            puts "nb_resp"
            puts nb_resp
        end
        #nb_resp = JSON.parse(response["NB Donation Response"])
        #puts nb_resp
        render json: response.to_json
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
