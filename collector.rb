require "rest_client"
require "json"
require "base64"
require "crack"
%w{simple-graphite}.each { |l| require l }

@timestamp=''
settings_file="settings.json"

def get_metrics(param_type,xsd)
	output = Array.new
	JSON.parse(xsd)['xs:schema']['xs:simpleType'].each do |type|
		if type['name'] == "#{param_type}Metric"
			type['xs:restriction']['xs:enumeration'].each do |metric|
				output.push(metric['value'])
			end
		end
	end
	return output
end

def get_keys(unisphere,symmetrix,monitor,auth)
	if monitor['scope'].downcase == "array"
		rest = rest_get("https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/#{monitor['type']}/#{monitor['scope']}/keys", auth)["#{scope.downcase}KeyResult"]["#{scope.downcase}Info"]
		#rest.each do |array|
			#if array['symmetrixId'] == symmetrix['symmetrixId']
				#@timestamp=array['lastAvailableDate']
				#return @timestamp
			#end
		#end
	else
		payload = { "#{monitor['scope']}KeyParam": { "symmetrixId": symmetrix['symmetrixId']}}
		rest = rest_post(payload,"https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/#{monitor['type']}/#{monitor['scope']}/keys", auth)["#{scope.downcase}KeyResult"]["#{scope.downcase}Info"]
		#rest.each do |device|
	end
	return rest
end

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

@config=readSettings(settings_file)
auth = Base64.strict_encode64("#{@config['uni_user']}:#{@config['uni_password']}")
g = Graphite.new({host: @config['graphite_host'], port: @config['graphite_port']})
myparams = Crack::XML.parse(File.read(@config['parameters_file'])).to_json

@config['unisphere'].each do |unisphere|
	unisphere['symmetrix'].each do |symmetrix|
		@config['monitor'].each do |monitor|
			graphite_payload = {}
			arrays_timestamp = rest_get("https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/#{monitor['type']}/#{monitor['scope']}/keys", auth)
			arrays_timestamp['arrayKeyResult']['arrayInfo'].each do |array|
				if array['symmetrixId'] == symmetrix['sid']
					@timestamp=array['lastAvailableDate']
				end
			end
			metrics_param = get_metrics(monitor['scope'],myparams)
			payload = {arrayParam: {symmetrixId: symmetrix['sid'], startDate: @timestamp, endDate: @timestamp, metrics: metrics_param}}
			metrics = rest_post(payload, "https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/#{monitor['type']}/#{monitor['scope']}/metrics", auth)
			metrics_param.each do |metric|
				graphite_payload["symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{metric}"] = metrics['iterator']['resultList']['result'][0][metric]
			end
			g.send_metrics(graphite_payload)
		end
	end
end
