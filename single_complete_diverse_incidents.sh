#!/bin/bash

# =============================================================================
# AI Monitoring System - Complete Diverse Incidents Enhancement
# Single File - Complete Implementation
# =============================================================================
# This script adds 24 different incident scenarios with specialized agent behaviors
# Transforms the system from showing the same incident to diverse operational scenarios
# =============================================================================

echo "🚨 COMPLETE DIVERSE INCIDENTS ENHANCEMENT"
echo "========================================"
echo "Adding 24 incident types with specialized AI agent behaviors"
echo ""

# Create backup
echo "💾 Creating backup of existing files..."
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp src/main.py "$BACKUP_DIR/main.py.backup" 2>/dev/null || echo "No existing main.py to backup"
cp frontend/src/App.js "$BACKUP_DIR/App.js.backup" 2>/dev/null || echo "No existing App.js to backup"

# Create enhanced main.py with 24 diverse incident scenarios
echo "🔧 Creating enhanced main.py with 24 incident types..."

cat > src/main.py << 'EOF_MAIN_PY'
"""
Enhanced AI-Powered IT Operations Monitoring System
Real-time workflow execution with 24 diverse incident scenarios
"""
import os
import asyncio
import json
import time
import uuid
import logging
import sys
import random
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from enum import Enum
from dataclasses import dataclass, field
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Setup logging
logs_dir = Path("logs")
logs_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(logs_dir / "app.log")
    ]
)
logger = logging.getLogger(__name__)

class AgentStatus(Enum):
    IDLE = "idle"
    RUNNING = "running"
    SUCCESS = "success"
    ERROR = "error"
    WAITING = "waiting"

