#!/usr/bin/env python3
"""
Complete ITSM AI Agent
Fixed memory threshold logic + ServiceNow integration with proper auth handling
"""

import os
import json
import time
import logging
import requests
import base64
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional

# LangChain imports (optional)
try:
    from langchain_openai import ChatOpenAI
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("LangChain not available, using direct OpenAI integration")

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ServiceNowClient:
    """ServiceNow API client with proper authentication"""
    
    def __init__(self, instance_url: str, username: str, password: str):
        self.instance_url = instance_url.rstrip('/')
        self.username = username
        self.password = password
        
        # Setup authentication
        auth_string = f"{username}:{password}"
        auth_bytes = auth_string.encode('ascii')
        auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
        
        self.headers = {
            'Authorization': f'Basic {auth_b64}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def test_connection(self) -> bool:
        """Test ServiceNow connection"""
        try:
            # Try to get user info first (simpler endpoint)
            url = f"{self.instance_url}/api/now/table/sys_user"
            params = {'sysparm_limit': 1, 'sysparm_fields': 'sys_id,name'}
            
            response = requests.get(url, headers=self.headers, params=params, timeout=30)
            
            if response.status_code == 200:
                logger.info("✅ ServiceNow connection successful")
                return True
            elif response.status_code == 401:
                logger.error("❌ ServiceNow authentication failed - check username/password")
                return False
            else:
                logger.warning(f"⚠️ ServiceNow responded with status {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"❌ ServiceNow connection error: {e}")
            return False
    
    def create_incident(self, data: Dict) -> Optional[Dict]:
        """Create incident ticket"""
        try:
            incident_data = {
                'short_description': data.get('title', 'AI Detected Infrastructure Issue'),
                'description': data.get('description', 'Automated incident from AI monitoring'),
                'urgency': self._map_priority(data.get('urgency', 'medium')),
                'impact': self._map_priority(data.get('impact', 'medium')),
                'category': 'Infrastructure',
                'subcategory': 'Monitoring',
                'state': '1',  # New
                'caller_id': self.username,
                'work_notes': f"Created by AI agent at {datetime.now(timezone.utc).isoformat()}\n\nTechnical Details:\n{data.get('technical_details', 'N/A')}\n\nRecommended Actions:\n{data.get('recommended_actions', 'Investigate and resolve')}"
            }
            
            url = f"{self.instance_url}/api/now/table/incident"
            response = requests.post(url, headers=self.headers, json=incident_data, timeout=30)
            response.raise_for_status()
            
            result = response.json()['result']
            return {
                'number': result.get('number'),
                'sys_id': result.get('sys_id'),
                'status': 'created'
            }
            
        except Exception as e:
            logger.error(f"Failed to create incident: {e}")
            return None
    
    def search_incidents(self, query: str, limit: int = 5) -> List[Dict]:
        """Search for existing incidents"""
        try:
            url = f"{self.instance_url}/api/now/table/incident"
            params = {
                'sysparm_query': query,
                'sysparm_limit': limit,
                'sysparm_fields': 'number,short_description,state,sys_created_on'
            }
            
            response = requests.get(url, headers=self.headers, params=params, timeout=30)
            response.raise_for_status()
            
            return response.json().get('result', [])
            
        except Exception as e:
            logger.error(f"Failed to search incidents: {e}")
            return []
    
    def _map_priority(self, priority: str) -> str:
        """Map priority to ServiceNow values"""
        mapping = {
            'low': '3',
            'medium': '2',
            'high': '1',
            'critical': '1'
        }
        return mapping.get(priority.lower(), '2')

class DatadogClient:
    """Datadog API client"""
    
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
    
    def get_metric(self, metric: str, minutes_back: int = 15) -> Optional[float]:
        """Get latest metric value"""
        try:
            current_time = datetime.now(timezone.utc)
            past_time = current_time - timedelta(minutes=minutes_back)
            
            url = f"{self.base_url}/api/v1/query"
            params = {
                'query': f"avg:{metric}{{*}}",
                'from': int(past_time.timestamp()),
                'to': int(current_time.timestamp())
            }
            
            response = requests.get(url, headers=self.headers, params=params, timeout=15)
            response.raise_for_status()
            
            data = response.json()
            series = data.get('series', [])
            
            if series and series[0].get('pointlist'):
                return series[0]['pointlist'][-1][1]  # Latest value
            
            return None
            
        except Exception as e:
            logger.error(f"Error getting metric {metric}: {e}")
            return None

class InfrastructureAnalyzer:
    """Analyze infrastructure metrics with proper thresholds"""
    
    def __init__(self):
        # Define thresholds properly
        self.thresholds = {
            'cpu_high': 85.0,           # CPU % above this is high
            'memory_low': 15.0,         # Available memory % below this is critical  
            'disk_high': 90.0,          # Disk usage % above this is high
            'load_high': 5.0            # Load average above this is high
        }
    
    def analyze_metrics(self, metrics: Dict) -> Dict:
        """Analyze metrics and identify issues"""
        issues = []
        
        # CPU Analysis
        cpu_usage = metrics.get('system.cpu.user', 0)
        if cpu_usage > self.thresholds['cpu_high']:
            issues.append({
                'metric': 'CPU Usage',
                'current_value': cpu_usage,
                'threshold': self.thresholds['cpu_high'],
                'severity': 'high' if cpu_usage > 95 else 'medium',
                'description': f'CPU usage at {cpu_usage:.1f}% (threshold: {self.thresholds["cpu_high"]}%)',
                'impact': 'Performance degradation, possible service slowdown',
                'actions': 'Identify CPU-intensive processes, consider scaling or optimization'
            })
        
        # Memory Analysis (FIXED LOGIC)
        memory_available = metrics.get('system.mem.pct_usable', 100)  # % available
        if memory_available < self.thresholds['memory_low']:
            memory_used = 100 - memory_available
            issues.append({
                'metric': 'Memory Usage',
                'current_value': memory_used,
                'threshold': 100 - self.thresholds['memory_low'],
                'severity': 'critical' if memory_available < 5 else 'high',
                'description': f'Memory usage at {memory_used:.1f}% (only {memory_available:.1f}% available)',
                'impact': 'Risk of application crashes, system instability, OOM kills',
                'actions': 'Investigate memory leaks, restart high-memory processes, scale memory'
            })
        
        # Disk Analysis  
        disk_usage = metrics.get('system.disk.in_use', 0) * 100  # Convert to percentage
        if disk_usage > self.thresholds['disk_high']:
            issues.append({
                'metric': 'Disk Usage',
                'current_value': disk_usage,
                'threshold': self.thresholds['disk_high'],
                'severity': 'critical' if disk_usage > 95 else 'medium',
                'description': f'Disk usage at {disk_usage:.1f}% (threshold: {self.thresholds["disk_high"]}%)',
                'impact': 'Risk of disk full, application failures, log rotation issues',
                'actions': 'Clean up old files, expand disk space, investigate disk usage'
            })
        
        # Load Analysis
        load_avg = metrics.get('system.load.1', 0)
        if load_avg > self.thresholds['load_high']:
            issues.append({
                'metric': 'System Load',
                'current_value': load_avg,
                'threshold': self.thresholds['load_high'],
                'severity': 'high' if load_avg > 10 else 'medium',
                'description': f'Load average at {load_avg:.2f} (threshold: {self.thresholds["load_high"]})',
                'impact': 'System overload, slow response times, resource contention',
                'actions': 'Identify resource-intensive processes, scale resources, load balancing'
            })
        
        return {
            'issues_found': len(issues) > 0,
            'issue_count': len(issues),
            'issues': issues,
            'highest_severity': self._get_highest_severity(issues),
            'metrics_analyzed': metrics
        }
    
    def _get_highest_severity(self, issues: List[Dict]) -> str:
        """Get highest severity from issues"""
        if not issues:
            return 'none'
        
        severity_order = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1}
        highest = max(issues, key=lambda x: severity_order.get(x.get('severity', 'low'), 1))
        return highest.get('severity', 'medium')

class ITSMAgent:
    """Complete ITSM Agent with AI analysis"""
    
    def __init__(self, servicenow_url: str, servicenow_user: str, servicenow_password: str,
                 datadog_api_key: str, datadog_app_key: str, datadog_site: str = "datadoghq.com",
                 openai_api_key: str = None, monitoring_interval: int = 600):
        
        self.servicenow = ServiceNowClient(servicenow_url, servicenow_user, servicenow_password)
        self.datadog = DatadogClient(datadog_api_key, datadog_app_key, datadog_site)
        self.analyzer = InfrastructureAnalyzer()
        self.monitoring_interval = monitoring_interval
        
        # Initialize OpenAI if available and key provided
        self.llm = None
        if openai_api_key and LANGCHAIN_AVAILABLE:
            try:
                self.llm = ChatOpenAI(
                    temperature=0.1,
                    model="gpt-4",
                    api_key=openai_api_key
                )
                logger.info("✅ OpenAI GPT-4 initialized for enhanced analysis")
            except Exception as e:
                logger.warning(f"⚠️ OpenAI initialization failed: {e}")
    
    def collect_metrics(self) -> Dict:
        """Collect current metrics from Datadog"""
        metrics = {
            'system.cpu.user': self.datadog.get_metric('system.cpu.user') or 0,
            'system.mem.pct_usable': self.datadog.get_metric('system.mem.pct_usable') or 100,
            'system.disk.in_use': self.datadog.get_metric('system.disk.in_use') or 0,
            'system.load.1': self.datadog.get_metric('system.load.1') or 0
        }
        return metrics
    
    def enhance_analysis_with_ai(self, analysis: Dict) -> Dict:
        """Enhance analysis with AI insights"""
        if not self.llm or not analysis.get('issues_found'):
            return analysis
        
        try:
            prompt = f"""
As an expert infrastructure engineer, enhance this analysis with additional insights:

Analysis: {json.dumps(analysis, indent=2)}

Provide enhanced insights in JSON format:
{{
  "root_cause_analysis": "likely root causes",
  "business_impact": "impact on business operations", 
  "escalation_needed": true/false,
  "additional_monitoring": "suggested additional metrics to monitor",
  "preventive_measures": "steps to prevent recurrence"
}}
"""
            
            response = self.llm.invoke(prompt)
            ai_insights = json.loads(response.content)
            analysis['ai_insights'] = ai_insights
            logger.info(f"🧠 AI enhanced analysis with additional insights")
            
        except Exception as e:
            logger.warning(f"⚠️ AI enhancement failed: {e}")
        
        return analysis
    
    def create_tickets_for_issues(self, analysis: Dict) -> List[Dict]:
        """Create ServiceNow tickets for identified issues"""
        created_tickets = []
        
        if not analysis.get('issues_found'):
            return created_tickets
        
        for issue in analysis.get('issues', []):
            # Check for duplicate tickets first
            search_query = f"short_descriptionLIKE{issue['metric']}"
            recent_tickets = self.servicenow.search_incidents(search_query, limit=3)
            
            # Skip if similar ticket created in last hour
            duplicate_found = False
            current_time = datetime.now(timezone.utc)
            
            for ticket in recent_tickets:
                created_time = datetime.fromisoformat(ticket.get('sys_created_on', '').replace('Z', '+00:00'))
                if (current_time - created_time).total_seconds() < 3600:  # 1 hour
                    duplicate_found = True
                    logger.info(f"⏭️ Skipping duplicate ticket for {issue['metric']} (recent: {ticket['number']})")
                    break
            
            if duplicate_found:
                continue
            
            # Create ticket data
            ai_insights = analysis.get('ai_insights', {})
            
            ticket_data = {
                'title': f"{issue['metric']} Critical Threshold Exceeded - {issue['current_value']:.1f}",
                'description': f"""
INFRASTRUCTURE ALERT - {issue['metric']} Issue Detected

CURRENT STATE:
- Metric: {issue['metric']}
- Current Value: {issue['current_value']:.2f}
- Threshold: {issue['threshold']}
- Severity: {issue['severity'].upper()}

IMPACT:
{issue['impact']}

TECHNICAL DETAILS:
{issue['description']}

RECOMMENDED ACTIONS:
{issue['actions']}

AI INSIGHTS:
- Root Cause: {ai_insights.get('root_cause_analysis', 'Analysis pending')}
- Business Impact: {ai_insights.get('business_impact', 'Assessment pending')}
- Preventive Measures: {ai_insights.get('preventive_measures', 'To be determined')}

MONITORING DATA:
{json.dumps(analysis['metrics_analyzed'], indent=2)}

This ticket was automatically created by the AI Infrastructure Monitoring Agent.
""",
                'urgency': issue['severity'],
                'impact': issue['severity'],
                'technical_details': issue['description'],
                'recommended_actions': issue['actions']
            }
            
            # Create the ticket
            ticket = self.servicenow.create_incident(ticket_data)
            if ticket:
                logger.info(f"🎫 Created incident {ticket['number']} for {issue['metric']}")
                created_tickets.append(ticket)
            else:
                logger.error(f"❌ Failed to create ticket for {issue['metric']}")
        
        return created_tickets
    
    def run_monitoring_cycle(self):
        """Run single monitoring cycle"""
        logger.info("🔍 Starting ITSM monitoring cycle...")
        
        # Collect metrics
        metrics = self.collect_metrics()
        logger.info(f"📊 Collected metrics: {metrics}")
        
        # Analyze for issues
        analysis = self.analyzer.analyze_metrics(metrics)
        
        if analysis['issues_found']:
            logger.warning(f"🚨 {analysis['issue_count']} issues detected (severity: {analysis['highest_severity']})")
            
            # Log each issue
            for issue in analysis['issues']:
                logger.warning(f"   - {issue['metric']}: {issue['current_value']:.2f} ({issue['severity']})")
            
            # Enhance with AI if available
            analysis = self.enhance_analysis_with_ai(analysis)
            
            # Create ServiceNow tickets
            created_tickets = self.create_tickets_for_issues(analysis)
            
            if created_tickets:
                logger.info(f"✅ Created {len(created_tickets)} ServiceNow tickets")
                for ticket in created_tickets:
                    logger.info(f"   🎫 {ticket['number']}")
            else:
                logger.warning("⚠️ Issues detected but no tickets created (duplicates or creation failed)")
        else:
            logger.info("✅ No issues detected - system healthy")
        
        return analysis
    
    def run_continuous_monitoring(self):
        """Run continuous monitoring"""
        logger.info(f"🚀 Starting ITSM Agent (interval: {self.monitoring_interval}s)")
        
        # Test connections
        if not self.datadog.get_metric('system.cpu.user'):
            logger.error("❌ Datadog connection failed")
            return
        logger.info("✅ Datadog connection successful")
        
        if not self.servicenow.test_connection():
            logger.error("❌ ServiceNow connection failed")
            return
        
        while True:
            try:
                self.run_monitoring_cycle()
                logger.info(f"😴 Sleeping for {self.monitoring_interval} seconds...")
                time.sleep(self.monitoring_interval)
                
            except KeyboardInterrupt:
                logger.info("🛑 Monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"💥 Error in monitoring cycle: {e}")
                time.sleep(60)

def main():
    """Main function"""
    
    # Environment variables
    servicenow_url = os.getenv('SERVICENOW_INSTANCE', 'https://dev221843.service-now.com')
    servicenow_user = os.getenv('SERVICENOW_USER')
    servicenow_password = os.getenv('SERVICENOW_PASSWORD')
    
    datadog_api_key = os.getenv('DATADOG_API_KEY')
    datadog_app_key = os.getenv('DATADOG_APP_KEY')
    datadog_site = os.getenv('DATADOG_SITE', 'datadoghq.com')
    
    openai_api_key = os.getenv('OPENAI_API_KEY')  # Optional
    monitoring_interval = int(os.getenv('MONITORING_INTERVAL', '600'))
    
    # Validate required variables
    required_vars = {
        'SERVICENOW_USER': servicenow_user,
        'SERVICENOW_PASSWORD': servicenow_password,
        'DATADOG_API_KEY': datadog_api_key,
        'DATADOG_APP_KEY': datadog_app_key
    }
    
    missing_vars = [var for var, value in required_vars.items() if not value]
    if missing_vars:
        logger.error(f"❌ Missing: {', '.join(missing_vars)}")
        print("\n📋 Required environment variables:")
        for var in required_vars:
            print(f"  - {var}")
        print("\n🔧 Optional:")
        print("  - SERVICENOW_INSTANCE (default: https://dev221843.service-now.com)")
        print("  - DATADOG_SITE (default: datadoghq.com)")
        print("  - OPENAI_API_KEY (for AI-enhanced analysis)")
        print("  - MONITORING_INTERVAL (default: 600)")
        return
    
    logger.info("🎫 Starting Complete ITSM AI Agent...")
    logger.info(f"🔗 ServiceNow: {servicenow_url}")
    logger.info(f"🤖 AI Enhancement: {'Enabled' if openai_api_key else 'Disabled'}")
    
    try:
        agent = ITSMAgent(
            servicenow_url=servicenow_url,
            servicenow_user=servicenow_user,
            servicenow_password=servicenow_password,
            datadog_api_key=datadog_api_key,
            datadog_app_key=datadog_app_key,
            datadog_site=datadog_site,
            openai_api_key=openai_api_key,
            monitoring_interval=monitoring_interval
        )
        
        agent.run_continuous_monitoring()
        
    except Exception as e:
        logger.error(f"❌ Failed to start ITSM agent: {e}")

if __name__ == "__main__":
    main()
