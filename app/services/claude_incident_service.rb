# app/services/claude_incident_service.rb

class ClaudeIncidentService

    API_URL = "https://api.anthropic.com/v1/messages"
    MODEL   = "claude-haiku-4-5-20251001"
  
    def self.analyze(incident, third_party_statuses)
      client = Faraday.new(API_URL) do |f|
        f.request :json
        f.response :json
      end
  
      response = client.post do |req|
        req.headers["x-api-key"]        = ENV.fetch("ANTHROPIC_API_KEY")
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model:      MODEL,
          max_tokens: 1500,
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
      down_services   = third_party_statuses.select { |s| s[:up] == false }
      all_operational = down_services.empty?
  
      prompt = <<~PROMPT
        You are an expert on-call engineering assistant for CallRail, a B2B SaaS call tracking and marketing analytics platform.
        An engineer has just been woken up by a PagerDuty alert. Help them make the right decisions fast.
  
        === CALLRAIL INCIDENT SEVERITY DEFINITIONS ===
  
        CRITICAL: Prevents majority of accounts from making/receiving calls, logging in,
        accessing mobile app or Lead Center, or data is being LOST (not delayed).
        Response: Primary + Escalation engineer + Incident Captain immediately.
        Comms: Post to #incidents every 10-15 min, update status.callrail.com
  
        MAJOR: Impacts most customers ability to use important features such as
        text inbound/outbound, data capture (delayed or recoverable), LC Agents,
        invoices, phone numbers, Google/Facebook integrations.
        Response: Primary investigates immediately, involves Escalation if needed.
        Comms: Post to #incidents every 30-45 min, update status.callrail.com
  
        MINOR: Minority of customers affected OR performance degraded but not down.
        Features: call waiting, hold music, secondary integrations, degraded webhooks.
        Response: Primary investigates as soon as possible.
        Comms: Post to #incidents at least once per hour during business hours.
  
        NOT AN INCIDENT: Minor bug with workaround available.
        Response: File Jira bug only, no incident process needed.
  
        === CALLRAIL TOOL CHAIN ===
  
        FOR ERRORS AND EXCEPTIONS:
        - Honeybadger: application error tracking, new exceptions after deploys
        - Datadog APM: app.datadoghq.com/apm/home - traces, error rates, latency
        - Datadog Dashboards: app.datadoghq.com/dashboard/lists - per-service dashboards
        - AWS CloudWatch: AWS-related logs
        - kubectl logs: Kubernetes pod logs
  
        FOR DEPLOYS AND ROLLBACKS:
        - Semaphore: CI/CD, build failures, deploy pipeline status
        - prodbot: deploy/rollback commands e.g. prodbot deploy rollback_to XXXX
        - Helm: Kubernetes deploy/rollback
        - kubectl: pod health, CrashLoopBackOff, rollout status
  
        FOR QUEUE AND JOB ISSUES:
        - Sidekiq UI: background job monitoring, dead queue, retries, queue depth
        - RabbitMQ Dashboard: message queue depth, throughput, stuck messages
  
        FOR DATABASE ISSUES:
        - PGHero: PostgreSQL performance, slow queries, index issues, lock contention
        - AWS Console -> RDS: CPU, connections, disk space, performance insights
  
        FOR INFRASTRUCTURE:
        - AWS Console: EC2, RDS, networking, region health
        - kubectl/Kubernetes: pod health, resource saturation, cluster status
        - Upwind: Kubernetes security, service topology, runtime risk
  
        === CALLRAIL SLACK CHANNELS ===
        - #on-call-rotation: acknowledge PagerDuty alerts here
        - #incidents: cross-department incident communication, post updates here
        - #inc-YYYYMMDD-shortdesc: temporary channel created by Incident Captain
        - #on-call-questions: questions about on-call process
  
        === CALLRAIL ESCALATION PROCESS ===
        - Secondary on-call: first escalation point after-hours
        - Escalation engineer: use PagerDuty Add Responders button on the incident
        - Incident Captain: rotating role (eng managers/PMs), manages comms
        - Subject Matter Experts: found in Runbooks or Incident Response doc
        - status.callrail.com: update for any customer-facing incidents
  
        === INCIDENT DETAILS ===
        ID: #{incident["id"]}
        Title: #{incident["title"]}
        Severity: #{incident["severity"]}
        Service: #{incident["service"]}
        Alert Type: #{incident["alert_type"]}
        Description: #{incident["description"]}
        Triggered At: #{incident["triggered_at"]}
  
        === THIRD PARTY STATUS ===
        #{all_operational ? "All third party services are operational." : "DEGRADED SERVICES: #{down_services.map { |s| "#{s[:name]} (#{s[:description]})" }.join(", ")}"}
  
        === YOUR RESPONSE FORMAT ===
        Respond in EXACTLY this format with no deviations:
  
        CALLRAIL SEVERITY CLASSIFICATION:
        [Critical / Major / Minor / Not An Incident]
        [One sentence explaining which definition this matches and why]
  
        INCIDENT TYPE:
        [Production Incident / High-Severity Bug / Low-Severity Bug / False Alarm]
        [One sentence explaining the classification]
  
        WHAT BROKE:
        [One clear sentence]
  
        IS THIS US OR THEM:
        [If a third party is down name it explicitly. Otherwise say this appears to be an internal issue.]
  
        STEP BY STEP - WHAT TO DO RIGHT NOW:
        1. [Exact CallRail tool] -> [Exact menu path] -> [Exactly what to look for]
        2. [Exact CallRail tool] -> [Exact menu path] -> [Exactly what to look for]
        3. [Exact CallRail tool] -> [Exact menu path] -> [Exactly what to look for]
        4. [Exact CallRail tool] -> [Exact menu path] -> [Exactly what to look for]
        5. [Exact CallRail tool] -> [Exact menu path] -> [Exactly what to look for]
  
        ESCALATION DECISION:
        [One of: Handle alone / Involve Secondary / Wake Incident Captain NOW]
        [One sentence with the reason and specific action to take]
  
        COMMUNICATION REQUIRED:
        [What to post, to which channel, and how often based on severity]
  
        LIKELY CAUSE:
        [One sentence on the most probable root cause]
  
        RUNBOOK NOTE:
        [Check Confluence runbooks for this alert type. If none exists, write one after resolving.]
      PROMPT
  
      prompt
    end
  
  end