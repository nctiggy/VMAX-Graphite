#!/usr/bin/env ruby

require "rest_client"
require "csv"
require "json"
require "base64"
require "crack"
require "pry-byebug"
%w{simple-graphite}.each { |l| require l }

settings_file="settings.json"

####################################################################################
# Method: Read's the Unisphere XSD file and gets all Metrics for the specified scope
####################################################################################
def get_metrics(param_type,xsd)
	output = Array.new
	JSON.parse(xsd)['xs:schema']['xs:simpleType'].each do |type|
		if type['name'] == "#{param_type}Metric"
			type['xs:restriction']['xs:enumeration'].each do |metric|
				output.push(metric['value']) if metric['value'] == metric['value'].upcase
			end
		end
	end
	return output
end

#####################################
# Method: Reutrns keys for all scopes
#####################################
def get_keys(unisphere,payload,monitor,auth)
	if monitor['scope'].downcase == "array"
		rest = rest_get("https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/keys", auth)
	else
		rest = rest_post(payload.to_json,"https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/keys", auth)
	end
	output = rest["#{monitor['scope'].downcase}Info"] if unisphere['version'] == 8
	output = rest["#{monitor['scope'].downcase}KeyResult"]["#{monitor['scope'].downcase}Info"] if unisphere['version'] == 7
	return output
end

##################################################
# Method: Find differences in the key payload
##################################################
def diff_key_payload(incoming_payload,parent_id=nil)
	baseline_keys=["firstAvailableDate","lastAvailableDate"]
	#baseline_keys.push(parent_id) if parent_id
	incoming_keys=incoming_payload.keys
	return incoming_keys-baseline_keys
end

##################################################
# Method: Build the Key Payload
##################################################
def build_key_payload(unisphere,symmetrix,key=nil,parent_id=nil)
	payload = { "symmetrixId" => symmetrix['sid']}
	extra_payload = {parent_id[0] => key[parent_id[0]]} if parent_id
	payload.merge(extra_payload) if parent _id
	payload = {  "#{monitor['scope']}KeyParam" => payload } if unisphere['version'] == 7
	return payload
end

##################################################
# Method: Build the Metric Payload
##################################################
def build_metric_payload(monitor,symmetrix,metrics,key=nil,parent_id=nil,child_key=nil)
	payload = { "symmetrixId" => symmetrix['sid'], "startDate" => key['lastAvailableDate'], "lastDate" => key['lastAvailableDate'], "dataFormat" => "Average", "metrics" => metrics}
	parent_payload = { parent_id[0] => key[parent_id[0]] } unless monitor['scope'] == "Array"
	payload.merge(parent_payload) unless monitor['scope'] == "Array"
	child_id = diff_key_payload(child_key) if child_key
	child_payload = { child_id[0] => child_key[child_id[0]] } if child_key
	payload.merge(child_payload) if child_key
	componentId = get_component_id_key(monitor['scope']) if unisphere['version'] == 7
	payload = {  "#{monitor['scope']}Param" => payload } if unisphere['version'] == 7
	return payload
end

##################################################
# Method: Returns Metrics for all component scopes
##################################################
def get_metrics(unisphere,payload,monitor,auth)
	rest = rest_post(payload.to_json,"https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/metrics", auth)
	output = rest['resultList']['result'][0] if unisphere['version'] == 8
	output = rest['iterator']['resultList']['result'][0] if unisphere['version'] == 7
	return output
end

##################################################
# Method: Returns Metrics for the Array scope only
##################################################
def get_array_metrics(unisphere,symmetrix,monitor,key,metrics,auth)
	### Create a payload if unisphere 7 ###
	payload = { "#{get_component_id_key(monitor['scope'])}Param" => { "symmetrixId" => symmetrix['sid'], "startDate" => key['lastAvailableDate'], "endDate" => key['lastAvailableDate'], "metrics" => metrics}} if unisphere['version'] == 7
	### Create a payload if unisphere 8 ###
	payload = { "metrics" => metrics, "dataFormat" => "Average", "symmetrixId" => symmetrix['sid'], "startDate" => key['lastAvailableDate'], "endDate" => key['lastAvailableDate']} if unisphere['version'] == 8
	### Make the rest call to unisphere ###
	rest = rest_post(payload.to_json, "https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/metrics", auth)
	### Parse the results to return an array of metrics for unisphere 8 ###
	output = rest['resultList']['result'][0] if unisphere['version'] == 8
	### Parse the results to return an array of metrics for unisphere 7 ###
	output = rest['iterator']['resultList']['result'][0] if unisphere['version'] == 7
	### Return the array of Metrics ###
	return output
end

#########################
# Method: API Post Method
#########################
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

###################################################################
# Method: Helper Method to correctly format scope for JSON payloads
###################################################################
def get_component_id_key(scope)
	### If the scope starts with fe or be
	scope.start_with?("fe","be") ? scope[2..-1].downcase : scope.downcase
end

########################
# Method: API GET Method
########################
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
g = Graphite.new({host: config['graphite']['host'], port: config['graphite']['port']}) if config['graphite']['enabled']

config['unisphere'].each do |unisphere|
	myparams = Crack::XML.parse(File.read("unisphere#{unisphere['version']}.xsd")).to_json
	auth = Base64.strict_encode64("#{unisphere['user']}:#{unisphere['password']}")
	unisphere['symmetrix'].each do |symmetrix|
		config['monitor'].each do |monitor|
			output_payload = {}
			metrics_param = get_metrics(monitor['scope'],myparams)
			key_payload = build_key_payload(unisphere,symmetrix)
			keys = get_keys(unisphere,key_payload,monitor,auth)
			if monitor['scope'] == "Array"
				keys.each do |key|
					if key['symmetrixId'] == symmetrix['sid']
						metrics = get_array_metrics(unisphere,symmetrix,monitor,key,metrics_param,auth)
						metrics_param.each do |metric|
							output_payload["symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{metric}"] = metrics[metric]
						end
					end
				end
			else
				keys.each do |key|
					parent_ids = diff_key_payload(key)
					if monitor.key?("children")
						child_payload = build_key_payload(unisphere,symmetrix,key,parent_ids)
						child_keys = get_keys(unisphere,child_payload,monitor,auth)
						child_keys.each do |child_key|
							metric_payload = build_metric_payload(monitor,symmetrix,metrics,key,parent_ids,child_key)
							metrics = get_metrics(unisphere,metric_payload,monitor,auth)
						end
					end
					metrics = get_component_metrics(unisphere,symmetrix,monitor,key,metrics_param,auth)
					metrics_param.each do |metric|
						output_payload["symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{key['id']}.#{metric}"] = metrics[metric] if unisphere['version'] == 8
						output_payload["symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{key[get_component_id_key(monitor['scope'])+'Id']}.#{metric}"] = metrics[metric] if unisphere['version'] == 7
					end
				end
			end
			g.send_metrics(output_payload) if config['graphite']['enabled']
			CSV.open("#{symmetrix['sid']}-#{Time.now.strftime("%Y%m%d%H%M%S")}.csv", "wb") { |csv| output_payload.to_a.each { |elem| csv << elem } } if config['csv']['enabled']
		end
	end
end
