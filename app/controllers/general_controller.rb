class GeneralController < ApplicationController
    def test
        render json: {
            success: true
        }.to_json
    end

    def gnaf
        response = HTTParty.get("https://api.psma.com.au/v2/addresses/geocoder?additionalProperties=localGovernmentArea,stateElectorate,commonwealthElectorate,asgsMain&address=#{params[:address]}",
            :headers => {"Authorization"=>ENV['GNAF_API_KEY']})
        render json: {
            response: response.body
        }.to_json
    end
end
