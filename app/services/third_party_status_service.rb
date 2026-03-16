# app/services/third_party_status_service.rb
#
# Checks the status of all third party services CallRail depends on
# Two categories:
# 1. STATUSPAGE_SERVICES - have a public JSON API we can parse automatically
# 2. MANUAL_CHECK_SERVICES - no public JSON API, we provide a direct link instead

class ThirdPartyStatusService

    # services using the standard statuspage.io format
    # all support /api/v2/status.json
    # indicator values: "none" = all good, "minor" / "major" / "critical" = something is wrong
    STATUSPAGE_SERVICES = [
      { name: "Twilio",      url: "https://status.twilio.com/api/v2/status.json" },
      { name: "Datadog",     url: "https://status.datadoghq.com/api/v2/status.json" },
      { name: "PagerDuty",   url: "https://status.pagerduty.com/api/v2/status.json" },
      { name: "Pusher",      url: "https://status.pusher.com/api/v2/status.json" },
      { name: "Semaphore",   url: "https://status.semaphoreci.com/api/v2/status.json" },
      { name: "Netlify",     url: "https://www.netlifystatus.com/api/v2/status.json" },
      { name: "AssemblyAI",  url: "https://status.assemblyai.com/api/v2/status.json" },
      { name: "Bandwidth",   url: "https://status.bandwidth.com/api/v2/status.json" },
      { name: "Snyk",        url: "https://status.snyk.io/api/v2/status.json" },
      { name: "Hubspot",     url: "https://status.hubspot.com/api/v2/status.json" },
      { name: "Zuora",       url: "https://status.zuora.com/api/v2/status.json" },
    ]
  
    # services without a public JSON API
    # provide a direct clickable link so the engineer can check manually in one click
    MANUAL_CHECK_SERVICES = [
      { name: "AWS",        url: "https://health.aws.amazon.com/health/status" },
      { name: "Mailchimp",  url: "https://status.mailchimp.com" },
      { name: "IBM Watson", url: "https://status.video.ibm.com" },
    ]
  
    # check_all runs through every service and returns an array of results
    # called by IncidentAnalysisJob before sending to Claude
    def self.check_all
      results = []
  
      # check all services with JSON APIs automatically
      STATUSPAGE_SERVICES.each do |service|
        results << check_statuspage(service[:name], service[:url])
      end
  
      # for manual services return a direct link instead of trying to parse
      # indicator: "manual" tells SlackNotificationService to render as a link
      MANUAL_CHECK_SERVICES.each do |service|
        results << {
          name: service[:name],
          up: nil,
          indicator: "manual",
          description: "Check manually: #{service[:url]}",
          url: service[:url],
          checked_at: Time.now.iso8601
        }
      end
  
      results
    end
  
    private
  
    # handles the standard statuspage.io JSON format
    # strips /api/v2/status.json from the URL to get the human readable status page link
    def self.check_statuspage(name, url)
      # human readable URL is the base without the API path
      # e.g. https://status.twilio.com/api/v2/status.json -> https://status.twilio.com
      human_url = url.gsub("/api/v2/status.json", "")
  
      response = Faraday.new(url) do |f|
        # follow redirects automatically
        # some status pages return a 302 before serving JSON
        f.response :follow_redirects
      end.get do |req|
        # timeout after 5 seconds
        req.options.timeout = 5
      end
  
      if response.success?
        data = JSON.parse(response.body)
  
        indicator   = data.dig("status", "indicator")
        description = data.dig("status", "description")
  
        {
          name: name,
          # "none" means all systems operational
          # anything else (minor, major, critical) means degraded
          up: indicator == "none",
          indicator: indicator || "unknown",
          description: description || "Unknown",
          # always include the human readable URL so Slack can show a link
          url: human_url,
          checked_at: Time.now.iso8601
        }
  
      else
        # service returned a non-200 response
        # include the URL so engineer can check the page directly
        {
          name: name,
          up: nil,
          indicator: "unknown",
          description: "Status page returned #{response.status}",
          url: human_url,
          checked_at: Time.now.iso8601
        }
      end
  
    rescue => e
      # could not reach the status page at all
      # still include the URL so engineer can try manually
      {
        name: name,
        up: nil,
        indicator: "unreachable",
        description: "Could not reach status page",
        url: human_url,
        checked_at: Time.now.iso8601
      }
    end
  
  end