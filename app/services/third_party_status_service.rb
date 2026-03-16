# app/services/third_party_status_service.rb
#
# Checks the status pages of all third party services CallRail depends on
# Most SaaS products publish a public status page at status.their-domain.com
# These pages return JSON we can parse to check if they are up or down

class ThirdPartyStatusService

    # list of all third party services to check
    # each entry has a name and a status page API URL
    SERVICES = [
      { name: "Twilio",      url: "https://status.twilio.com/api/v2/status.json" },
      { name: "AWS",         url: "https://health.aws.amazon.com/public/currentevents" },
      { name: "Datadog",     url: "https://status.datadoghq.com/api/v2/status.json" },
      { name: "PagerDuty",   url: "https://status.pagerduty.com/api/v2/status.json" },
      { name: "Semaphore",   url: "https://semaphoreci.statuspage.io/api/v2/status.json" },
      { name: "Pusher",      url: "https://status.pusher.com/api/v2/status.json" },
      { name: "Mailchimp",   url: "https://status.mailchimp.com/api/v2/status.json" },
      { name: "Hubspot",     url: "https://status.hubspot.com/api/v2/status.json" },
      { name: "Netlify",     url: "https://www.netlifystatus.com/api/v2/status.json" },
      { name: "Zuora",       url: "https://status.zuora.com/api/v2/status.json" },
      { name: "AssemblyAI",  url: "https://status.assemblyai.com/api/v2/status.json" },
      { name: "Bandwidth",   url: "https://status.bandwidth.com/api/v2/status.json" },
      { name: "Snyk",        url: "https://status.snyk.io/api/v2/status.json" },
    ]
  
    # check_all loops through every service and returns an array of results
    # each result tells us the service name, whether it is up, and the status description
    def self.check_all
      SERVICES.map do |service|
        check_service(service[:name], service[:url])
      end
    end
  
    private
  
    def self.check_service(name, url)
      # make a GET request to the status page API
      # timeout after 5 seconds — we can't wait forever at 2am
      response = Faraday.get(url) do |req|
        req.options.timeout = 5
      end
  
      if response.success?
        # parse the JSON response
        data = JSON.parse(response.body)
  
        # most status pages follow the same format:
        # { "status": { "indicator": "none", "description": "All Systems Operational" } }
        indicator = data.dig("status", "indicator")
        description = data.dig("status", "description")
  
        {
          name: name,
          # "none" means everything is fine
          # anything else (minor, major, critical) means there is a problem
          up: indicator == "none",
          indicator: indicator,
          description: description || "Unknown",
          checked_at: Time.now.iso8601
        }
      else
        # if the status page itself returned an error
        {
          name: name,
          up: nil,
          indicator: "unknown",
          description: "Status page returned #{response.status}",
          checked_at: Time.now.iso8601
        }
      end
  
    # if the request timed out or failed entirely
    rescue => e
      {
        name: name,
        up: nil,
        indicator: "unreachable",
        description: "Could not reach status page: #{e.message}",
        checked_at: Time.now.iso8601
      }
    end
  
  end