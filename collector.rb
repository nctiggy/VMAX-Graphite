#!/usr/bin/env ruby

require "rest-client"
require "csv"
require "json"
require "base64"
require "nokogiri"
require "influxdb"
%w{simple-graphite}.each { |l| require l }

settings_file="#{Dir.pwd}/settings.json"

####################################################################################
# Method: Read's the Unisphere XSD file and gets all Metrics for the specified scope
####################################################################################
def get_metrics(param_type)
  page = Nokogiri::HTML(open("#{Dir.pwd}/target/docs/performance_#{param_type}Metric.html"))
  output = page.css('table').last.css('td:first-child:not(.deprecated)').map(&:text)
  return output
end

####################################################################################
# Method: Create a version file
####################################################################################
def newer_version?(auth)
  puts "magic"
end

####################################################################################
# Method:
####################################################################################

#####################################
# Method: Reutrns keys for all scopes
#####################################
def get_keys(unisphere,payload,monitor,auth)
  if monitor['scope'].downcase == "array"
    rest = rest_get("https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/keys", auth)
  else
    rest = rest_post(payload.to_json,"https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/keys", auth)
  end
  componentId = get_component_id_payload(monitor['scope'])
  output = rest["#{componentId}Info"] if unisphere['version'] == 8
  output = rest["#{componentId}KeyResult"]["#{componentId}Info"] if unisphere['version'] == 7
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
def build_key_payload(unisphere,symmetrix,monitor,key=nil,parent_id=nil)
  payload = { "symmetrixId" => symmetrix['sid']}
  extra_payload = {parent_id[0] => key[parent_id[0]]} if parent_id
  payload.merge!(extra_payload) if parent_id
  componentId = get_component_id_key(monitor['scope']) if unisphere['version'] == 7
  payload = {  "#{componentId}KeyParam" => payload } if unisphere['version'] == 7
  return payload
end

##################################################
# Method: Build the Metric Payload
##################################################
def build_metric_payload(unisphere,monitor,symmetrix,metrics,key=nil,parent_id=nil,child_key=nil,child_id=nil)
  payload = { "symmetrixId" => symmetrix['sid'], "metrics" => metrics}
  parent_payload = { parent_id[0] => key[parent_id[0]] } unless monitor['scope'] == "Array"
  payload.merge!(parent_payload) unless monitor['scope'] == "Array"
  child_payload = { child_id[0] => child_key[child_id[0]], "startDate" => child_key['lastAvailableDate'], "endDate" => child_key['lastAvailableDate'] } if child_key
  payload.merge!(child_payload) if child_key
  timestamp_payload = { "startDate" => key['lastAvailableDate'], "endDate" => key['lastAvailableDate'] } unless child_key
  payload.merge!(timestamp_payload) unless child_key
  uni8_payload = { "dataFormat" => "Average" } if unisphere['version'] == 8
  payload.merge!(uni8_payload) if unisphere['version'] == 8
  componentId = get_component_id_key(monitor['scope']) if (unisphere['version'] == 7 && child_key.nil?)
  componentId = get_component_id_key(monitor['children'][0]['scope']) if (unisphere['version'] == 7 && child_key != nil)
  payload = {  "#{componentId}Param" => payload } if unisphere['version'] == 7
  return payload
end

################################################################################
# Method: Returns Metrics for all component scopes. Helper for building payloads
################################################################################
def get_perf_metrics(unisphere,payload,monitor,auth)
  rest = rest_post(payload.to_json,"https://#{unisphere['ip']}:#{unisphere['port']}/univmax/restapi/performance/#{monitor['scope']}/metrics", auth)
  output = rest['resultList']['result'][0] if unisphere['version'] == 8
  output = rest['iterator']['resultList']['result'][0] if unisphere['version'] == 7
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

##################################################################################
# Method: Helper Method to correctly format scope for JSON payloads in Unisphere 7
##################################################################################
def get_component_id_key(scope)
  ## Splits the string based on upper case letters ##
  s = scope.split /(?=[A-Z])/
  i = 0
  while i < s.length
    ## If the string in the array is all upcase, make it downcase ##
    s[i] = s[i].downcase if s[i] == s[i].upcase
    ## If this is the first string in the array and it is camelcase, make it all downcase ##
    s[i] = s[i].downcase if i == 0 && s[i] == s[i].capitalize
    i += 1
  end
  new_scope = s.join
  return new_scope
end