class IncidentSeverity(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

@dataclass
class AgentExecution:
    agent_id: str
    agent_name: str
    execution_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    incident_id: str = ""
    status: AgentStatus = AgentStatus.IDLE
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    progress: int = 0
    logs: List[Dict[str, Any]] = field(default_factory=list)
    input_data: Dict[str, Any] = field(default_factory=dict)
    output_data: Dict[str, Any] = field(default_factory=dict)
    error_message: str = ""
    duration_seconds: float = 0.0

@dataclass
class Incident:
    id: str = field(default_factory=lambda: f"INC-{int(time.time())}")
    title: str = ""
    description: str = ""
    severity: IncidentSeverity = IncidentSeverity.MEDIUM
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    status: str = "open"
    affected_systems: List[str] = field(default_factory=list)
    workflow_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    workflow_status: str = "in_progress"
    current_agent: str = ""
    completed_agents: List[str] = field(default_factory=list)
    failed_agents: List[str] = field(default_factory=list)
    executions: Dict[str, AgentExecution] = field(default_factory=dict)
    root_cause: str = ""
    resolution: str = ""
    pagerduty_incident_id: str = ""
    servicenow_ticket_id: str = ""
    remediation_applied: List[str] = field(default_factory=list)
    incident_type: str = ""

# 24 Diverse incident scenarios database
INCIDENT_SCENARIOS = [
    {
        "title": "Database Connection Pool Exhaustion - Production MySQL",
        "description": "Production MySQL database experiencing connection pool exhaustion with applications unable to establish new connections. Current connections: 500/500.",
        "severity": "critical",
        "affected_systems": ["mysql-prod-01", "mysql-prod-02", "app-servers-pool"],
        "incident_type": "database",
        "root_cause": "Connection pool exhaustion due to long-running queries and insufficient connection cleanup",
        "monitoring_data": {"connection_count": 500, "slow_queries": 45, "cpu": "85%", "memory": "78%"}
    },
    {
        "title": "DDoS Attack Detected - Main Web Application",
        "description": "Distributed Denial of Service attack targeting main web application. Traffic spike: 50,000 requests/second from multiple IP ranges.",
        "severity": "critical",
        "affected_systems": ["web-app-prod", "load-balancer-01", "cdn-endpoints"],
        "incident_type": "security",
        "root_cause": "Coordinated DDoS attack using botnet across multiple geographic regions",
        "monitoring_data": {"request_rate": "50k/sec", "error_rate": "78%", "blocked_ips": 15420}
    },
    {
        "title": "Redis Cache Cluster Memory Exhaustion",
        "description": "Redis cache cluster experiencing memory exhaustion leading to cache misses and degraded application performance.",
        "severity": "high",
        "affected_systems": ["redis-cluster-01", "redis-cluster-02", "microservices-backend"],
        "incident_type": "infrastructure",
        "root_cause": "Memory leak in session data storage causing gradual memory exhaustion",
        "monitoring_data": {"memory_usage": "98%", "cache_hit_ratio": "23%", "evicted_keys": 89234}
    },
    {
        "title": "SSL Certificate Expiration - E-commerce Platform",
        "description": "SSL certificates for main e-commerce platform expired, causing browser security warnings and preventing transactions.",
        "severity": "critical",
        "affected_systems": ["ecommerce-frontend", "payment-gateway", "api-endpoints"],
        "incident_type": "security",
        "root_cause": "SSL certificate auto-renewal process failed due to DNS validation issues",
        "monitoring_data": {"expired_certs": 3, "failed_transactions": 245, "bounce_rate": "89%"}
    },
    {
        "title": "Kubernetes Pod Crash Loop - Microservices",
        "description": "Critical microservices experiencing crash loop backoff in Kubernetes cluster. Pod restart count exceeded threshold.",
        "severity": "high",
        "affected_systems": ["k8s-cluster-prod", "user-service", "order-service"],
        "incident_type": "container",
        "root_cause": "Memory limits too restrictive for current workload causing OOMKilled events",
        "monitoring_data": {"restart_count": 847, "memory_limit": "512Mi", "failed_pods": 12}
    },
    {
        "title": "Ransomware Detection - File Server Encryption",
        "description": "Ransomware activity detected on file servers. Multiple files showing .locked extension and ransom note detected.",
        "severity": "critical",
        "affected_systems": ["file-server-01", "backup-server", "shared-storage"],
        "incident_type": "security",
        "root_cause": "Ransomware infiltration through compromised email attachment and lateral movement",
        "monitoring_data": {"encrypted_files": 15678, "affected_shares": 8, "ransom_amount": "$50,000"}
    },
    {
        "title": "API Rate Limit Exceeded - Payment Integration",
        "description": "Third-party payment API rate limits exceeded causing transaction failures. 95% of payment requests failing.",
        "severity": "high",
        "affected_systems": ["payment-service", "checkout-api", "billing-system"],
        "incident_type": "api",
        "root_cause": "Inefficient API call patterns and missing request throttling mechanisms",
        "monitoring_data": {"api_calls_per_min": 10000, "rate_limit": 5000, "failed_payments": 1847}
    },
    {
        "title": "Storage Array Disk Failure - RAID Degraded",
        "description": "Storage array experiencing multiple disk failures. RAID 5 array in degraded state with 2 out of 8 disks failed.",
        "severity": "critical",
        "affected_systems": ["storage-array-01", "database-volumes", "vm-datastores"],
        "incident_type": "storage",
        "root_cause": "Hardware failure due to disk age and excessive wear from high I/O workloads",
        "monitoring_data": {"failed_disks": 2, "total_disks": 8, "array_status": "Degraded"}
    },
    {
        "title": "Network Switch Stack Failure - Data Center",
        "description": "Core network switch stack failure in primary data center causing network segmentation across VLANs.",
        "severity": "critical",
        "affected_systems": ["core-switch-stack", "vlan-infrastructure", "inter-dc-links"],
        "incident_type": "network",
        "root_cause": "Switch stack master election failure due to firmware bug and split-brain condition",
        "monitoring_data": {"affected_vlans": 12, "disconnected_devices": 245, "packet_loss": "35%"}
    },
    {
        "title": "Docker Registry Corruption - Container Deployment",
        "description": "Docker registry experiencing image corruption preventing container deployments and CI/CD pipeline failures.",
        "severity": "high",
        "affected_systems": ["docker-registry", "ci-cd-pipeline", "deployment-systems"],
        "incident_type": "container",
        "root_cause": "Storage corruption in registry backend due to disk I/O errors",
        "monitoring_data": {"corrupted_images": 23, "failed_pulls": 156, "storage_errors": 89}
    },
    {
        "title": "Active Directory Domain Controller Failure",
        "description": "Primary Active Directory domain controller failure causing authentication issues across the organization.",
        "severity": "critical",
        "affected_systems": ["ad-dc-primary", "ad-dc-secondary", "domain-workstations"],
        "incident_type": "authentication",
        "root_cause": "Hardware failure on primary DC with delayed replication to secondary controllers",
        "monitoring_data": {"failed_logins": 1456, "affected_users": 890, "replication_lag": "45min"}
    },
    {
        "title": "Elasticsearch Cluster Split Brain - Search Service",
        "description": "Elasticsearch cluster experiencing split brain condition with multiple master nodes causing data conflicts.",
        "severity": "high",
        "affected_systems": ["elasticsearch-cluster", "search-api", "analytics-dashboard"],
        "incident_type": "search",
        "root_cause": "Network partition causing split brain with multiple master elections",
        "monitoring_data": {"master_nodes": 3, "cluster_status": "Red", "unassigned_shards": 45}
    },
    {
        "title": "CDN Origin Server Overload - Media Streaming",
        "description": "CDN origin servers experiencing overload during peak streaming hours. Cache miss ratio increased to 85%.",
        "severity": "high",
        "affected_systems": ["cdn-origin-servers", "media-cache", "streaming-platform"],
        "incident_type": "cdn",
        "root_cause": "CDN cache invalidation storm and insufficient origin server capacity",
        "monitoring_data": {"cache_hit_ratio": "15%", "origin_response_time": "8.5s", "concurrent_streams": 45000}
    },
    {
        "title": "Message Queue Deadlock - Event Processing",
        "description": "RabbitMQ message queue experiencing deadlock condition. Consumer processes hanging and message backlog growing.",
        "severity": "high",
        "affected_systems": ["rabbitmq-cluster", "event-processors", "notification-service"],
        "incident_type": "messaging",
        "root_cause": "Circular dependency in message processing causing deadlock condition",
        "monitoring_data": {"queue_depth": 125000, "dead_letter_count": 8934, "consumer_count": 0}
    },
    {
        "title": "Cloud Storage Bucket Misconfiguration - Data Exposure",
        "description": "AWS S3 bucket misconfiguration detected exposing sensitive customer data to public internet.",
        "severity": "critical",
        "affected_systems": ["s3-customer-data", "cloud-infrastructure", "data-pipeline"],
        "incident_type": "security",
        "root_cause": "Bucket policy misconfiguration during infrastructure automation deployment",
        "monitoring_data": {"exposed_files": 15000, "data_size": "45GB", "discovery_time": "2hours"}
    },
    {
        "title": "DNS Resolution Failure - External Services",
        "description": "DNS resolution failures for external services causing application timeouts with NXDOMAIN responses.",
        "severity": "medium",
        "affected_systems": ["dns-servers", "external-apis", "web-applications"],
        "incident_type": "dns",
        "root_cause": "DNS server configuration drift and upstream resolver connectivity issues",
        "monitoring_data": {"failed_queries": 12456, "nxdomain_rate": "45%", "affected_domains": 23}
    },
    {
        "title": "Load Balancer Health Check Failures - Web Tier",
        "description": "Load balancer health checks failing for web tier. 6 out of 10 backend servers marked as unhealthy.",
        "severity": "high",
        "affected_systems": ["load-balancer", "web-servers", "application-tier"],
        "incident_type": "loadbalancer",
        "root_cause": "Health check endpoint timeout due to database connection bottleneck",
        "monitoring_data": {"healthy_servers": 4, "total_servers": 10, "health_check_timeout": "30s"}
    },
    {
        "title": "Backup System Corruption - Data Recovery Risk",
        "description": "Backup system experiencing data corruption. Last 3 backup sets failed integrity checks with checksum mismatches.",
        "severity": "critical",
        "affected_systems": ["backup-servers", "tape-library", "backup-software"],
        "incident_type": "backup",
        "root_cause": "Storage media degradation and backup software bug causing data corruption",
        "monitoring_data": {"failed_backups": 3, "corruption_rate": "15%", "last_good_backup": "4days"}
    },
    {
        "title": "VPN Concentrator Overload - Remote Access",
        "description": "VPN concentrator experiencing connection overload during peak remote work hours with connection failures.",
        "severity": "medium",
        "affected_systems": ["vpn-concentrator", "remote-access", "authentication-server"],
        "incident_type": "vpn",
        "root_cause": "Concurrent connection limit exceeded due to increased remote work demand",
        "monitoring_data": {"active_connections": 2000, "connection_limit": 2000, "failed_attempts": 456}
    },
    {
        "title": "IoT Device Botnet Activity - Network Security",
        "description": "Suspicious botnet activity detected from IoT devices with coordinated outbound traffic to C&C servers.",
        "severity": "high",
        "affected_systems": ["iot-devices", "network-security", "firewall-systems"],
        "incident_type": "security",
        "root_cause": "IoT device firmware vulnerability exploited for botnet recruitment",
        "monitoring_data": {"infected_devices": 67, "c2_servers": 5, "outbound_traffic": "500MB/hour"}
    },
    {
        "title": "Log Aggregation System Disk Full - Monitoring",
        "description": "Log aggregation system experiencing disk space exhaustion. Log ingestion stopped and data at risk.",
        "severity": "medium",
        "affected_systems": ["log-aggregation", "elasticsearch", "monitoring-dashboard"],
        "incident_type": "monitoring",
        "root_cause": "Log retention policy misconfiguration and unexpected log volume spike",
        "monitoring_data": {"disk_usage": "98%", "log_ingestion_rate": "0MB/s", "data_at_risk": "1.2TB"}
    },
    {
        "title": "API Gateway Rate Limiting Malfunction",
        "description": "API gateway rate limiting system malfunction allowing excessive requests to saturate backend services.",
        "severity": "high",
        "affected_systems": ["api-gateway", "backend-services", "database-pool"],
        "incident_type": "api",
        "root_cause": "Rate limiting service configuration error bypassing request throttling",
        "monitoring_data": {"requests_per_second": 15000, "rate_limit_bypassed": "78%", "backend_errors": 2456}
    },
    {
        "title": "Microservice Circuit Breaker Cascade",
        "description": "Multiple microservice circuit breakers triggered simultaneously causing cascade failure across service mesh.",
        "severity": "high",
        "affected_systems": ["microservices", "service-mesh", "api-gateway"],
        "incident_type": "infrastructure",
        "root_cause": "Dependency service degradation triggering circuit breakers in cascade pattern",
        "monitoring_data": {"circuit_breakers_open": 12, "failed_requests": 45000, "cascade_depth": 4}
    },
    {
        "title": "Certificate Authority Compromise Alert",
        "description": "Internal Certificate Authority potentially compromised. Immediate certificate rotation required across infrastructure.",
        "severity": "critical",
        "affected_systems": ["internal-ca", "ssl-certificates", "security-infrastructure"],
        "incident_type": "security",
        "root_cause": "Suspected CA private key compromise detected through anomalous certificate issuance",
        "monitoring_data": {"certificates_issued": 1500, "anomalous_certs": 45, "ca_status": "Compromised"}
    }
]

class WorkflowEngine:
    def __init__(self):
        self.active_incidents: Dict[str, Incident] = {}
        self.incident_history: List[Incident] = []
        self.agent_execution_history: Dict[str, List[AgentExecution]] = {
            "monitoring": [], "rca": [], "pager": [], "ticketing": [], 
            "email": [], "remediation": [], "validation": []
        }
        
    async def trigger_incident_workflow(self, incident_data: Dict[str, Any]) -> Incident:
        # Always select a random scenario for diverse testing
        scenario = random.choice(INCIDENT_SCENARIOS)
        incident = Incident(
            title=scenario["title"],
            description=scenario["description"],
            severity=IncidentSeverity(scenario["severity"]),
            affected_systems=scenario["affected_systems"],
            incident_type=scenario["incident_type"]
        )
        logger.info(f"🎭 Selected scenario: {scenario['incident_type']} - {scenario['title']}")
        
        self.active_incidents[incident.id] = incident
        asyncio.create_task(self._execute_workflow(incident))
        return incident
    
    async def _execute_workflow(self, incident: Incident):
        workflow_steps = [
            ("monitoring", self._execute_monitoring_agent),
            ("rca", self._execute_rca_agent),
            ("pager", self._execute_pager_agent),
            ("ticketing", self._execute_ticketing_agent),
            ("email", self._execute_email_agent),
            ("remediation", self._execute_remediation_agent),
            ("validation", self._execute_validation_agent)
        ]
        
        try:
            for agent_id, agent_func in workflow_steps:
                incident.current_agent = agent_id
                incident.updated_at = datetime.now()
                
                execution = await agent_func(incident)
                incident.executions[agent_id] = execution
                self.agent_execution_history[agent_id].append(execution)
                
                if execution.status == AgentStatus.SUCCESS:
                    incident.completed_agents.append(agent_id)
                else:
                    incident.failed_agents.append(agent_id)
                
                # Variable timing based on incident complexity
                complexity_delay = {
                    "security": random.uniform(2.0, 4.0),
                    "database": random.uniform(1.5, 3.0),
                    "network": random.uniform(1.0, 2.5),
                    "container": random.uniform(0.8, 2.0),
                    "infrastructure": random.uniform(1.2, 2.8)
                }
                delay = complexity_delay.get(incident.incident_type, random.uniform(1.5, 3.0))
                await asyncio.sleep(delay)
            
            incident.workflow_status = "completed"
            incident.current_agent = ""
            incident.status = "resolved" if len(incident.failed_agents) == 0 else "partially_resolved"
            
            self.incident_history.append(incident)
            del self.active_incidents[incident.id]
            
        except Exception as e:
            incident.workflow_status = "failed"
            incident.status = "failed"
            logger.error(f"Workflow failed for incident {incident.id}: {str(e)}")
    
    def get_scenario_data(self, incident: Incident):
        """Get scenario-specific data for the incident"""
        for scenario in INCIDENT_SCENARIOS:
            if scenario["title"] == incident.title:
                return scenario
        return None
    
    async def _execute_monitoring_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(
            agent_id="monitoring", agent_name="Monitoring Agent",
            incident_id=incident.id, input_data={"systems": incident.affected_systems}
        )
        
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        scenario = self.get_scenario_data(incident)
        
        try:
            # Type-specific monitoring analysis
            if incident.incident_type == "database":
                await self._log_activity(execution, "🔍 Analyzing database connection metrics and query performance...")
                execution.progress = 20
                await asyncio.sleep(random.uniform(1.5, 2.5))
                
                await self._log_activity(execution, "📊 Collecting MySQL performance counters and slow query log...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(2.0, 3.0))
                
                await self._log_activity(execution, "📝 Correlating connection pool exhaustion with application load...")
                execution.progress = 85
                await asyncio.sleep(random.uniform(1.0, 2.0))
                
                execution.output_data = {
                    "database_connections": scenario["monitoring_data"]["connection_count"],
                    "slow_queries": scenario["monitoring_data"]["slow_queries"],
                    "cpu_usage": scenario["monitoring_data"]["cpu"],
                    "memory_usage": scenario["monitoring_data"]["memory"],
                    "anomaly_type": "connection_exhaustion",
                    "metrics_analyzed": 15420
                }
                
            elif incident.incident_type == "security":
                await self._log_activity(execution, "🚨 Initiating security threat detection and analysis...")
                execution.progress = 25
                await asyncio.sleep(random.uniform(2.0, 3.0))
                
                await self._log_activity(execution, "🔒 Correlating security events with threat intelligence feeds...")
                execution.progress = 65
                await asyncio.sleep(random.uniform(2.5, 3.5))
                
                await self._log_activity(execution, "⚠️ Analyzing attack patterns and IOC matching...")
                execution.progress = 90
                await asyncio.sleep(random.uniform(1.5, 2.0))
                
                monitoring_data = scenario["monitoring_data"]
                execution.output_data = {
                    "security_events": random.randint(10000, 50000),
                    "threat_indicators": random.randint(100, 500),
                    "blocked_ips": monitoring_data.get("blocked_ips", random.randint(1000, 20000)),
                    "attack_volume": monitoring_data.get("request_rate", "Unknown"),
                    "anomaly_type": "security_breach",
                    "threat_level": "Critical"
                }
                
            elif incident.incident_type == "network":
                await self._log_activity(execution, "🌐 Performing network topology analysis and path tracing...")
                execution.progress = 30
                await asyncio.sleep(random.uniform(1.5, 2.5))
                
                await self._log_activity(execution, "📡 Collecting SNMP metrics from network infrastructure...")
                execution.progress = 65
                await asyncio.sleep(random.uniform(2.0, 3.0))
                
                await self._log_activity(execution, "🔍 Analyzing packet loss patterns and latency distribution...")
                execution.progress = 90
                await asyncio.sleep(random.uniform(1.0, 1.5))
                
                monitoring_data = scenario["monitoring_data"]
                execution.output_data = {
                    "affected_vlans": monitoring_data.get("affected_vlans", random.randint(5, 15)),
                    "packet_loss": monitoring_data.get("packet_loss", f"{random.uniform(5, 40):.1f}%"),
                    "disconnected_devices": monitoring_data.get("disconnected_devices", random.randint(50, 300)),
                    "network_segments": len(incident.affected_systems),
                    "anomaly_type": "network_failure"
                }
                
            elif incident.incident_type == "container":
                await self._log_activity(execution, "📦 Analyzing Kubernetes cluster state and pod metrics...")
                execution.progress = 25
                await asyncio.sleep(random.uniform(1.0, 2.0))
                
                await self._log_activity(execution, "🔄 Collecting container resource utilization and restart patterns...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(1.5, 2.5))
                
                await self._log_activity(execution, "📊 Examining OOMKilled events and memory pressure...")
                execution.progress = 85
                await asyncio.sleep(random.uniform(1.0, 1.5))
                
                monitoring_data = scenario["monitoring_data"]
                execution.output_data = {
                    "restart_count": monitoring_data.get("restart_count", random.randint(100, 1000)),
                    "failed_pods": monitoring_data.get("failed_pods", random.randint(5, 20)),
                    "memory_limit": monitoring_data.get("memory_limit", "512Mi"),
                    "oom_kills": random.randint(20, 100),
                    "anomaly_type": "container_failure"
                }
                
            else:  # Infrastructure, storage, API, etc.
                await self._log_activity(execution, f"🔍 Analyzing {incident.incident_type} infrastructure metrics...")
                execution.progress = 25
                await asyncio.sleep(random.uniform(1.0, 2.0))
                
                await self._log_activity(execution, f"📊 Collecting {incident.incident_type} performance data...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(1.5, 2.5))
                
                await self._log_activity(execution, f"📝 Correlating {incident.incident_type} anomaly patterns...")
                execution.progress = 85
                await asyncio.sleep(random.uniform(1.0, 2.0))
                
                execution.output_data = {
                    "system_metrics": scenario["monitoring_data"] if scenario else {"cpu": "85%", "memory": "78%"},
                    "affected_services": len(incident.affected_systems),
                    "error_rate": f"{random.uniform(10, 50):.1f}%",
                    "anomaly_type": f"{incident.incident_type}_degradation"
                }
            
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ {incident.incident_type.title()} monitoring analysis completed - Critical metrics identified")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
            await self._log_activity(execution, f"❌ Monitoring analysis failed: {str(e)}", "ERROR")
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    async def _execute_rca_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(
            agent_id="rca", agent_name="RCA Agent", incident_id=incident.id,
            input_data=incident.executions.get("monitoring", {}).output_data or {}
        )
        
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        scenario = self.get_scenario_data(incident)
        
        try:
            await self._log_activity(execution, f"🧠 AI-powered root cause analysis for {incident.incident_type} incident...")
            execution.progress = 25
            await asyncio.sleep(random.uniform(2.0, 3.0))
            
            # Get scenario-specific root cause
            root_cause = scenario["root_cause"] if scenario else f"{incident.incident_type.title()} issue requiring investigation"
            
            if incident.incident_type == "database":
                await self._log_activity(execution, "🔍 Analyzing database query patterns, connection lifecycle, and lock contention...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(2.5, 3.5))
                
                await self._log_activity(execution, "💡 Correlating application behavior with database performance metrics...")
                
            elif incident.incident_type == "security":
                await self._log_activity(execution, "🛡️ Analyzing attack vectors, payload signatures, and threat actor TTPs...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(3.0, 4.0))
                
                await self._log_activity(execution, "🔬 Cross-referencing with global threat intelligence and MITRE ATT&CK framework...")
                
            elif incident.incident_type == "network":
                await self._log_activity(execution, "🌐 Performing network path analysis and failure point identification...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(2.0, 3.0))
                
                await self._log_activity(execution, "🔧 Analyzing network convergence times and routing table inconsistencies...")
                
            elif incident.incident_type == "container":
                await self._log_activity(execution, "📦 Examining container orchestration patterns and resource allocation...")
                execution.progress = 60
           

                await self._log_activity(execution, "🔍 Analyzing Kubernetes scheduler decisions and node capacity...")
                
            else:
                await self._log_activity(execution, f"💡 Performing deep {incident.incident_type} dependency analysis...")
                execution.progress = 60
                await asyncio.sleep(random.uniform(2.0, 3.0))
                
                await self._log_activity(execution, f"🔬 Cross-correlating {incident.incident_type} metrics with system behavior...")
            
            execution.progress = 90
            await asyncio.sleep(random.uniform(1.0, 2.0))
            
            execution.output_data = {
                "root_cause": root_cause,
                "confidence": random.uniform(0.85, 0.97),
                "incident_type": incident.incident_type,
                "analysis_depth": "comprehensive",
                "contributing_factors": self._get_contributing_factors(incident.incident_type),
                "recommended_actions": self._get_incident_actions(incident.incident_type)
            }
            
            incident.root_cause = execution.output_data["root_cause"]
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ Root cause identified: {incident.incident_type} - Confidence: {execution.output_data['confidence']:.1%}")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_contributing_factors(self, incident_type: str) -> List[str]:
        """Get incident-specific contributing factors"""
        factors = {
            "database": ["High query volume", "Insufficient connection cleanup", "Resource contention"],
            "security": ["Unpatched vulnerabilities", "Weak access controls", "Insufficient monitoring"],
            "network": ["Hardware aging", "Configuration drift", "Capacity limitations"],
            "container": ["Resource misconfiguration", "Image vulnerabilities", "Orchestration bugs"],
            "infrastructure": ["Resource exhaustion", "Dependency failures", "Configuration errors"],
            "storage": ["Hardware degradation", "I/O bottlenecks", "Capacity limits"],
            "api": ["Rate limit misconfiguration", "Backend scaling issues", "Circuit breaker failures"]
        }
        return factors.get(incident_type, ["System overload", "Configuration drift", "Resource constraints"])
    
    def _get_incident_actions(self, incident_type: str) -> List[str]:
        """Get incident-specific recommended actions"""
        actions = {
            "database": ["Scale connection pool", "Optimize slow queries", "Add read replicas", "Tune memory allocation"],
            "security": ["Isolate affected systems", "Reset compromised credentials", "Apply security patches", "Enhanced monitoring"],
            "network": ["Activate backup paths", "Replace faulty hardware", "Update routing tables", "Load balancing"],
            "container": ["Increase resource limits", "Restart failed pods", "Update container images", "Scale cluster"],
            "infrastructure": ["Scale compute resources", "Restart critical services", "Load rebalancing", "Capacity planning"],
            "storage": ["Replace failed disks", "Initiate RAID rebuild", "Data migration", "I/O optimization"],
            "api": ["Enable rate limiting", "Scale backend services", "Circuit breaker tuning", "Cache optimization"]
        }
        return actions.get(incident_type, ["Service restart", "Resource scaling", "Configuration review"])
    
    async def _execute_pager_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(agent_id="pager", agent_name="Pager Agent", incident_id=incident.id)
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        
        try:
            await self._log_activity(execution, f"📞 Creating PagerDuty alert for {incident.incident_type} incident...")
            execution.progress = 40
            await asyncio.sleep(random.uniform(1.0, 1.8))
            
            # Determine appropriate team based on incident type
            team = self._get_escalation_team(incident.incident_type, incident.severity.value)
            
            await self._log_activity(execution, f"📱 Escalating to {team} with {incident.severity.value} priority...")
            execution.progress = 80
            await asyncio.sleep(random.uniform(1.0, 1.5))
            
            execution.output_data = {
                "pagerduty_incident_id": f"PD-{incident.incident_type.upper()}-{incident.id[-6:]}",
                "escalated_to": team,
                "notification_methods": self._get_notification_methods(incident.incident_type, incident.severity.value),
                "escalation_policy": f"{incident.incident_type}_escalation",
                "on_call_engineer": self._get_on_call_engineer(incident.incident_type)
            }
            
            incident.pagerduty_incident_id = execution.output_data["pagerduty_incident_id"]
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ {team} notified - Engineer {execution.output_data['on_call_engineer']} paged")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_escalation_team(self, incident_type: str, severity: str) -> str:
        """Get appropriate escalation team based on incident type and severity"""
        teams = {
            "database": "Database Engineering",
            "security": "Security Operations Center", 
            "network": "Network Operations Team",
            "infrastructure": "Infrastructure Engineering",
            "container": "Platform Engineering",
            "storage": "Storage Engineering",
            "api": "API Platform Team",
            "dns": "Network Operations",
            "monitoring": "SRE Team",
            "backup": "Data Protection Team",
            "authentication": "Identity & Access Management",
            "search": "Search Platform Team",
            "cdn": "Content Delivery Team",
            "messaging": "Messaging Platform Team",
            "loadbalancer": "Load Balancing Team",
            "vpn": "Network Security Team"
        }
        base_team = teams.get(incident_type, "General Operations")
        
        if severity in ["critical"]:
            return f"Senior {base_team} + Management"
        elif severity == "high":
            return f"Senior {base_team}"
        return base_team
    
    def _get_notification_methods(self, incident_type: str, severity: str) -> List[str]:
        """Get notification methods based on incident type and severity"""
        base_methods = ["SMS", "Email", "PagerDuty App"]
        
        if severity == "critical":
            base_methods.extend(["Phone Call", "Slack Urgent", "Teams Alert"])
        if incident_type == "security":
            base_methods.append("Security Channel")
        
        return base_methods
    
    def _get_on_call_engineer(self, incident_type: str) -> str:
        """Get on-call engineer name based on incident type"""
        engineers = {
            "database": random.choice(["Sarah Chen", "Marcus Rodriguez", "Priya Patel"]),
            "security": random.choice(["Alex Thompson", "Jordan Kim", "Riley Foster"]),
            "network": random.choice(["David Wilson", "Maya Singh", "Chris Anderson"]),
            "infrastructure": random.choice(["Sam Parker", "Jessica Liu", "Tyler Brown"]),
            "container": random.choice(["Morgan Davis", "Casey Johnson", "Avery Taylor"]),
            "storage": random.choice(["Quinn Martinez", "Blake Cooper", "River Thompson"]),
            "api": random.choice(["Phoenix Lee", "Sage Williams", "Rowan Clark"])
        }
        return engineers.get(incident_type, random.choice(["Jamie Smith", "Taylor Jones", "Cameron Lee"]))
    
    async def _execute_ticketing_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(agent_id="ticketing", agent_name="Ticketing Agent", incident_id=incident.id)
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        
        try:
            await self._log_activity(execution, f"🎫 Creating ServiceNow ticket for {incident.incident_type} incident...")
            execution.progress = 30
            await asyncio.sleep(random.uniform(1.2, 2.0))
            
            # Get incident-specific ticket classification
            priority, category, subcategory = self._get_ticket_classification(incident.incident_type, incident.severity.value)
            
            await self._log_activity(execution, f"📝 Classifying as {priority} priority {category}...")
            execution.progress = 70
            await asyncio.sleep(random.uniform(1.0, 1.5))
            
            execution.output_data = {
                "ticket_id": f"{incident.incident_type.upper()}{datetime.now().strftime('%Y%m%d')}{incident.id[-4:]}",
                "priority": priority,
                "category": category,
                "subcategory": subcategory,
                "assigned_to": self._get_escalation_team(incident.incident_type, incident.severity.value),
                "estimated_resolution": self._get_resolution_estimate(incident.incident_type, incident.severity.value),
                "business_impact": self._get_business_impact(incident.incident_type, incident.severity.value)
            }
            
            incident.servicenow_ticket_id = execution.output_data["ticket_id"]
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ ServiceNow ticket {execution.output_data['ticket_id']} created and assigned")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_ticket_classification(self, incident_type: str, severity: str) -> tuple:
        """Get ticket priority, category, and subcategory"""
        priority_map = {
            "critical": "1 - Critical",
            "high": "2 - High", 
            "medium": "3 - Medium",
            "low": "4 - Low"
        }
        
        classifications = {
            "database": ("Database Services", "Performance Degradation"),
            "security": ("Security", "Incident Response"),
            "network": ("Network", "Connectivity Issues"),
            "infrastructure": ("Infrastructure", "System Outage"),
            "container": ("Platform Services", "Container Orchestration"),
            "storage": ("Storage", "Hardware Failure"),
            "api": ("Application Services", "API Gateway"),
            "dns": ("Network", "DNS Resolution"),
            "authentication": ("Security", "Authentication"),
            "search": ("Platform Services", "Search Engine"),
            "cdn": ("Network", "Content Delivery"),
            "messaging": ("Messaging", "Queue Management"),
            "backup": ("Data Management", "Backup Systems"),
            "vpn": ("Network", "VPN Connectivity"),
            "monitoring": ("Operations", "Monitoring Systems"),
            "loadbalancer": ("Network", "Load Balancing")
        }
        
        category, subcategory = classifications.get(incident_type, ("General", "System Issue"))
        return priority_map.get(severity, "3 - Medium"), category, subcategory
    
    def _get_resolution_estimate(self, incident_type: str, severity: str) -> str:
        """Get estimated resolution time"""
        base_estimates = {
            "database": "2-4 hours",
            "security": "4-8 hours",
            "network": "1-3 hours",
            "infrastructure": "2-6 hours", 
            "container": "1-2 hours",
            "storage": "4-12 hours",
            "api": "1-2 hours",
            "dns": "30min-2 hours",
            "authentication": "2-4 hours",
            "search": "2-6 hours",
            "cdn": "1-4 hours",
            "messaging": "1-3 hours",
            "backup": "4-24 hours",
            "vpn": "1-3 hours",
            "monitoring": "30min-2 hours",
            "loadbalancer": "1-2 hours"
        }
        
        base = base_estimates.get(incident_type, "2-4 hours")
        if severity == "critical":
            return f"{base} (expedited)"
        return base
    
    def _get_business_impact(self, incident_type: str, severity: str) -> str:
        """Get business impact description"""
        impacts = {
            "database": "Application performance degradation affecting user transactions",
            "security": "Potential data breach requiring immediate containment",
            "network": "Connectivity issues affecting multiple business services",
            "infrastructure": "System unavailability impacting business operations",
            "container": "Service deployment issues affecting application availability",
            "storage": "Data access issues with potential data loss risk",
            "api": "Integration failures affecting customer-facing services",
            "dns": "Domain resolution failures affecting web services",
            "authentication": "User login failures affecting system access",
            "search": "Search functionality degradation affecting user experience",
            "cdn": "Content delivery issues affecting website performance",
            "messaging": "Message processing delays affecting business workflows",
            "backup": "Data protection failures creating compliance risks",
            "vpn": "Remote access issues affecting workforce productivity",
            "monitoring": "Observability gaps affecting incident detection",
            "loadbalancer": "Traffic distribution issues affecting service availability"
        }
        
        base_impact = impacts.get(incident_type, "System issues affecting business operations")
        if severity == "critical":
            return f"CRITICAL: {base_impact}"
        return base_impact
    
    async def _execute_email_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(agent_id="email", agent_name="Email Agent", incident_id=incident.id)
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        
        try:
            await self._log_activity(execution, f"📧 Composing {incident.incident_type} incident notification...")
            execution.progress = 40
            await asyncio.sleep(random.uniform(1.0, 1.5))
            
            # Get incident-specific stakeholders
            stakeholders = self._get_incident_stakeholders(incident.incident_type, incident.severity.value)
            
            await self._log_activity(execution, f"📤 Sending notifications to {len(stakeholders)} stakeholder groups...")
            execution.progress = 80
            await asyncio.sleep(random.uniform(1.2, 1.8))
            
            execution.output_data = {
                "emails_sent": stakeholders,
                "notification_type": f"{incident.incident_type}_incident_alert",
                "executive_briefing": incident.severity.value in ["critical", "high"],
                "communication_plan": self._get_communication_plan(incident.incident_type),
                "update_frequency": self._get_update_frequency(incident.severity.value)
            }
            
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ Stakeholder notifications sent - {execution.output_data['update_frequency']} updates scheduled")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_incident_stakeholders(self, incident_type: str, severity: str) -> List[str]:
        """Get stakeholders to notify based on incident type and severity"""
        base_stakeholders = [f"{incident_type}-team@company.com", "it-operations@company.com"]
        
        # Add severity-based stakeholders
        if severity in ["critical", "high"]:
            base_stakeholders.extend(["management@company.com", "incident-commander@company.com"])
            
        if severity == "critical":
            base_stakeholders.extend(["cto@company.com", "executive-team@company.com"])
        
        # Add incident-type specific stakeholders
        type_stakeholders = {
            "security": ["security-team@company.com", "compliance@company.com", "legal@company.com"],
            "database": ["dba-team@company.com", "backend-developers@company.com", "data-team@company.com"],
            "network": ["network-ops@company.com", "telecom@company.com"],
            "container": ["platform-team@company.com", "devops@company.com", "sre@company.com"],
            "api": ["api-team@company.com", "integration-partners@company.com"],
            "storage": ["storage-admins@company.com", "backup-team@company.com"],
            "authentication": ["identity-team@company.com", "security@company.com"],
            "search": ["search-team@company.com", "data-platform@company.com"],
            "cdn": ["cdn-team@company.com", "web-performance@company.com"],
            "messaging": ["messaging-team@company.com", "integration@company.com"],
            "backup": ["backup-team@company.com", "data-protection@company.com"],
            "vpn": ["network-security@company.com", "remote-access@company.com"],
            "monitoring": ["sre@company.com", "observability@company.com"],
            "loadbalancer": ["network-ops@company.com", "platform@company.com"]
        }
        
        base_stakeholders.extend(type_stakeholders.get(incident_type, []))
        return list(set(base_stakeholders))  # Remove duplicates
    
    def _get_communication_plan(self, incident_type: str) -> str:
        """Get communication plan based on incident type"""
        plans = {
            "security": "Security incident communication protocol with legal review",
            "database": "Database incident communication with application teams",
            "network": "Network outage communication with all affected teams",
            "infrastructure": "Infrastructure incident communication with service owners",
            "container": "Container platform communication with development teams",
            "storage": "Storage incident communication with data teams",
            "api": "API incident communication with integration partners",
            "authentication": "Authentication incident communication with all users",
            "backup": "Backup incident communication with data protection teams"
        }
        return plans.get(incident_type, "Standard incident communication protocol")
    
    def _get_update_frequency(self, severity: str) -> str:
        """Get update frequency based on severity"""
        frequencies = {
            "critical": "Every 15 minutes",
            "high": "Every 30 minutes", 
            "medium": "Every hour",
            "low": "Every 4 hours"
        }
        return frequencies.get(severity, "Every hour")
    
    async def _execute_remediation_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(agent_id="remediation", agent_name="Remediation Agent", incident_id=incident.id)
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        
        try:
            await self._log_activity(execution, f"🔧 Analyzing {incident.incident_type} remediation strategies...")
            execution.progress = 25
            await asyncio.sleep(random.uniform(1.5, 2.5))
            
            # Get incident-specific remediation actions
            remediation_actions = self._get_remediation_actions(incident.incident_type, incident.severity.value)
            
            await self._log_activity(execution, f"⚡ Executing {len(remediation_actions)} automated remediation procedures...")
            execution.progress = 50
            await asyncio.sleep(random.uniform(2.5, 4.0))
            
            await self._log_activity(execution, f"🔄 Applying {incident.incident_type}-specific recovery protocols...")
            execution.progress = 75
            await asyncio.sleep(random.uniform(2.0, 3.0))
            
            execution.output_data = {
                "actions_performed": remediation_actions,
                "rollback_available": self._has_rollback_capability(incident.incident_type),
                "automation_level": self._get_automation_level(incident.incident_type),
                "safety_checks": self._get_safety_checks(incident.incident_type),
                "estimated_recovery_time": self._get_recovery_time(incident.incident_type, incident.severity.value)
            }
            
            incident.remediation_applied = execution.output_data["actions_performed"]
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            await self._log_activity(execution, f"✅ {incident.incident_type.title()} remediation completed - {len(remediation_actions)} actions applied")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_remediation_actions(self, incident_type: str, severity: str) -> List[str]:
        """Get incident-specific remediation actions"""
        base_actions = {
            "database": ["connection_pool_scaling", "query_optimization", "replica_failover", "cache_warming"],
            "security": ["system_isolation", "credential_rotation", "security_patching", "monitoring_enhancement"],
            "network": ["traffic_rerouting", "failover_activation", "hardware_replacement", "routing_optimization"],
            "infrastructure": ["resource_scaling", "service_restart", "load_rebalancing", "capacity_optimization"],
            "container": ["pod_restart", "resource_limit_increase", "node_scaling", "image_update"],
            "storage": ["disk_replacement", "raid_rebuild", "data_replication", "io_optimization"],
            "api": ["rate_limit_tuning", "backend_scaling", "circuit_breaker_reset", "cache_optimization"],
            "dns": ["dns_cache_flush", "resolver_restart", "upstream_failover", "zone_transfer"],
            "authentication": ["service_restart", "token_refresh", "ldap_reconnect", "cache_clear"],
            "search": ["index_rebuild", "cluster_restart", "shard_reallocation", "memory_tuning"],
            "cdn": ["cache_purge", "origin_scaling", "edge_server_restart", "route_optimization"],
            "messaging": ["queue_drain", "broker_restart", "consumer_scaling", "dlq_processing"],
            "backup": ["job_restart", "storage_rescan", "integrity_check", "retention_cleanup"],
            "vpn": ["connection_reset", "concentrator_restart", "tunnel_rebuild", "capacity_increase"],
            "monitoring": ["service_restart", "disk_cleanup", "retention_adjustment", "index_optimization"],
            "loadbalancer": ["health_check_reset", "backend_refresh", "ssl_renewal", "traffic_rebalance"]
        }
        
        actions = base_actions.get(incident_type, ["service_restart", "resource_scaling", "configuration_reset"])
        
        # Add severity-specific actions
        if severity == "critical":
            critical_actions = {
                "database": ["emergency_read_replica", "connection_overflow_handling"],
                "security": ["full_system_isolation", "emergency_credential_lockdown"],
                "network": ["emergency_traffic_bypass", "disaster_recovery_activation"],
                "container": ["emergency_cluster_scaling", "priority_pod_scheduling"],
                "storage": ["emergency_replica_activation", "rapid_recovery_mode"],
                "api": ["emergency_rate_limiting", "circuit_breaker_activation"]
            }
            actions.extend(critical_actions.get(incident_type, ["emergency_procedures"]))
        
        return actions
    
    def _has_rollback_capability(self, incident_type: str) -> bool:
        """Check if incident type supports rollback"""
        rollback_supported = ["database", "infrastructure", "container", "api", "cdn", "messaging"]
        return incident_type in rollback_supported
    
    def _get_automation_level(self, incident_type: str) -> str:
        """Get automation level for incident type"""
        levels = {
            "container": "high",
            "api": "high",
            "cdn": "high",
            "infrastructure": "medium",
            "database": "medium",
            "messaging": "medium",
            "dns": "medium",
            "monitoring": "medium",
            "loadbalancer": "medium",
            "network": "low",
            "security": "low",  # Security requires more manual oversight
            "storage": "low",
            "backup": "low",
            "authentication": "low",
            "search": "medium",
            "vpn": "low"
        }
        return levels.get(incident_type, "medium")
    
    def _get_safety_checks(self, incident_type: str) -> List[str]:
        """Get safety checks performed during remediation"""
        checks = {
            "database": ["backup_verification", "transaction_consistency", "replication_lag"],
            "security": ["access_control_verification", "audit_log_integrity", "compliance_check"],
            "network": ["redundancy_verification", "traffic_flow_validation", "latency_check"],
            "container": ["health_check_validation", "resource_availability", "deployment_rollback_ready"],
            "storage": ["data_integrity_check", "raid_status_verification", "backup_availability"],
            "api": ["endpoint_health_check", "rate_limit_verification", "dependency_validation"],
            "dns": ["resolution_validation", "zone_consistency_check", "upstream_connectivity"],
            "authentication": ["service_availability", "token_validation", "directory_connectivity"],
            "search": ["cluster_health_check", "index_integrity", "query_performance"],
            "cdn": ["origin_connectivity", "cache_consistency", "edge_server_health"],
            "messaging": ["queue_health_check", "consumer_validation", "message_integrity"],
            "backup": ["job_status_verification", "data_integrity", "retention_compliance"],
            "vpn": ["tunnel_connectivity", "authentication_check", "capacity_verification"],
            "monitoring": ["data_ingestion_check", "alerting_validation", "dashboard_availability"],
            "loadbalancer": ["backend_health_validation", "ssl_certificate_check", "traffic_distribution"]
        }
        return checks.get(incident_type, ["system_health_check", "service_availability", "rollback_ready"])
    
    def _get_recovery_time(self, incident_type: str, severity: str) -> str:
        """Get estimated recovery time"""
        base_times = {
            "database": "15-30 minutes",
            "security": "30-60 minutes",
            "network": "10-20 minutes",
            "infrastructure": "20-40 minutes",
            "container": "5-15 minutes",
            "api": "10-20 minutes",
            "storage": "30-120 minutes",
            "dns": "5-15 minutes",
            "authentication": "10-30 minutes",
            "search": "20-60 minutes",
            "cdn": "10-30 minutes",
            "messaging": "15-45 minutes",
            "backup": "60-240 minutes",
            "vpn": "10-30 minutes",
            "monitoring": "5-20 minutes",
            "loadbalancer": "10-25 minutes"
        }
        
        base_time = base_times.get(incident_type, "20-30 minutes")
        if severity == "critical":
            return f"{base_time} (priority recovery)"
        return base_time
    
    async def _execute_validation_agent(self, incident: Incident) -> AgentExecution:
        execution = AgentExecution(agent_id="validation", agent_name="Validation Agent", incident_id=incident.id)
        execution.status = AgentStatus.RUNNING
        execution.started_at = datetime.now()
        
        try:
            await self._log_activity(execution, f"🔍 Starting {incident.incident_type} resolution validation...")
            execution.progress = 30
            await asyncio.sleep(random.uniform(2.0, 3.0))
            
            await self._log_activity(execution, f"📊 Monitoring {incident.incident_type} system metrics and KPIs...")
            execution.progress = 60
            await asyncio.sleep(random.uniform(2.0, 2.5))
            
            await self._log_activity(execution, f"✅ Performing {incident.incident_type} health verification tests...")
            execution.progress = 90
            await asyncio.sleep(random.uniform(1.5, 2.0))
            
            # Determine resolution success (85% success rate)
            resolution_successful = random.random() < 0.85
            
            validation_results = self._get_validation_results(incident.incident_type, resolution_successful)
            
            execution.output_data = {
                "health_checks": validation_results,
                "incident_resolved": resolution_successful,
                "validation_score": random.uniform(0.88, 0.98) if resolution_successful else random.uniform(0.65, 0.85),
                "post_incident_actions": self._get_post_incident_actions(incident.incident_type),
                "monitoring_enhanced": True
            }
            
            if resolution_successful:
                incident.resolution = self._get_resolution_message(incident.incident_type)
                incident.status = "resolved"
            else:
                incident.resolution = f"{incident.incident_type.title()} issue partially resolved - continued monitoring and manual intervention required"
                incident.status = "partially_resolved"
            
            execution.progress = 100
            execution.status = AgentStatus.SUCCESS
            status_msg = "fully resolved" if resolution_successful else "partially resolved"
            await self._log_activity(execution, f"✅ {incident.incident_type.title()} validation completed - Issue {status_msg}")
            
        except Exception as e:
            execution.status = AgentStatus.ERROR
            execution.error_message = str(e)
        
        execution.completed_at = datetime.now()
        execution.duration_seconds = (execution.completed_at - execution.started_at).total_seconds()
        return execution
    
    def _get_validation_results(self, incident_type: str, successful: bool) -> Dict[str, str]:
        """Get incident-specific validation results"""
        if successful:
            results = {
                "database": {"connections": "Normal (450/500)", "query_time": "<50ms", "cpu": "45%", "memory": "65%"},
                "security": {"threat_level": "Green", "access_controls": "Active", "monitoring": "Enhanced", "systems": "Secured"},
            
                "network": {"latency": "8ms", "packet_loss": "0%", "bandwidth": "Optimal", "redundancy": "Active"},
                "infrastructure": {"cpu": "35%", "memory": "58%", "disk": "68%", "services": "All Healthy"},
                "container": {"pods": "All Running", "memory": "Optimal", "cpu": "40%", "replicas": "Desired State"},
                "storage": {"raid_status": "Optimal", "disk_health": "Good", "io_latency": "1.2ms", "throughput": "Normal"},
                "api": {"response_time": "35ms", "error_rate": "0.05%", "throughput": "Normal", "rate_limits": "Active"},
                "dns": {"resolution_time": "15ms", "success_rate": "99.9%", "cache_hit": "85%", "zones": "Healthy"},
                "authentication": {"login_success": "99.5%", "token_validation": "Normal", "ldap": "Connected", "sso": "Active"},
                "search": {"cluster_status": "Green", "query_time": "45ms", "indices": "Healthy", "shards": "Assigned"},
                "cdn": {"cache_hit": "92%", "origin_latency": "50ms", "edge_health": "100%", "bandwidth": "Normal"},
                "messaging": {"queue_depth": "Normal", "consumers": "Active", "throughput": "Optimal", "dlq": "Empty"},
                "backup": {"last_backup": "Success", "integrity": "Verified", "retention": "Compliant", "rpo": "Met"},
                "vpn": {"connections": "Stable", "throughput": "Normal", "auth_success": "99%", "tunnels": "Active"},
                "monitoring": {"ingestion": "Normal", "alerts": "Active", "dashboards": "Available", "retention": "OK"},
                "loadbalancer": {"backends": "Healthy", "response_time": "25ms", "ssl": "Valid", "traffic": "Balanced"}
            }
        else:
            results = {
                "database": {"connections": "Elevated (480/500)", "query_time": "120ms", "cpu": "65%", "memory": "72%"},
                "security": {"threat_level": "Yellow", "access_controls": "Monitoring", "systems": "Under Review"},
                "network": {"latency": "25ms", "packet_loss": "0.1%", "bandwidth": "Reduced", "issues": "Minor"},
                "infrastructure": {"cpu": "55%", "memory": "78%", "services": "Mostly Healthy", "alerts": "Active"},
                "container": {"pods": "Stabilizing", "memory": "High", "cpu": "60%", "monitoring": "Enhanced"},
                "storage": {"raid_status": "Rebuilding", "disk_health": "Warning", "io_latency": "3.5ms", "monitoring": "Active"},
                "api": {"response_time": "85ms", "error_rate": "0.8%", "throughput": "Reduced", "monitoring": "Enhanced"},
                "dns": {"resolution_time": "35ms", "success_rate": "98%", "cache_hit": "70%", "monitoring": "Active"},
                "authentication": {"login_success": "97%", "token_validation": "Delayed", "monitoring": "Enhanced"},
                "search": {"cluster_status": "Yellow", "query_time": "120ms", "monitoring": "Active"},
                "cdn": {"cache_hit": "75%", "origin_latency": "150ms", "monitoring": "Enhanced"},
                "messaging": {"queue_depth": "Elevated", "consumers": "Recovering", "monitoring": "Active"},
                "backup": {"last_backup": "Warning", "integrity": "Checking", "monitoring": "Enhanced"},
                "vpn": {"connections": "Recovering", "auth_success": "95%", "monitoring": "Active"},
                "monitoring": {"ingestion": "Reduced", "alerts": "Enhanced", "monitoring": "Active"},
                "loadbalancer": {"backends": "Recovering", "response_time": "65ms", "monitoring": "Enhanced"}
            }
        
        return results.get(incident_type, {"status": "Healthy" if successful else "Monitoring", "performance": "Normal" if successful else "Degraded"})
    
    def _get_post_incident_actions(self, incident_type: str) -> List[str]:
        """Get post-incident actions for follow-up"""
        actions = {
            "database": ["Connection pool tuning review", "Query performance audit", "Monitoring threshold adjustment"],
            "security": ["Security audit", "Incident review meeting", "Security policy update", "Training session"],
            "network": ["Network capacity review", "Hardware refresh planning", "Redundancy assessment"],
            "infrastructure": ["Capacity planning review", "Auto-scaling configuration", "Resource optimization"],
            "container": ["Resource limit review", "Image security scan", "Deployment process improvement"],
            "storage": ["Storage capacity planning", "Backup verification", "Hardware lifecycle review"],
            "api": ["Rate limiting review", "Performance testing", "Integration health check"],
            "dns": ["DNS configuration audit", "Resolver capacity review", "Zone delegation check"],
            "authentication": ["Authentication flow review", "Token lifecycle audit", "Directory sync verification"],
            "search": ["Index optimization review", "Cluster sizing assessment", "Query performance analysis"],
            "cdn": ["Cache strategy review", "Origin capacity planning", "Edge server optimization"],
            "messaging": ["Queue configuration review", "Consumer scaling assessment", "Message flow optimization"],
            "backup": ["Backup strategy review", "Recovery testing", "Retention policy audit"],
            "vpn": ["VPN capacity planning", "Connection optimization", "Security policy review"],
            "monitoring": ["Retention policy review", "Alert threshold tuning", "Dashboard optimization"],
            "loadbalancer": ["Health check optimization", "SSL certificate lifecycle", "Traffic pattern analysis"]
        }
        return actions.get(incident_type, ["Post-incident review", "Process improvement", "Monitoring enhancement"])
    
    def _get_resolution_message(self, incident_type: str) -> str:
        """Get incident-specific resolution message"""
        messages = {
            "database": "Database connection pool optimized and query performance restored to baseline levels",
            "security": "Security threat successfully contained and systems hardened with enhanced monitoring",
            "network": "Network connectivity fully restored with redundancy verified and performance optimized",
            "infrastructure": "Infrastructure resources scaled appropriately and system performance returned to normal",
            "container": "Container orchestration stabilized with resource optimization and health monitoring active",
            "storage": "Storage system fully repaired with RAID rebuild completed and data integrity verified",
            "api": "API gateway rate limiting configured and backend performance optimized for normal operation",
            "dns": "DNS resolution fully restored with redundant resolvers active and zone consistency verified",
            "authentication": "Authentication services restored with enhanced monitoring and token validation active",
            "search": "Search cluster stabilized with optimal shard allocation and query performance restored",
            "cdn": "CDN performance optimized with cache warming completed and origin servers scaled",
            "messaging": "Message queue processing restored with consumer scaling and dead letter queue management",
            "backup": "Backup system integrity verified with successful test restore and monitoring enhanced",
            "vpn": "VPN connectivity stabilized with capacity optimization and connection monitoring active",
            "monitoring": "Monitoring system restored with data ingestion optimized and alerting fully functional",
            "loadbalancer": "Load balancer health restored with backend optimization and traffic distribution balanced"
        }
        return messages.get(incident_type, f"{incident_type.title()} issue fully resolved with enhanced monitoring in place")
    
    async def _log_activity(self, execution: AgentExecution, message: str, level: str = "INFO"):
        """Log agent activity with timestamp"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "level": level,
            "message": message,
            "execution_id": execution.execution_id
        }
        execution.logs.append(log_entry)
        logger.info(f"[{execution.incident_id}] {execution.agent_name}: {message}")

# Global workflow engine
workflow_engine = WorkflowEngine()

class EnhancedMonitoringSystemApp:
    def __init__(self):
        self.app = FastAPI(
            title="AI Monitoring System",
            description="Real-Time AI-Powered IT Operations Monitoring with 24 Diverse Incident Types",
            version="2.0.0",
            docs_url="/api/docs"
        )
        
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        self._setup_routes()
    
    def _setup_routes(self):
        @self.app.post("/api/trigger-incident")
        async def trigger_incident(incident_data: dict):
            incident = await workflow_engine.trigger_incident_workflow(incident_data)
            return {
                "incident_id": incident.id,
                "workflow_id": incident.workflow_id,
                "status": "workflow_started",
                "title": incident.title,
                "severity": incident.severity.value,
                "incident_type": incident.incident_type,
                "message": f"Incident {incident.id} workflow initiated successfully",
                "affected_systems": len(incident.affected_systems)
            }
        
        @self.app.get("/api/incidents/{incident_id}/status")
        async def get_incident_status(incident_id: str):
            incident = None
            if incident_id in workflow_engine.active_incidents:
                incident = workflow_engine.active_incidents[incident_id]
            else:
                incident = next((i for i in workflow_engine.incident_history if i.id == incident_id), None)
            
            if not incident:
                return {"error": "Incident not found"}
            
            return {
                "incident_id": incident.id,
                "title": incident.title,
                "severity": incident.severity.value,
                "incident_type": getattr(incident, 'incident_type', 'general'),
                "status": incident.status,
                "workflow_status": incident.workflow_status,
                "current_agent": incident.current_agent,
                "completed_agents": incident.completed_agents,
                "failed_agents": incident.failed_agents,
                "created_at": incident.created_at.isoformat(),
                "root_cause": incident.root_cause,
                "resolution": incident.resolution,
                "pagerduty_incident_id": incident.pagerduty_incident_id,
                "servicenow_ticket_id": incident.servicenow_ticket_id,
                "remediation_applied": incident.remediation_applied,
                "executions": {
                    agent_id: {
                        "status": execution.status.value,
                        "progress": execution.progress,
                        "duration": execution.duration_seconds,
                        "started_at": execution.started_at.isoformat() if execution.started_at else None,
                        "log_count": len(execution.logs),
                        "error": execution.error_message
                    }
                    for agent_id, execution in incident.executions.items()
                }
            }
        
        @self.app.get("/api/incidents/{incident_id}/agent/{agent_id}/logs")
        async def get_agent_logs(incident_id: str, agent_id: str):
            incident = None
            if incident_id in workflow_engine.active_incidents:
                incident = workflow_engine.active_incidents[incident_id]
            else:
                incident = next((i for i in workflow_engine.incident_history if i.id == incident_id), None)
            
            if not incident or agent_id not in incident.executions:
                return {"error": "Not found"}
            
            execution = incident.executions[agent_id]
            return {
                "incident_id": incident_id,
                "agent_id": agent_id,
                "agent_name": execution.agent_name,
                "execution_id": execution.execution_id,
                "status": execution.status.value,
                "progress": execution.progress,
                "started_at": execution.started_at.isoformat() if execution.started_at else None,
                "completed_at": execution.completed_at.isoformat() if execution.completed_at else None,
                "duration_seconds": execution.duration_seconds,
                "input_data": execution.input_data,
                "output_data": execution.output_data,
                "error_message": execution.error_message,
                "logs": execution.logs
            }
        
        @self.app.get("/api/incidents")
        async def get_incidents(limit: int = 20):
            all_incidents = list(workflow_engine.active_incidents.values()) + workflow_engine.incident_history
            all_incidents.sort(key=lambda x: x.created_at, reverse=True)
            all_incidents = all_incidents[:limit]
            
            return {
                "total_incidents": len(all_incidents),
                "active_incidents": len(workflow_engine.active_incidents),
                "incidents": [
                    {
                        "id": incident.id,
                        "title": incident.title,
                        "severity": incident.severity.value,
                        "incident_type": getattr(incident, 'incident_type', 'general'),
                        "status": incident.status,
                        "workflow_status": incident.workflow_status,
                        "created_at": incident.created_at.isoformat(),
                        "updated_at": incident.updated_at.isoformat(),
                        "completed_agents": len(incident.completed_agents),
                        "total_agents": 7,
                        "pagerduty_incident_id": incident.pagerduty_incident_id,
                        "servicenow_ticket_id": incident.servicenow_ticket_id
                    }
                    for incident in all_incidents
                ]
            }
        
        @self.app.get("/api/dashboard/stats")
        async def get_dashboard_stats():
            all_incidents = list(workflow_engine.active_incidents.values()) + workflow_engine.incident_history
            today_incidents = [i for i in all_incidents if i.created_at.date() == datetime.now().date()]
            
            agent_stats = {}
            for agent_id in workflow_engine.agent_execution_history:
                executions = workflow_engine.agent_execution_history[agent_id]
                successful = len([e for e in executions if e.status == AgentStatus.SUCCESS])
                total = len(executions)
                avg_duration = sum([e.duration_seconds for e in executions if e.duration_seconds > 0]) / max(total, 1)
                
                agent_stats[agent_id] = {
                    "total_executions": total,
                    "successful_executions": successful,
                    "success_rate": (successful / max(total, 1)) * 100,
                    "average_duration": avg_duration
                }
            
            return {
                "incidents": {
                    "total_all_time": len(all_incidents),
                    "active": len(workflow_engine.active_incidents),
                    "today": len(today_incidents),
                    "resolved_today": len([i for i in today_incidents if i.status == "resolved"]),
                    "average_resolution_time_minutes": 8.5
                },
                "agents": agent_stats,
                "system": {
                    "uptime_hours": 24,
                    "total_workflows": len(all_incidents),
                    "successful_workflows": len([i for i in all_incidents if i.status == "resolved"]),
                    "overall_success_rate": (len([i for i in all_incidents if i.status == "resolved"]) / max(len(all_incidents), 1)) * 100,
                    "available_scenarios": len(INCIDENT_SCENARIOS)
                }
            }
        
        @self.app.get("/api/agents")
        async def get_agents():
            agent_configs = {
                "monitoring": "Real-time monitoring with incident-type specific metric collection and analysis",
                "rca": "AI-powered root cause analysis with machine learning correlation and pattern recognition", 
                "pager": "Intelligent escalation to specialized teams with context-aware notification routing",
                "ticketing": "Smart ticket classification with automated priority and category assignment",
                "email": "Context-aware stakeholder notifications with incident-specific communication protocols",
                "remediation": "Automated remediation with incident-type specific procedures and safety validation",
                "validation": "Comprehensive health verification with specialized testing and monitoring enhancement"
            }
            
            agents_data = {}
            for agent_id, description in agent_configs.items():
                executions = workflow_engine.agent_execution_history[agent_id]
                recent = executions[-1] if executions else None
                
                agents_data[agent_id] = {
                    "status": "ready",
                    "description": description,
                    "total_executions": len(executions),
                    "successful_executions": len([e for e in executions if e.status == AgentStatus.SUCCESS]),
                    "last_activity": recent.started_at.isoformat() if recent and recent.started_at else "Never",
                    "average_duration": sum([e.duration_seconds for e in executions]) / max(len(executions), 1),
                    "success_rate": (len([e for e in executions if e.status == AgentStatus.SUCCESS]) / max(len(executions), 1)) * 100
                }
            
            return {"agents": agents_data, "total_agents": 7}
        
        @self.app.websocket("/ws/incidents/{incident_id}")
        async def websocket_incident_updates(websocket: WebSocket, incident_id: str):
            await websocket.accept()
            
            try:
                while True:
                    if incident_id in workflow_engine.active_incidents:
                        incident = workflow_engine.active_incidents[incident_id]
                        
                        status_update = {
                            "type": "status_update",
                            "incident_id": incident_id,
                            "workflow_status": incident.workflow_status,
                            "current_agent": incident.current_agent,
                            "completed_agents": incident.completed_agents,
                            "incident_type": getattr(incident, 'incident_type', 'general'),
                            "agent_executions": {
                                agent_id: {
                                    "status": execution.status.value,
                                    "progress": execution.progress,
                                    "latest_log": execution.logs[-1] if execution.logs else None
                                }
                                for agent_id, execution in incident.executions.items()
                            },
                            "timestamp": datetime.now().isoformat()
                        }
                        
                        await websocket.send_text(json.dumps(status_update))
                    else:
                        incident = next((i for i in workflow_engine.incident_history if i.id == incident_id), None)
                        if incident:
                            final_update = {
                                "type": "workflow_completed",
                                "incident_id": incident_id,
                                "status": incident.status,
                                "resolution": incident.resolution,
                                "timestamp": datetime.now().isoformat()
                            }
                            await websocket.send_text(json.dumps(final_update))
                            break
                    
                    await asyncio.sleep(2)
                    
            except WebSocketDisconnect:
                pass
        
        @self.app.get("/health")
        async def health_check():
            return {
                "status": "healthy",
                "service": "AI Monitoring System",
                "version": "2.0.0",
                "features": ["24 diverse incident types", "Real-time workflows", "Specialized agent behaviors"],
                "workflow_engine": {
                    "active_incidents": len(workflow_engine.active_incidents),
                    "total_incidents": len(workflow_engine.incident_history),
                    "available_scenarios": len(INCIDENT_SCENARIOS)
                },
                "scenario_types": list(set(s["incident_type"] for s in INCIDENT_SCENARIOS))
            }
        
        # Serve frontend
        frontend_path = Path("frontend/build")
        if frontend_path.exists():
            self.app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="static")
        else:
            @self.app.get("/")
            async def root():
                return {
                    "message": "🤖 Enhanced AI Monitoring System v2.0",
                    "version": "2.0.0",
                    "features": [
                        "24 diverse incident scenarios",
                        "Real-time specialized agent workflows",
                        "Type-specific monitoring and remediation",
                        "Intelligent escalation and communication",
                        "Live progress tracking with detailed logs",
                        "Interactive dashboard with incident visualization"
                    ],
                    "available_incident_types": list(set(s["incident_type"] for s in INCIDENT_SCENARIOS)),
                    "total_scenarios": len(INCIDENT_SCENARIOS)
                }
    
    def run(self, host: str = "0.0.0.0", port: int = 8000):
        logger.info("🚀 Starting Enhanced AI Monitoring System v2.0...")
        logger.info(f"🎭 Available incident scenarios: {len(INCIDENT_SCENARIOS)}")
        logger.info(f"📊 Incident types: {list(set(s['incident_type'] for s in INCIDENT_SCENARIOS))}")
        logger.info("✨ Features: Diverse incidents, specialized agents, real-time workflows")
        logger.info(f"📊 Dashboard: http://localhost:{port}")
        uvicorn.run(self.app, host=host, port=port, log_level="info")

if __name__ == "__main__":
    app = EnhancedMonitoringSystemApp()
    app.run()
EOF_MAIN_PY

