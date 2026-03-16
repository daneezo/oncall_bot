# app/jobs/incident_analysis_job.rb

class IncidentAnalysisJob < ApplicationJob

  # incidents go in their own queue — high priority
  queue_as :incidents

  # retry 3 times — we really want this to succeed at 2am
  retry_on StandardError, attempts: 3, wait: :polynomially_longer

  # incident is a hash of the PagerDuty alert details
  def perform(incident)

    # step 1 — check all 3rd party status pages
    # this tells us immediately if the problem is us or someone else
    third_party_statuses = ThirdPartyStatusService.check_all

    # step 2 — send everything to Claude for analysis
    # Claude gets the alert details + 3rd party statuses
    # and returns a structured briefing
    briefing = ClaudeIncidentService.analyze(incident, third_party_statuses)

    # step 3 — post the briefing to Slack
    # this is what the engineer wakes up to
    SlackNotificationService.post_incident_briefing(incident, briefing, third_party_statuses)

  rescue => e
    # if anything fails, post a minimal alert to Slack
    # so the engineer at least knows something fired
    SlackNotificationService.post_error(incident, e.message)
    raise e
  end

end