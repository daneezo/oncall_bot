# app/services/claude_incident_service.rb
#
# Sends incident details + third party statuses to Claude
# Claude returns a structured briefing with exact navigation steps
# so the engineer knows exactly where to look at 2am

class ClaudeIncidentService

    API_URL = "https://api.anthropic.com/v1/messages"
    MODEL   = "claude-haiku-4-5-20251001"
  
    def self.analyze(incident, third_party_statuses)
  
      client = Faraday.new(API_URL) do |f|
        f.request :json
        f.response :json
      end
  
      response = client.post do |req|
        req.headers["x-api-key"]         = ENV.fetch("ANTHROPIC_API_KEY")
        req.headers["anthropic-version"]  = "2023-06-01"
        req.body = {
          model:      MODEL,
          max_tokens: 1000,
          messages: [
            {
              role:    "user",
              content: build_prompt(incident, third_party_statuses)
            }
          ]
        }
      end
  
      response.body.dig("content", 0, "text")
  
    rescue => e
      "Claude analysis unavailable: #{e.message}"
    end
  
    private
  
    def self.build_prompt(incident, third_party_statuses)
      # identify which third parties are down
      down_services = third_party_statuses.select { |s| s[:up] == false }
      all_operational = down_services.empty?
  
      <<~PROMPT
        You are an expert on-call engineering assistant for CallRail, a B2B SaaS marketing analytics platform.
        An engineer has just been woken up at 2am by this PagerDuty alert. Give them exactly what they need to act immediately.
  
        INCIDENT DETAILS:
        - ID: #{incident["id"]}
        - Title: #{incident["title"]}
        - Severity: #{incident["severity"]}
        - Service: #{incident["service"]}
        - Alert Type: #{incident["alert_type"]}
        - Description: #{incident["description"]}
        - Triggered At: #{incident["triggered_at"]}
  
        THIRD PARTY STATUS:
        #{all_operational ? "All third party services are operational." : "DEGRADED SERVICES: #{down_services.map { |s| "#{s[:name]} (#{s[:description]})" }.join(", ")}"}
  
        Respond in exactly this format — no deviations:
  
        SEVERITY: [Critical/High/Low]
  
        WHAT BROKE:
        [One clear sentence explaining what is wrong]
  
        IS THIS US OR THEM:
        [If a third party is down that could cause this, say so clearly with the service name. Otherwise say "This appears to be an internal issue."]
  
        STEP BY STEP — WHAT TO DO RIGHT NOW:
        1. [Exact tool name] → [Exact menu path] → [Exactly what to look for]
        2. [Exact tool name] → [Exact menu path] → [Exactly what to look for]
        3. [Exact tool name] → [Exact menu path] → [Exactly what to look for]
        4. [Exact tool name] → [Exact menu path] → [Exactly what to look for]
        5. [Exact tool name] → [Exact menu path] → [Exactly what to look for]
  
        ESCALATE OR HANDLE:
        [Should the engineer handle this alone or escalate? To whom?]
  
        LIKELY CAUSE:
        [One sentence on the most probable root cause based on the alert type]
      PROMPT
    end
  
  end