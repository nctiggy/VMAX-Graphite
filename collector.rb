require "rest_client"
require "json"
require "base64"
%w{simple-graphite}.each { |l| require l }

@timestamp=''
settings_file="settings.json"

def rest_post(payload, api_url, auth, cert=nil)
	JSON.parse(RestClient::Request.execute(
		method: :post,
		url: api_url,
		verify_ssl: false,
		payload: payload,
		headers: {
			authorization: auth,
			content_type: 'application/json',
			accept: :json
		}
	))
end

def rest_get(api_url, auth, cert=nil)
	JSON.parse(RestClient::Request.execute(method: :get,
		url: api_url,
		verify_ssl: false,
		headers: {
			authorization: auth,
			accept: :json
		}
	))
end

def readSettings(file)
	settings = File.read(file)
	JSON.parse(settings)
end

config=readSettings(settings_file)
auth = Base64.strict_encode64("#{config['uni_user']}:#{config['uni_password']}")
g = Graphite.new({host: config['graphite_host'], port: config['graphite_port']})

config['unisphere'].each do |unisphere|
	unisphere['symmetrix'].each do |symmetrix|
		config['monitor'].each do |monitor|
			payload = {}
			###arrays_timestamp = JSON.parse('{"arrayKeyResult": {"arrayInfo": [{"symmetrixId": "000192601775","lastAvailableDate": "1441310100000"}]}}')
			rest_get("https://#{unisphere['ip']}:#{unisphere['port']}/unimax/restapi/#{monitor['type']}/#{monitor['scope']}/keys", auth)['arrayKeyResult']['arrayInfo']
			arrays_timestamp['arrayKeyResult']['arrayInfo'].each do |array|
				if array['symmetrixId'] == symmetrix['sid']
					@timestamp=array['lastAvailableDate']
				end
			end
			payload = {arrayParam: {symmetrixId: symmetrix['sid'], startDate: @timestamp, endDate: @timestamp, metrics: monitor['metrics']}}
			metrics = rest_post(payload, "https://#{unisphere['ip']}:#{unisphere['port']}/unimax/restapi/#{monitor['type']}/#{monitor['scope']}/metrics", auth)
			monitor['metrics'].each do |metric|
				payload["symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{metric}] = metrics['iterator']['resultList']['result'][0][metric]
			g.send_metrics(payload)
		end
	end
end
