# app/controllers/api/v1/incidents_controller.rb

module Api
    module V1
      class IncidentsController < ApplicationController
  
        # POST /api/v1/incidents
        # receives a simulated PagerDuty alert and kicks off the analysis pipeline
        def create
          # extract the incident details from the request body
          incident = incident_params
  
          # queue the analysis job — we don't process inline
          # the API responds immediately, analysis happens in the background
          IncidentAnalysisJob.perform_later(incident.to_h)
  
          # return 202 Accepted — not 201 Created
          # 202 means "we received it and will process it asynchronously"
          render json: {
            message: "Incident received and queued for analysis",
            incident_id: incident[:id],
            status: "queued"
          }, status: :accepted
        end
  
        private
  
        def incident_params
          # whitelist exactly what fields we accept from a PagerDuty-style alert
          params.require(:incident).permit(
            :id,                  # PagerDuty incident ID
            :title,               # short description of what fired
            :severity,            # critical / high / low
            :service,             # which service triggered it e.g. sidekiq-worker
            :alert_type,          # dead_queue / high_error_rate / latency etc.
            :description,         # full alert body
            :runbook_url,         # link to existing runbook if one exists
            :triggered_at         # when the alert fired
          )
        end
  
      end
    end
  end