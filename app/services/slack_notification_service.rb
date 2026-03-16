# app/services/slack_notification_service.rb
#
# Posts structured incident briefings to Slack
# Uses Slack Block Kit format for rich readable messages
# Block Kit lets us use headers, dividers, and formatted sections

class SlackNotificationService

    def self.post_incident_briefing(incident, briefing, third_party_statuses)
  
      # separate statuses into categories for the status section
      down_services    = third_party_statuses.select { |s| s[:up] == false }
      unknown_services = third_party_statuses.select { |s| s[:up].nil? }
  
      # pick an emoji based on severity
      # this is the first thing the engineer sees at 2am
      severity_emoji = case incident["severity"]&.downcase
      when "critical" then "🔴"
      when "high"     then "🟠"
      when "low"      then "🟡"
      else "⚪"
      end
  
      blocks = [
  
        # header block - big bold title at the top
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "#{severity_emoji} OnCallBot Incident Briefing"
          }
        },
  
        # incident details - two columns showing key facts
        {
          type: "section",
          fields: [
            { type: "mrkdwn", text: "*Incident:*\n#{incident["title"]}" },
            { type: "mrkdwn", text: "*ID:*\n#{incident["id"]}" },
            { type: "mrkdwn", text: "*Service:*\n#{incident["service"]}" },
            { type: "mrkdwn", text: "*Triggered:*\n#{incident["triggered_at"]}" }
          ]
        },
  
        { type: "divider" },
  
        # third party status section
        # pass the full statuses list so we can show ALL services with links
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*3rd Party Status:*\n#{format_third_party_status(third_party_statuses)}"
          }
        },
  
        { type: "divider" },
  
        # Claudes full analysis
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*AI Analysis:*\n```#{briefing}```"
          }
        },
  
        { type: "divider" },
  
        # footer
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "OnCallBot | #{Time.now.strftime('%Y-%m-%d %H:%M:%S UTC')} | DEV-19"
            }
          ]
        }
  
      ]
  
      # post to Slack via incoming webhook
      Faraday.post(ENV.fetch("SLACK_WEBHOOK_URL")) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { blocks: blocks }.to_json
      end
  
    end
  
    # posts a minimal error message if the analysis job itself fails
    # ensures the engineer always gets notified even if Claude is down
    def self.post_error(incident, error_message)
      Faraday.post(ENV.fetch("SLACK_WEBHOOK_URL")) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          text: "🔴 *OnCallBot Error* — Failed to analyze incident #{incident["id"]}: #{error_message}"
        }.to_json
      end
    end
  
    private
  
    # formats the third party status section
    # takes the FULL statuses array so every service gets a clickable link
    # at 2am the engineer should never have to search for a status page URL
    def self.format_third_party_status(statuses)
  
      # split into four buckets
      down_services   = statuses.select { |s| s[:up] == false }
      operational     = statuses.select { |s| s[:up] == true }
      manual_services = statuses.select { |s| s[:indicator] == "manual" }
      unreachable     = statuses.select { |s| s[:up].nil? && s[:indicator] != "manual" }
  
      lines = []
  
      # confirmed down - most urgent, shown first with link
      down_services.each do |s|
        link = s[:url] ? " - <#{s[:url]}|Check status>" : ""
        lines << "🔴 #{s[:name]}: #{s[:description]}#{link}"
      end
  
      # unreachable or returned error
      # always show a clickable link so engineer can verify directly
      # this replaces the raw error message with something actionable
      unreachable.each do |s|
        link = s[:url] ? " - <#{s[:url]}|Check status page>" : ""
        lines << "⚪ #{s[:name]}: #{s[:description]}#{link}"
      end
  
      # operational services - show with link so engineer can verify if needed
      operational.each do |s|
        link = s[:url] ? " - <#{s[:url]}|Status page>" : ""
        lines << "✅ #{s[:name]}: #{s[:description]}#{link}"
      end
  
      # manual check services - no JSON API so always show direct link
      unless manual_services.empty?
        lines << "\n*Check manually:*"
        manual_services.each do |s|
          link = s[:url] ? "<#{s[:url]}|Open status page>" : s[:description]
          lines << "🔗 #{s[:name]}: #{link}"
        end
      end
  
      lines.join("\n")
    end
  
  end