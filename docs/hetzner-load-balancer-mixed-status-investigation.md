# Hetzner Load Balancer Mixed Status Investigation Report

**Date:** 2025-08-29  
**Investigation Lead:** DevOps Team  
**Status:** RESOLVED - No Action Required

## Executive Summary

Investigation into Hetzner load balancers showing "mixed" health status revealed this is **expected behavior** when using `label_selector` target configurations. Despite the "mixed" status display, all services are fully functional and all individual targets report healthy status. This is a cosmetic display characteristic of the Hetzner Cloud API, not an operational issue.

## Problem Statement

Both Hetzner load balancers (`ai-consigliere-dev-control-plane` and `ai-consigliere-dev-nginx`) consistently display "mixed" health status despite:
- All k3s cluster nodes showing Ready state
- All individual LB targets reporting healthy
- Services being fully accessible through the load balancers
- Proper firewall rules configured for health checks

## Investigation Timeline

### Initial State
- **Control Plane LB:** ID 4318998, IP 5.161.38.104, Status: mixed
- **Nginx LB:** ID 4318999, IP 5.161.35.135, Status: mixed
- **Cluster:** All 4 nodes (3 control plane, 1 worker) in Ready state
- **Services:** Functional but showing concerning "mixed" health

### Hypotheses Tested

#### H1: Port Configuration Mismatch (❌ Disproven)
**Hypothesis:** Health check ports don't match destination ports  
**Test:** Compared service configurations  
**Result:** Health check ports correctly match destination ports (31874, 32611)

#### H2: Firewall Blocking NodePorts (❌ Disproven)
**Hypothesis:** Firewall rules block NodePort ranges (30000-32767)  
**Test:** Examined firewall configuration  
**Result:** Proper rules exist allowing LB IPs to access NodePorts:
- Port 31874 allowed from 5.161.35.135/32
- Port 32611 allowed from 5.161.35.135/32
- Port 6443 allowed from both LB IPs
- All private network traffic (10.0.0.0/8) allowed

#### H3: Duplicate Target Configuration (✅ Partially Confirmed)
**Hypothesis:** Duplicate target entries cause status confusion  
**Test:** Analyzed target configurations  
**Result:** Found nginx LB had server 107494102 configured twice:
1. As a direct server target
2. Via label_selector that included the same server

**Action Taken:** Removed duplicate direct server target

#### H4: Hetzner API Behavior (✅ Root Cause)
**Discovery:** When using `label_selector` targets, the parent `health_status` field is always `null` in the Hetzner API response, while nested individual targets show their actual health status.

## Technical Analysis

### Load Balancer Configuration Structure

```json
{
  "targets": [
    {
      "type": "label_selector",
      "health_status": null,  // <-- Always null for label_selector
      "targets": [
        {
          "type": "server",
          "health_status": [
            {
              "listen_port": 6443,
              "status": "healthy"  // <-- Individual targets are healthy
            }
          ]
        }
      ]
    }
  ]
}
```

### Current Configuration

#### Control Plane Load Balancer
- **Type:** lb11
- **Algorithm:** round_robin
- **Target Type:** label_selector
- **Selector:** `cluster=ai-consigliere-dev,engine=k3s,provisioner=terraform,role=control_plane_node`
- **Health Checks:** TCP on port 6443
- **Actual Status:** All 3 control plane nodes healthy
- **Display Status:** Mixed (due to null parent health_status)

#### Nginx Load Balancer
- **Type:** lb11
- **Algorithm:** round_robin
- **Target Type:** label_selector
- **Selector:** `cluster=ai-consigliere-dev,engine=k3s,provisioner=terraform,role in (control_plane_node,agent_node)`
- **Services:**
  - Port 80 → NodePort 31874
  - Port 443 → NodePort 32611
- **Health Checks:** TCP on respective NodePorts
- **Actual Status:** All 4 nodes healthy
- **Display Status:** Mixed (due to null parent health_status)

### Functional Verification

All services are fully operational despite "mixed" status:

```bash
# API Server - TLS endpoint reachable (401 authentication required as expected)
curl -k https://5.161.38.104:6443/healthz
# Status: 401 ✓

# Nginx HTTP - Service responding (404 no default backend as expected)
curl http://5.161.35.135
# Status: 404 ✓

# Kubernetes cluster - All nodes Ready
kubectl get nodes
# All 4 nodes: Ready ✓
```

## Root Cause

The "mixed" health status is **expected Hetzner Cloud API behavior** when using `label_selector` target types. The API design returns:
1. `null` for the parent label_selector's health_status field
2. Actual health status for individual nested server targets
3. The CLI/Console **derives** a "mixed" summary from this null + healthy combination

**Important:** There is no canonical "LB health" field in the Hetzner API. The "mixed" status is a UI-computed summary, not an API-provided value. Tools like Ansible's `hetzner.hcloud.load_balancer_status` literally calculate overall status from individual target states.

This is a display characteristic, not an operational issue. The load balancers are functioning correctly and routing traffic to healthy targets.

