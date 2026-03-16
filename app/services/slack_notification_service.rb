# app/services/slack_notification_service.rb
#
# Posts structured incident briefings to Slack
# Uses Slack's Block Kit format for rich, readable messages
# Block Kit lets us use headers, dividers, and formatted sections

class SlackNotificationService

    def self.post_incident_briefing(incident, briefing, third_party_statuses)
  
      # identify down services for the status summary
      down_services   = third_party_statuses.select { |s| s[:up] == false }
      unknown_services = third_party_statuses.select { |s| s[:up].nil? }
  
      # pick an emoji based on severity
      severity_emoji = case incident["severity"]&.downcase
      when "critical" then "🔴"
      when "high"     then "🟠"
      when "low"      then "🟡"
      else "⚪"
      end
  
      # build the Slack message using Block Kit
      # blocks are Slack's way of creating rich formatted messages
      blocks = [
  
        # header block — big bold title at the top
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "#{severity_emoji} OnCallBot Incident Briefing"
          }
        },
  
        # incident title and ID
        {
          type: "section",
          fields: [
            { type: "mrkdwn", text: "*Incident:*\n#{incident["title"]}" },
            { type: "mrkdwn", text: "*ID:*\n#{incident["id"]}" },
            { type: "mrkdwn", text: "*Service:*\n#{incident["service"]}" },
            { type: "mrkdwn", text: "*Triggered:*\n#{incident["triggered_at"]}" }
          ]
        },
  
        # divider between sections
        { type: "divider" },
  
        # third party status summary
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*3rd Party Status:*\n#{format_third_party_status(down_services, unknown_services)}"
          }
        },
  
        { type: "divider" },
  
        # Claude's full analysis
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*AI Analysis:*\n```#{briefing}```"
          }
        },
  
        { type: "divider" },
  
        # footer with timestamp
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
  
      # post to Slack
      Faraday.post(ENV.fetch("SLACK_WEBHOOK_URL")) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { blocks: blocks }.to_json
      end
  
    end
  
    # posts a minimal error message if the analysis job itself fails
    def self.post_error(incident, error_message)
      Faraday.post(ENV.fetch("SLACK_WEBHOOK_URL")) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          text: "🔴 *OnCallBot Error* — Failed to analyze incident #{incident["id"]}: #{error_message}"
        }.to_json
      end
    end
  
    private
  
    def self.format_third_party_status(down_services, unknown_services)
      if down_services.empty? && unknown_services.empty?
        "✅ All third party services operational"
      else
        lines = []
        down_services.each    { |s| lines << "🔴 #{s[:name]}: #{s[:description]}" }
        unknown_services.each { |s| lines << "⚪ #{s[:name]}: #{s[:description]}" }
        lines.join("\n")
      end
    end
  
  end