##################################################################################
# Method: Helper Method to correctly format scope for JSON return in Unisphere 7
##################################################################################
def get_component_id_payload(scope)
  ## Splits the string based on upper case letters ##
  s = scope.split /(?=[A-Z])/
  i = 0
  if s[-1].capitalize == "Pool"
    new_scope = "pool"
  else
    while i < s.length
      ## If the string in the array is all upcase, make it downcase ##
      s[i] = s[i].downcase if s[i] == s[i].upcase
      ## If this is the first string in the array and it is camelcase, make it all downcase ##
      s[i] = s[i].downcase if i == 0 && s[i] == s[i].capitalize
      i += 1
    end
    new_scope = s.join
  end
  return new_scope
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

#################################
# Method: Read settings.json file
#################################
def readSettings(file)
  settings = File.read(file)
  JSON.parse(settings)
end

config=readSettings(settings_file)
g = Graphite.new({host: config['graphite']['host'], port: config['graphite']['port']}) if config['graphite']['enabled']
i = InfluxDB::Client.new url: influx_url if config['influxdb']['enabled']

## Loop through each Unisphere ##
config['unisphere'].each do |unisphere|
  ## Build the Base64 auth string ##
  auth = Base64.strict_encode64("#{unisphere['user']}:#{unisphere['password']}")
  ## Loop through each symmetrix in the current unisphere ##
  unisphere['symmetrix'].each do |symmetrix|
    graphite_output_payload = {}
    influx_output_payload = []
    ## Loop through each component on the current symmetrix ##
    config['monitor'].each do |monitor|
      ## If the component is not enabled i.e. false then skip. If the parent is false it will skip the children ##
      next unless monitor['enabled']
      metrics_param = get_metrics(monitor['scope'])
      key_payload = build_key_payload(unisphere,symmetrix,monitor)
      keys = get_keys(unisphere,key_payload,monitor,auth)
      keys.each do |key|
        parent_ids = diff_key_payload(key)
        if monitor.key?("children")
          if monitor['children'][0]['enabled']
            child_payload = build_key_payload(unisphere,symmetrix,monitor['children'][0],key,parent_ids)
            child_keys = get_keys(unisphere,child_payload,monitor['children'][0],auth)
            child_keys.each do |child_key|
              child_ids = diff_key_payload(child_key)
              metrics_param = get_metrics(monitor['children'][0]['scope'])
              metric_payload = build_metric_payload(unisphere,monitor,symmetrix,metrics_param,key,parent_ids,child_key,child_ids)
              metrics = get_perf_metrics(unisphere,metric_payload,monitor['children'][0],auth)
              metrics_param.each do |metric|
                influx_output_payload.push({series: metric, tags: { array_type: 'symmetrix', sn: symmetrix['sid'], component: monitor['scope'], component_name: key[parent_ids[0]], child_component_name: child_key[child_ids[0]]}, values: { value: metrics[metric] } } )
                graphite_output_payload[(config['graphite']['prefix'] ? "#{config['graphite']['prefix']}." : "") + "symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{key[parent_ids[0]]}.#{child_key[child_ids[0]]}.#{metric}"] = metrics[metric]
              end
            end
          end
        end
        if (monitor['scope'] != "Array") || (monitor['scope'] == "Array" && key['symmetrixId'] == symmetrix['sid'])
          metrics_param = get_metrics(monitor['scope'])
          metric_payload = build_metric_payload(unisphere,monitor,symmetrix,metrics_param,key,parent_ids)
          metrics = get_perf_metrics(unisphere,metric_payload,monitor,auth)
          metrics_param.each do |metric|
            influx_output_payload.push({series: metric, tags: { array_type: 'symmetrix', sn: symmetrix['sid'], component: monitor['scope'], component_name: key[parent_ids[0]]}, values: { value: metrics[metric] } } ) unless monitor['scope'] == "Array"
            influx_output_payload.push({series: metric, tags: { array_type: 'symmetrix', sn: symmetrix['sid'], component: monitor['scope']}, values: { value: metrics[metric] } } ) if monitor['scope'] == "Array"
            graphite_output_payload[(config['graphite']['prefix'] ? "#{config['graphite']['prefix']}." : "") + "symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{metric}"] = metrics[metric] if monitor['scope'] == "Array"
            graphite_output_payload[(config['graphite']['prefix'] ? "#{config['graphite']['prefix']}." : "") + "symmetrix.#{symmetrix['sid']}.#{monitor['scope']}.#{key[parent_ids[0]]}.#{metric}"] = metrics[metric] unless monitor['scope'] == "Array"
          end
        end
      end
    end
    i.write_points(influx_output_payload) if config['influxdb']['enabled']
    g.send_metrics(graphite_output_payload) if config['graphite']['enabled']
    CSV.open("#{symmetrix['sid']}-#{Time.now.strftime("%Y%m%d%H%M%S")}.csv", "wb") { |csv| graphite_output_payload.to_a.each { |elem| csv << elem } } if config['csv']['enabled']
  end
end