### API Evidence

The Hetzner API structure shows health status only exists on concrete server targets, never on the label_selector wrapper:

```bash
# Command to verify API structure:
hcloud load-balancer describe 4318999 --output json |
jq '.targets[] | {
  type,
  has_parent_health: has("health_status"),
  parent_health: .health_status,
  nested_targets: (.targets // []) | map({
    type,
    server_id: .server.id,
    health: .health_status
  })
}'
```

**Output demonstrates:**
- `label_selector` type has `parent_health: null`
- Only nested server targets have actual health arrays
- The "mixed" display is derived from this structure

## Recommendations

### For Operations Team

1. **Accept "mixed" status as normal** for label_selector configurations
2. **Verify all nested targets are healthy** before dismissing "mixed" status:
   ```bash
   # Check that 100% of nested targets are healthy
   hcloud load-balancer describe <lb-id> --output json | \
   jq '[.targets[].targets[]?.health_status[]?.status] | 
       group_by(.) | map({status: .[0], count: length})'
   ```
3. **Monitor actual service health** through:
   - Direct health endpoint checks
   - Application monitoring (Prometheus/Grafana)
   - Per-target health status changes
   - Kubernetes node and pod status
4. **Do not rely on LB status display** as the primary health indicator

### For Target Selection (Future-Proofing)

Consider refining the nginx LB selector to prevent real mixed states:
- Current: `role in (control_plane_node,agent_node)` includes all nodes
- Recommended: Use specific labels for ingress nodes (e.g., `role=ingress`)
- This prevents issues if control plane nodes are later tainted or don't run ingress

### For Health Checks (Optional Enhancement)

Current TCP checks verify port reachability. For application-aware health:
```yaml
# Via Hetzner CCM annotations on the Service:
metadata:
  annotations:
    load-balancer.hetzner.cloud/health-check-protocol: "http"
    load-balancer.hetzner.cloud/health-check-http-path: "/healthz"
```

### For Monitoring

Create alerts based on:
- Individual target health flips (not overall LB status)
- Actual service availability (HTTP/HTTPS response codes)
- Kubernetes node status
- Pod readiness/liveness probes
- Application-level SLOs (Prometheus blackbox exporter)

Rather than:
- Hetzner LB summary health status display

### Documentation Updates

1. Add note to runbooks that "mixed" LB status is expected with label_selector
2. Include this behavior in onboarding documentation
3. Update monitoring dashboards to show actual service health metrics

## Conclusion

The investigation revealed that the "mixed" health status is not a problem requiring resolution. It's a characteristic of how Hetzner's API represents health status for dynamically targeted load balancers using label selectors. All services are healthy and functional.

### Key Takeaways

1. **No action required** - The system is operating correctly
2. **Improved one configuration** - Removed duplicate target from nginx LB
3. **Documented expected behavior** - This report serves as reference
4. **Focus on functional monitoring** - Use actual service health checks, not LB status display

## Appendix: Quick Reference Commands

```bash
# Check load balancer status
export HCLOUD_TOKEN="your-token-here"
hcloud load-balancer list

# View detailed LB configuration
hcloud load-balancer describe <lb-id> --output json

# Test service availability
curl -k https://<control-plane-lb-ip>:6443/healthz
curl http://<nginx-lb-ip>

# Check Kubernetes cluster health
kubectl get nodes -o wide
kubectl get svc -n nginx

# View firewall rules
hcloud firewall describe ai-consigliere-dev
```

## Firewall Considerations

### Current IPv4 Rules (Working)
- NodePorts 31874, 32611 allowed from LB IP 5.161.35.135/32
- API port 6443 allowed from both LB IPs
- All private network traffic (10.0.0.0/8) allowed

### Future IPv6 Consideration
If IPv6 is enabled on load balancers, ensure firewall rules mirror IPv4 allowances:
- Add IPv6 LB addresses to allowed sources
- Hetzner LBs support dual-stack; health checks may use either protocol

## References

### Investigation Logs
- [Initial Investigation - Private Network Health](/home/brian/Dev/espocrm-standalone/logs_8-29-2025/private_network_health_verification.txt)
- [Initial Investigation - Load Balancer Health](/home/brian/Dev/espocrm-standalone/logs_8-29-2025/load_balancer_health_investigation.txt)

### Technical Documentation
- [Hetzner Cloud API - Load Balancer Endpoints](https://docs.hetzner.cloud/#load-balancers) - Shows health_status structure on targets
- [Hetzner Python SDK Models](https://hcloud-python.readthedocs.io/en/stable/reference.html#hcloud.load_balancers.domain.LoadBalancerTarget) - LoadBalancerTargetLabelSelector has only selector field
- [Ansible hcloud Collection](https://docs.ansible.com/ansible/latest/collections/hetzner/hcloud/index.html) - Computes LB status from target states
- [Hetzner Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) - Supports health check annotations
- [k3s Documentation](https://docs.k3s.io/)

---

*Last Updated: 2025-08-29*  
*Next Review: N/A - Issue Resolved*