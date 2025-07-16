#!/usr/bin/env python3
"""
ServiceNow LangChain AI Agent
Intelligent ticket creation and management for infrastructure issues
"""

import os
import json
import time
import logging
import requests
import base64
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Any

# LangChain imports
from langchain.agents import create_react_agent, AgentExecutor
from langchain.tools import BaseTool
from langchain.prompts import PromptTemplate
from langchain_openai import ChatOpenAI
from langchain.memory import ConversationBufferWindowMemory
from langchain import hub
from pydantic import Field

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ServiceNowTool(BaseTool):
    """LangChain tool for ServiceNow operations"""
    
    name: str = "servicenow_operations"
    description: str = """ServiceNow operations tool. Use for:
    - create_incident: Create incident ticket (JSON with title, description, urgency, impact)
    - create_problem: Create problem ticket (JSON with title, description, urgency, impact) 
    - search_tickets: Search existing tickets (JSON with query parameters)
    - update_ticket: Update existing ticket (JSON with ticket_id and updates)
    - get_ticket: Get ticket details (JSON with ticket_id and table_name)
    """
    
    # ServiceNow connection parameters
    instance_url: str = Field()
    username: str = Field()
    password: str = Field()
    
    class Config:
        arbitrary_types_allowed = True
    
    def __init__(self, instance_url: str, username: str, password: str):
        super().__init__(instance_url=instance_url, username=username, password=password)
        # Set up authentication
        auth_string = f"{username}:{password}"
        auth_bytes = auth_string.encode('ascii')
        auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
        
        object.__setattr__(self, 'headers', {
            'Authorization': f'Basic {auth_b64}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
    
    def _run(self, query: str) -> str:
        """Execute ServiceNow operations"""
        try:
            operation_data = json.loads(query)
            operation = operation_data.get('operation')
            
            if operation == 'create_incident':
                return self._create_incident(operation_data)
            elif operation == 'create_problem':
                return self._create_problem(operation_data)
            elif operation == 'search_tickets':
                return self._search_tickets(operation_data)
            elif operation == 'update_ticket':
                return self._update_ticket(operation_data)
            elif operation == 'get_ticket':
                return self._get_ticket(operation_data)
            else:
                return f"Unknown operation: {operation}"
                
        except json.JSONDecodeError:
            return "Error: Input must be valid JSON"
        except Exception as e:
            return f"ServiceNow operation failed: {str(e)}"
    
    def _create_incident(self, data: Dict) -> str:
        """Create an incident ticket"""
        try:
            incident_data = {
                'short_description': data.get('title', 'Infrastructure Issue Detected'),
                'description': data.get('description', 'Automated incident from AI monitoring'),
                'urgency': self._map_urgency(data.get('urgency', 'medium')),
                'impact': self._map_impact(data.get('impact', 'medium')),
                'category': data.get('category', 'Infrastructure'),
                'subcategory': data.get('subcategory', 'Monitoring'),
                'caller_id': data.get('caller_id', ''),
                'assignment_group': data.get('assignment_group', ''),
                'state': '1',  # New
                'source': 'AI Monitoring Agent',
                'u_ai_generated': 'true',
                'u_monitoring_source': data.get('monitoring_source', 'Datadog'),
                'work_notes': f"Ticket created by AI agent at {datetime.now(timezone.utc).isoformat()}"
            }
            
            # Add custom fields if provided
            custom_fields = data.get('custom_fields', {})
            incident_data.update(custom_fields)
            
            url = f"{self.instance_url}/api/now/table/incident"
            response = requests.post(url, headers=self.headers, json=incident_data, timeout=30)
            response.raise_for_status()
            
            result = response.json()['result']
            ticket_number = result.get('number')
            sys_id = result.get('sys_id')
            
            return json.dumps({
                'status': 'success',
                'ticket_number': ticket_number,
                'sys_id': sys_id,
                'message': f'Incident {ticket_number} created successfully',
                'url': f"{self.instance_url}/nav_to.do?uri=incident.do?sys_id={sys_id}"
            }, indent=2)
            
        except Exception as e:
            logger.error(f"Failed to create incident: {e}")
            return f"Failed to create incident: {str(e)}"
    
    def _create_problem(self, data: Dict) -> str:
        """Create a problem ticket"""
        try:
            problem_data = {
                'short_description': data.get('title', 'Infrastructure Problem Detected'),
                'description': data.get('description', 'Automated problem from AI monitoring'),
                'urgency': self._map_urgency(data.get('urgency', 'medium')),
                'impact': self._map_impact(data.get('impact', 'medium')),
                'category': data.get('category', 'Infrastructure'),
                'subcategory': data.get('subcategory', 'Monitoring'),
                'assignment_group': data.get('assignment_group', ''),
                'state': '1',  # New
                'source': 'AI Monitoring Agent',
                'u_ai_generated': 'true',
                'u_monitoring_source': data.get('monitoring_source', 'Datadog'),
                'work_notes': f"Problem created by AI agent at {datetime.now(timezone.utc).isoformat()}"
            }
            
            # Add related incidents if provided
            if data.get('related_incidents'):
                problem_data['u_related_incidents'] = ', '.join(data['related_incidents'])
            
            custom_fields = data.get('custom_fields', {})
            problem_data.update(custom_fields)
            
            url = f"{self.instance_url}/api/now/table/problem"
            response = requests.post(url, headers=self.headers, json=problem_data, timeout=30)
            response.raise_for_status()
            
            result = response.json()['result']
            ticket_number = result.get('number')
            sys_id = result.get('sys_id')
            
            return json.dumps({
                'status': 'success',
                'ticket_number': ticket_number,
                'sys_id': sys_id,
                'message': f'Problem {ticket_number} created successfully',
                'url': f"{self.instance_url}/nav_to.do?uri=problem.do?sys_id={sys_id}"
            }, indent=2)
            
        except Exception as e:
            logger.error(f"Failed to create problem: {e}")
            return f"Failed to create problem: {str(e)}"
    
    def _search_tickets(self, data: Dict) -> str:
        """Search for existing tickets"""
        try:
            table = data.get('table', 'incident')
            query = data.get('query', '')
            limit = data.get('limit', 10)
            
            url = f"{self.instance_url}/api/now/table/{table}"
            params = {
                'sysparm_query': query,
                'sysparm_limit': limit,
                'sysparm_fields': 'number,short_description,state,urgency,impact,sys_created_on,assignment_group'
            }
            
            response = requests.get(url, headers=self.headers, params=params, timeout=30)
            response.raise_for_status()
            
            results = response.json()['result']
            
            return json.dumps({
                'status': 'success',
                'count': len(results),
                'tickets': results
            }, indent=2)
            
        except Exception as e:
            return f"Failed to search tickets: {str(e)}"
    
    def _update_ticket(self, data: Dict) -> str:
        """Update an existing ticket"""
        try:
            table = data.get('table', 'incident')
            sys_id = data.get('sys_id')
            ticket_number = data.get('ticket_number')
            updates = data.get('updates', {})
            
            if not sys_id and not ticket_number:
                return "Error: Must provide either sys_id or ticket_number"
            
            # If only ticket number provided, find sys_id
            if ticket_number and not sys_id:
                search_url = f"{self.instance_url}/api/now/table/{table}"
                search_params = {
                    'sysparm_query': f'number={ticket_number}',
                    'sysparm_fields': 'sys_id'
                }
                search_response = requests.get(search_url, headers=self.headers, params=search_params, timeout=30)
                search_response.raise_for_status()
                search_results = search_response.json()['result']
                
                if not search_results:
                    return f"Ticket {ticket_number} not found"
                
                sys_id = search_results[0]['sys_id']
            
            # Add AI work note
            if 'work_notes' not in updates:
                updates['work_notes'] = f"Updated by AI agent at {datetime.now(timezone.utc).isoformat()}"
            
            url = f"{self.instance_url}/api/now/table/{table}/{sys_id}"
            response = requests.patch(url, headers=self.headers, json=updates, timeout=30)
            response.raise_for_status()
            
            result = response.json()['result']
            
            return json.dumps({
                'status': 'success',
                'message': f'Ticket updated successfully',
                'ticket_number': result.get('number'),
                'updates': updates
            }, indent=2)
            
        except Exception as e:
            return f"Failed to update ticket: {str(e)}"
    
    def _get_ticket(self, data: Dict) -> str:
        """Get ticket details"""
        try:
            table = data.get('table', 'incident')
            sys_id = data.get('sys_id')
            ticket_number = data.get('ticket_number')
            
            if ticket_number and not sys_id:
                # Search by ticket number first
                search_url = f"{self.instance_url}/api/now/table/{table}"
                search_params = {
                    'sysparm_query': f'number={ticket_number}',
                    'sysparm_limit': 1
                }
                search_response = requests.get(search_url, headers=self.headers, params=search_params, timeout=30)
                search_response.raise_for_status()
                search_results = search_response.json()['result']
                
                if not search_results:
                    return f"Ticket {ticket_number} not found"
                
                result = search_results[0]
            else:
                # Get by sys_id
                url = f"{self.instance_url}/api/now/table/{table}/{sys_id}"
                response = requests.get(url, headers=self.headers, timeout=30)
                response.raise_for_status()
                result = response.json()['result']
            
            return json.dumps({
                'status': 'success',
                'ticket': result
            }, indent=2)
            
        except Exception as e:
            return f"Failed to get ticket: {str(e)}"
    
    def _map_urgency(self, urgency: str) -> str:
        """Map urgency levels to ServiceNow values"""
        mapping = {
            'low': '3',
            'medium': '2', 
            'high': '1',
            'critical': '1'
        }
        return mapping.get(urgency.lower(), '2')
    
    def _map_impact(self, impact: str) -> str:
        """Map impact levels to ServiceNow values"""
        mapping = {
            'low': '3',
            'medium': '2',
            'high': '1', 
            'critical': '1'
        }
        return mapping.get(impact.lower(), '2')

class DatadogMetricsTool(BaseTool):
    """Tool for querying Datadog metrics (reused from previous agent)"""
    
    name: str = "datadog_metrics"
    description: str = "Query Datadog metrics for infrastructure monitoring data"
    
    api_key: str = Field()
    app_key: str = Field()
    site: str = Field()
    
    class Config:
        arbitrary_types_allowed = True
    
    def __init__(self, api_key: str, app_key: str, site: str = "datadoghq.com"):
        super().__init__(api_key=api_key, app_key=app_key, site=site)
        object.__setattr__(self, 'base_url', f"https://api.{site}")
        object.__setattr__(self, 'headers', {
            'DD-API-KEY': api_key,
            'DD-APPLICATION-KEY': app_key,
            'Content-Type': 'application/json'
        })
    
    def _run(self, query: str) -> str:
        """Query Datadog metrics"""
        try:
            current_time = datetime.now(timezone.utc)
            past_time = current_time - timedelta(minutes=15)
            
            url = f"{self.base_url}/api/v1/query"
            params = {
                'query': f"avg:{query}{{*}}",
                'from': int(past_time.timestamp()),
                'to': int(current_time.timestamp())
            }
            
            response = requests.get(url, headers=self.headers, params=params, timeout=15)
            response.raise_for_status()
            
            data = response.json()
            series = data.get('series', [])
            
            if not series:
                return f"No data found for metric: {query}"
            
            results = []
            for serie in series:
                points = serie.get('pointlist', [])
                if points:
                    latest_value = points[-1][1]
                    results.append({
                        'metric': query,
                        'value': latest_value,
                        'scope': serie.get('scope', 'unknown')
                    })
            
            return json.dumps(results, indent=2)
            
        except Exception as e:
            return f"Error querying metric {query}: {str(e)}"

class ServiceNowAIAgent:
    """AI Agent for ServiceNow ticket management with infrastructure monitoring"""
    
    def __init__(self, servicenow_instance: str, servicenow_user: str, servicenow_password: str,
                 datadog_api_key: str, datadog_app_key: str, openai_api_key: str,
                 datadog_site: str = "datadoghq.com", monitoring_interval: int = 300):
        
        # Initialize OpenAI
        self.llm = ChatOpenAI(
            temperature=0.1,
            model="gpt-4",
            api_key=openai_api_key,
            max_tokens=1500
        )
        
        # Initialize tools
        self.servicenow_tool = ServiceNowTool(servicenow_instance, servicenow_user, servicenow_password)
        self.datadog_tool = DatadogMetricsTool(datadog_api_key, datadog_app_key, datadog_site)
        
        tools = [self.servicenow_tool, self.datadog_tool]
        
        # Create custom prompt for ServiceNow operations
        self.prompt = PromptTemplate.from_template("""
You are an expert IT Service Management AI agent specializing in ServiceNow ticket management and infrastructure monitoring.

Your capabilities:
- Monitor infrastructure metrics via Datadog
- Create incident and problem tickets in ServiceNow
- Search and update existing tickets
- Correlate monitoring data with service impact
- Provide intelligent ticket categorization and prioritization

Available tools:
- servicenow_operations: Create/search/update ServiceNow tickets
- datadog_metrics: Query infrastructure metrics

When creating tickets, always include:
- Clear, technical short description
- Detailed description with metrics and impact
- Appropriate urgency/impact based on severity
- Relevant category/subcategory
- Work notes with AI analysis

Task: {input}

Previous actions: {agent_scratchpad}
""")
        
        # Create agent
        try:
            react_prompt = hub.pull("hwchase17/react")
        except:
            react_prompt = self.prompt
        
        self.agent = create_react_agent(self.llm, tools, react_prompt)
        self.agent_executor = AgentExecutor(
            agent=self.agent,
            tools=tools,
            verbose=True,
            max_iterations=6,
            max_execution_time=120,
            handle_parsing_errors=True,
            return_intermediate_steps=True
        )
        
        self.monitoring_interval = monitoring_interval
        self.last_alert_time = {}  # Track alerts to prevent duplicates
    
    def analyze_and_create_ticket(self, metrics_data: Dict, issue_description: str = None) -> str:
        """Analyze metrics and create appropriate ServiceNow tickets"""
        
        task = f"""
Analyze the following infrastructure metrics and create appropriate ServiceNow tickets if issues are detected:

Metrics Data: {json.dumps(metrics_data, indent=2)}

Issue Description: {issue_description or "Automated monitoring detected potential issues"}

Steps to follow:
1. Analyze the metrics data to identify any issues (CPU > 85%, Memory < 15%, Disk > 90%, Load > 5.0)
2. Search ServiceNow for similar recent tickets to avoid duplicates
3. If issues found and no recent duplicate tickets exist:
   - Create incident ticket for immediate operational impact
   - Create problem ticket if this appears to be a recurring or systemic issue
4. Include detailed technical information, impact assessment, and recommended actions
5. Set appropriate urgency/impact based on severity and business impact

Provide a summary of actions taken.
"""
        
        try:
            result = self.agent_executor.invoke({"input": task})
            return result.get('output', 'No output received')
        except Exception as e:
            logger.error(f"Agent execution failed: {e}")
            return f"Failed to analyze and create ticket: {str(e)}"
    
    def create_incident_for_alert(self, alert_data: Dict) -> str:
        """Create incident ticket for PagerDuty alert"""
        
        task = f"""
Create a ServiceNow incident ticket for this PagerDuty alert:

Alert Data: {json.dumps(alert_data, indent=2)}

Requirements:
1. Extract key information from the alert (summary, severity, details)
2. Create an incident ticket with:
   - Clear technical summary
   - Detailed description including all alert details
   - Appropriate urgency/impact mapping
   - Category: Infrastructure, Subcategory: Monitoring
3. Include the PagerDuty incident ID and alert source in custom fields
4. Set work notes explaining this was created from a PagerDuty alert

Return the created ticket number and details.
"""
        
        try:
            result = self.agent_executor.invoke({"input": task})
            return result.get('output', 'No output received')
        except Exception as e:
            logger.error(f"Failed to create incident for alert: {e}")
            return f"Failed to create incident: {str(e)}"
    
    def run_monitoring_cycle(self):
        """Run monitoring cycle and create tickets for issues"""
        logger.info("🎫 Starting ServiceNow AI monitoring cycle...")
        
        # Collect key metrics
        metrics = ['system.cpu.user', 'system.mem.pct_usable', 'system.disk.in_use', 'system.load.1']
        metrics_data = {}
        
        for metric in metrics:
            result = self.datadog_tool._run(metric)
            try:
                parsed_result = json.loads(result)
                if isinstance(parsed_result, list) and parsed_result:
                    metrics_data[metric] = parsed_result[0].get('value', 0)
                else:
                    metrics_data[metric] = 0
            except:
                metrics_data[metric] = 0
        
        logger.info(f"📊 Collected metrics: {metrics_data}")
        
        # Analyze and create tickets if needed
        result = self.analyze_and_create_ticket(metrics_data)
        logger.info(f"🧠 AI Analysis Result: {result}")
    
    def run_continuous_monitoring(self):
        """Run continuous monitoring with ServiceNow integration"""
        logger.info(f"🚀 Starting ServiceNow AI monitoring (interval: {self.monitoring_interval}s)")
        
        # Test connections
        test_result = self.datadog_tool._run("system.cpu.user")
        if "Error" not in test_result:
            logger.info("✅ Datadog connection successful")
        else:
            logger.error("❌ Datadog connection failed")
            return
        
        # Test ServiceNow connection
        try:
            test_snow = self.servicenow_tool._run(json.dumps({
                "operation": "search_tickets",
                "table": "incident",
                "query": "state=1",
                "limit": 1
            }))
            if "success" in test_snow:
                logger.info("✅ ServiceNow connection successful")
            else:
                logger.warning(f"⚠️ ServiceNow test: {test_snow}")
        except Exception as e:
            logger.error(f"❌ ServiceNow connection failed: {e}")
        
        while True:
            try:
                self.run_monitoring_cycle()
                logger.info(f"😴 Sleeping for {self.monitoring_interval} seconds...")
                time.sleep(self.monitoring_interval)
                
            except KeyboardInterrupt:
                logger.info("🛑 ServiceNow monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"💥 Error in monitoring cycle: {e}")
                time.sleep(60)

def main():
    """Main function"""
    
    # Get environment variables
    servicenow_instance = os.getenv('SERVICENOW_INSTANCE', 'https://dev221843.service-now.com')
    servicenow_user = os.getenv('SERVICENOW_USER')
    servicenow_password = os.getenv('SERVICENOW_PASSWORD')
    
    datadog_api_key = os.getenv('DATADOG_API_KEY')
    datadog_app_key = os.getenv('DATADOG_APP_KEY') 
    datadog_site = os.getenv('DATADOG_SITE', 'datadoghq.com')
    
    openai_api_key = os.getenv('OPENAI_API_KEY')
    monitoring_interval = int(os.getenv('MONITORING_INTERVAL', '600'))  # 10 minutes default for tickets
    
    # Validate required variables
    required_vars = {
        'SERVICENOW_USER': servicenow_user,
        'SERVICENOW_PASSWORD': servicenow_password,
        'DATADOG_API_KEY': datadog_api_key,
        'DATADOG_APP_KEY': datadog_app_key,
        'OPENAI_API_KEY': openai_api_key
    }
    
    missing_vars = [var for var, value in required_vars.items() if not value]
    if missing_vars:
        logger.error(f"❌ Missing required environment variables: {', '.join(missing_vars)}")
        print("\n📋 Required environment variables:")
        for var in required_vars:
            print(f"  - {var}")
        print("\n🔧 Optional:")
        print("  - SERVICENOW_INSTANCE (default: https://dev221843.service-now.com)")
        print("  - DATADOG_SITE (default: datadoghq.com)")
        print("  - MONITORING_INTERVAL (default: 600)")
        print("\n💡 Example setup:")
        print("export SERVICENOW_USER='your_username'")
        print("export SERVICENOW_PASSWORD='your_password'")
        return
    
    logger.info("🎫 Starting ServiceNow AI Agent with OpenAI GPT-4...")
    logger.info(f"🔗 ServiceNow Instance: {servicenow_instance}")
    
    try:
        agent = ServiceNowAIAgent(
            servicenow_instance=servicenow_instance,
            servicenow_user=servicenow_user,
            servicenow_password=servicenow_password,
            datadog_api_key=datadog_api_key,
            datadog_app_key=datadog_app_key,
            openai_api_key=openai_api_key,
            datadog_site=datadog_site,
            monitoring_interval=monitoring_interval
        )
        
        agent.run_continuous_monitoring()
        
    except Exception as e:
        logger.error(f"❌ Failed to start ServiceNow agent: {e}")

if __name__ == "__main__":
    main()
