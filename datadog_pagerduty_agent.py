import os
import json
import time
import logging
import requests
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
import re
from dataclasses import dataclass
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class Severity(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

@dataclass
class IncidentPattern:
    """Defines patterns that indicate major incidents"""
    name: str
    pattern: str
    severity: Severity
    description: str

class DatadogClient:
    """Client for interacting with Datadog API"""
    
    def __init__(self, api_key: str, app_key: str, site: str = "datadoghq.com"):
        self.api_key = api_key
        self.app_key = app_key
        self.site = site
        self.base_url = f"https://api.{site}"
        self.headers = {
            'DD-API-KEY': api_key,
            'DD-APPLICATION-KEY': app_key,
            'Content-Type': 'application/json'
        }
    
    def test_connection(self) -> bool:
        """Test the Datadog API connection"""
        url = f"{self.base_url}/api/v1/validate"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            logger.info("Datadog API connection successful")
            return True
        except requests.RequestException as e:
            logger.error(f"Datadog API connection failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response content: {e.response.text}")
            return False

    def get_log_indexes(self) -> List[str]:
        """Get available log indexes"""
        url = f"{self.base_url}/api/v1/logs/config/indexes"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            indexes = response.json().get('indexes', [])
            return [idx.get('name') for idx in indexes if idx.get('name')]
        except requests.RequestException as e:
            logger.error(f"Error getting log indexes: {e}")
            return ['*']  # Default fallback

    def search_logs(self, query: str, from_time: datetime, to_time: datetime, limit: int = 100) -> List[Dict]:
        """Search logs using Datadog Logs API v2"""
        url = f"{self.base_url}/api/v2/logs/events/search"
        
        # Get available indexes
        indexes = self.get_log_indexes()
        if not indexes:
            indexes = ['*']
        
        # Convert to milliseconds since epoch for Datadog API
        from_ms = int(from_time.timestamp() * 1000)
        to_ms = int(to_time.timestamp() * 1000)
        
        payload = {
            "filter": {
                "query": query,
                "from": from_ms,
                "to": to_ms,
                "indexes": indexes[:5]  # Limit to first 5 indexes to avoid errors
            },
            "sort": "-timestamp",
            "page": {
                "limit": limit
            }
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return data.get('data', [])
        except requests.RequestException as e:
            logger.error(f"Error searching Datadog logs: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response content: {e.response.text}")
            
            # Fallback: try with simpler query
            if 'invalid_argument' in str(e) and 'indexes' in str(e):
                logger.info("Retrying with simplified index configuration...")
                return self._search_logs_fallback(query, from_time, to_time, limit)
            return []
    
    def _search_logs_fallback(self, query: str, from_time: datetime, to_time: datetime, limit: int = 100) -> List[Dict]:
        """Fallback log search without specific indexes"""
        url = f"{self.base_url}/api/v2/logs/events/search"
        
        from_ms = int(from_time.timestamp() * 1000)
        to_ms = int(to_time.timestamp() * 1000)
        
        payload = {
            "filter": {
                "query": query,
                "from": from_ms,
                "to": to_ms
            },
            "sort": "-timestamp",
            "page": {
                "limit": limit
            }
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return data.get('data', [])
        except requests.RequestException as e:
            logger.error(f"Fallback log search also failed: {e}")
            return []

class PagerDutyClient:
    """Client for interacting with PagerDuty API"""
    
    def __init__(self, integration_key: str, api_token: str = None):
        self.integration_key = integration_key
        self.api_token = api_token
        self.events_url = "https://events.pagerduty.com/v2/enqueue"
        self.api_url = "https://api.pagerduty.com"
    
    def trigger_alert(self, summary: str, source: str, severity: str, 
                     custom_details: Dict = None, dedup_key: str = None) -> bool:
        """Trigger a PagerDuty alert"""
        payload = {
            "routing_key": self.integration_key,
            "event_action": "trigger",
            "payload": {
                "summary": summary,
                "source": source,
                "severity": severity,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "custom_details": custom_details or {}
            }
        }
        
        if dedup_key:
            payload["dedup_key"] = dedup_key
        
        try:
            response = requests.post(self.events_url, json=payload)
            response.raise_for_status()
            logger.info(f"PagerDuty alert triggered successfully: {response.json()}")
            return True
        except requests.RequestException as e:
            logger.error(f"Error triggering PagerDuty alert: {e}")
            return False

class IncidentAnalyzer:
    """AI-powered incident analyzer using pattern matching and severity assessment"""
    
    def __init__(self):
        self.incident_patterns = [
            IncidentPattern(
                name="Database Connection Failure",
                pattern=r"(database|db|mysql|postgres|mongodb).*(connection|connect).*(failed|error|timeout)",
                severity=Severity.CRITICAL,
                description="Database connectivity issues"
            ),
            IncidentPattern(
                name="High Error Rate",
                pattern=r"(error rate|exception rate|failure rate).*(high|spike|increased|above)",
                severity=Severity.HIGH,
                description="Elevated error rates detected"
            ),
            IncidentPattern(
                name="Memory Issues",
                pattern=r"(memory|ram|heap).*(exhausted|full|high|leak|out of memory|oom)",
                severity=Severity.CRITICAL,
                description="Memory-related issues"
            ),
            IncidentPattern(
                name="Service Unavailable",
                pattern=r"(service|api|endpoint).*(unavailable|down|timeout|unreachable)",
                severity=Severity.CRITICAL,
                description="Service availability issues"
            ),
            IncidentPattern(
                name="CPU Spike",
                pattern=r"(cpu|processor).*(high|spike|100%|overload|throttling)",
                severity=Severity.HIGH,
                description="CPU utilization issues"
            ),
            IncidentPattern(
                name="Disk Space",
                pattern=r"(disk|storage|filesystem).*(full|low|space|no space)",
                severity=Severity.HIGH,
                description="Disk space issues"
            ),
            IncidentPattern(
                name="Network Issues",
                pattern=r"(network|connection|socket).*(timeout|reset|refused|unreachable)",
                severity=Severity.MEDIUM,
                description="Network connectivity problems"
            ),
            IncidentPattern(
                name="Security Alert",
                pattern=r"(security|auth|unauthorized|breach|attack|intrusion|suspicious)",
                severity=Severity.CRITICAL,
                description="Security-related incident"
            )
        ]
    
    def analyze_log_entry(self, log_entry: Dict) -> Optional[Dict]:
        """Analyze a single log entry for incident patterns"""
        # Handle both v1 and v2 API response formats
        if 'attributes' in log_entry:
            # V2 API format
            message = log_entry.get('attributes', {}).get('message', '').lower()
        else:
            # V1 API format or simplified format
            message = log_entry.get('message', '').lower()
        
        for pattern in self.incident_patterns:
            if re.search(pattern.pattern, message, re.IGNORECASE):
                return {
                    'pattern_name': pattern.name,
                    'severity': pattern.severity,
                    'description': pattern.description,
                    'log_entry': log_entry,
                    'matched_text': message
                }
        
        return None
    
    def assess_incident_severity(self, incidents: List[Dict]) -> Severity:
        """Assess overall incident severity based on multiple incidents"""
        if not incidents:
            return Severity.LOW
        
        severity_scores = {
            Severity.LOW: 1,
            Severity.MEDIUM: 2,
            Severity.HIGH: 3,
            Severity.CRITICAL: 4
        }
        
        max_severity = max(incident['severity'] for incident in incidents)
        incident_count = len(incidents)
        
        # Escalate severity if multiple incidents detected
        if incident_count > 5 and max_severity.value != Severity.CRITICAL.value:
            return Severity.CRITICAL
        elif incident_count > 3 and max_severity.value == Severity.MEDIUM.value:
            return Severity.HIGH
        
        return max_severity

class DatadogPagerDutyAgent:
    """Main AI agent for monitoring Datadog and triggering PagerDuty alerts"""
    
    def __init__(self, datadog_api_key: str, datadog_app_key: str, 
                 pagerduty_integration_key: str, monitoring_interval: int = 300,
                 datadog_site: str = "datadoghq.com"):
        self.datadog_client = DatadogClient(datadog_api_key, datadog_app_key, datadog_site)
        self.pagerduty_client = PagerDutyClient(pagerduty_integration_key)
        self.analyzer = IncidentAnalyzer()
        self.monitoring_interval = monitoring_interval
        self.last_check = datetime.now(timezone.utc) - timedelta(minutes=5)
        self.alerted_incidents = set()  # Track already alerted incidents
    
    def monitor_logs(self, query: str = "*") -> List[Dict]:
        """Monitor Datadog logs for incidents"""
        current_time = datetime.now(timezone.utc)
        
        # Search logs from last check to now
        logs = self.datadog_client.search_logs(
            query=query,
            from_time=self.last_check,
            to_time=current_time,
            limit=1000
        )
        
        self.last_check = current_time
        return logs
    
    def process_incidents(self, logs: List[Dict]) -> List[Dict]:
        """Process logs and identify incidents"""
        incidents = []
        
        for log in logs:
            incident = self.analyzer.analyze_log_entry(log)
            if incident:
                incidents.append(incident)
        
        return incidents
    
    def should_alert(self, incidents: List[Dict]) -> bool:
        """Determine if an alert should be triggered"""
        if not incidents:
            return False
        
        # Check if we've already alerted for similar incidents recently
        incident_signature = self.generate_incident_signature(incidents)
        if incident_signature in self.alerted_incidents:
            return False
        
        # Alert for high severity incidents or multiple incidents
        severity = self.analyzer.assess_incident_severity(incidents)
        return severity in [Severity.HIGH, Severity.CRITICAL] or len(incidents) > 3
    
    def generate_incident_signature(self, incidents: List[Dict]) -> str:
        """Generate a unique signature for incident deduplication"""
        pattern_names = sorted(set(incident['pattern_name'] for incident in incidents))
        return f"{'-'.join(pattern_names)}-{datetime.now(timezone.utc).strftime('%Y%m%d%H')}"
    
    def create_alert_summary(self, incidents: List[Dict]) -> str:
        """Create a summary for the PagerDuty alert"""
        severity = self.analyzer.assess_incident_severity(incidents)
        incident_count = len(incidents)
        
        pattern_counts = {}
        for incident in incidents:
            pattern_name = incident['pattern_name']
            pattern_counts[pattern_name] = pattern_counts.get(pattern_name, 0) + 1
        
        summary_parts = [f"[{severity.value.upper()}] {incident_count} incidents detected"]
        
        for pattern, count in pattern_counts.items():
            summary_parts.append(f"{pattern}: {count}")
        
        return " | ".join(summary_parts)
    
    def run_monitoring_cycle(self, log_query: str = "*"):
        """Run a single monitoring cycle"""
        logger.info("Starting monitoring cycle...")
        
        # Monitor logs
        logs = self.monitor_logs(log_query)
        logger.info(f"Retrieved {len(logs)} log entries")
        
        # Process incidents
        incidents = self.process_incidents(logs)
        logger.info(f"Identified {len(incidents)} potential incidents")
        
        # Trigger alert if necessary
        if self.should_alert(incidents):
            incident_signature = self.generate_incident_signature(incidents)
            summary = self.create_alert_summary(incidents)
            
            # Prepare custom details
            custom_details = {
                'incident_count': len(incidents),
                'incident_patterns': [incident['pattern_name'] for incident in incidents],
                'severity': self.analyzer.assess_incident_severity(incidents).value,
                'detection_time': datetime.now(timezone.utc).isoformat()
            }
            
            # Trigger PagerDuty alert
            success = self.pagerduty_client.trigger_alert(
                summary=summary,
                source="Datadog AI Agent",
                severity=self.analyzer.assess_incident_severity(incidents).value,
                custom_details=custom_details,
                dedup_key=incident_signature
            )
            
            if success:
                self.alerted_incidents.add(incident_signature)
                logger.info(f"Alert triggered for incident: {summary}")
            else:
                logger.error("Failed to trigger alert")
        
        logger.info("Monitoring cycle completed")
    
    def run_continuous_monitoring(self, log_query: str = "*"):
        """Run continuous monitoring"""
        logger.info(f"Starting continuous monitoring with {self.monitoring_interval}s interval...")
        
        # Test connections before starting
        if not self.datadog_client.test_connection():
            logger.error("Datadog connection failed. Please check your API keys and permissions.")
            return
        
        while True:
            try:
                self.run_monitoring_cycle(log_query)
                time.sleep(self.monitoring_interval)
            except KeyboardInterrupt:
                logger.info("Monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in monitoring cycle: {e}")
                time.sleep(60)  # Wait before retrying

def main():
    """Main function to run the AI agent"""
    # Configuration from environment variables
    datadog_api_key = os.getenv('DATADOG_API_KEY')
    datadog_app_key = os.getenv('DATADOG_APP_KEY')
    datadog_site = os.getenv('DATADOG_SITE', 'datadoghq.com')
    pagerduty_integration_key = os.getenv('PAGERDUTY_INTEGRATION_KEY')
    monitoring_interval = int(os.getenv('MONITORING_INTERVAL', '300'))  # 5 minutes default
    
    if not all([datadog_api_key, datadog_app_key, pagerduty_integration_key]):
        logger.error("Missing required environment variables")
        print("Required environment variables:")
        print("- DATADOG_API_KEY")
        print("- DATADOG_APP_KEY") 
        print("- PAGERDUTY_INTEGRATION_KEY")
        print("Optional:")
        print("- DATADOG_SITE (default: datadoghq.com)")
        print("- MONITORING_INTERVAL (default: 300)")
        print("- LOG_QUERY (default: *)")
        return
    
    logger.info(f"Using Datadog site: {datadog_site}")
    
    # Initialize and run the agent
    agent = DatadogPagerDutyAgent(
        datadog_api_key=datadog_api_key,
        datadog_app_key=datadog_app_key,
        pagerduty_integration_key=pagerduty_integration_key,
        monitoring_interval=monitoring_interval,
        datadog_site=datadog_site
    )
    
    # Custom log query (optional)
    log_query = os.getenv('LOG_QUERY', '*')
    
    # Run continuous monitoring
    agent.run_continuous_monitoring(log_query)

if __name__ == "__main__":
    main()
