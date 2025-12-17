# Node-RED Integration with Home Assistant

## Overview

Node-RED is a flow-based development tool for visual programming, perfect for creating complex automation workflows that integrate with Home Assistant. This guide covers setting up Node-RED to work seamlessly with your Home Assistant instance.

## Quick Start

### 1. Start Node-RED

Node-RED starts automatically when you deploy the home stack:

```bash
./scripts/orionctl up home
```

**Access:** https://nodered.orion.lan

### 2. Install Home Assistant Nodes

The first time you access Node-RED, install the Home Assistant palette:

1. Click the **hamburger menu** (≡) in the top right
2. Select **Manage palette**
3. Go to the **Install** tab
4. Search for: `node-red-contrib-home-assistant-websocket`
5. Click **Install**
6. Wait for installation to complete

**Alternatively, install via command line:**

```bash
docker exec -it orion_nodered npm install node-red-contrib-home-assistant-websocket
docker restart orion_nodered
```

### 3. Generate Home Assistant Long-Lived Access Token

Node-RED needs a token to communicate with Home Assistant:

1. Navigate to **Home Assistant** (https://home.orion.lan)
2. Click your **Profile** (bottom left)
3. Scroll down to **Long-Lived Access Tokens**
4. Click **Create Token**
5. Give it a name: `Node-RED Integration`
6. **Copy the token** (shown only once!)

**Keep this token secure!** It provides full access to your Home Assistant instance.

### 4. Configure Home Assistant Server in Node-RED

Now connect Node-RED to Home Assistant:

1. In Node-RED, drag a **Home Assistant node** onto the canvas (from the palette on the left)
2. Double-click the node to edit it
3. Click the **pencil icon** next to "Server" to add a new server
4. Configure:
   - **Name:** `Home Assistant`
   - **Base URL:** `http://host.docker.internal:8123`
   - **Access Token:** Paste your Long-Lived Access Token
   - **WebSocket:** Check "I use the Home Assistant Add-on" is **unchecked**
5. Click **Add**
6. Click **Done**

**Why `host.docker.internal:8123`?**  
Home Assistant runs in host network mode, so we use the Docker host gateway to reach it from Node-RED's bridge network.

### 5. Test the Connection

Create a simple test flow:

1. Drag an **inject** node to the canvas
2. Drag an **events: state** node (from Home Assistant palette)
3. Double-click the events node:
   - Select your Home Assistant server
   - Enter an entity ID (e.g., `sun.sun`)
   - Click **Done**
4. Drag a **debug** node to the canvas
5. Connect: inject → events → debug
6. Click **Deploy** (top right)
7. Click the inject button - you should see state changes in the debug panel

If you see Home Assistant state data, the integration is working! 🎉

## Common Use Cases

### 1. Advanced Automation

Create complex automations with conditional logic, delays, and multiple triggers:

**Example: Smart Morning Routine**
```
[trigger] Time: 7:00 AM
  ↓
[check] Is anyone home?
  ↓ Yes
[switch] Turn on bedroom lights gradually
  ↓
[delay] Wait 5 minutes
  ↓
[call service] Start coffee maker
  ↓
[notify] Send "Good morning" notification
```

### 2. Data Processing

Process Home Assistant data before acting on it:

- Calculate averages of sensor values
- Combine multiple sensors
- Filter and transform data
- Store historical data in databases

### 3. External Integrations

Connect Home Assistant to services without native integrations:

- Custom API calls
- MQTT publishing/subscribing
- Database operations
- Email notifications
- Web scraping

### 4. Dashboard & Visualization

Create custom dashboards and data visualizations:

- Real-time charts
- Custom widgets
- External displays
- Mobile notifications

## Example Flows

### Example 1: Motion-Activated Lights with Timer

```
[Event: State] motion_sensor.living_room
  state == "on"
  ↓
[Call Service] light.turn_on
  entity_id: light.living_room
  ↓
[Delay] 5 minutes
  ↓
[Event: State] motion_sensor.living_room
  state == "off"
  ↓
[Call Service] light.turn_off
  entity_id: light.living_room
```

### Example 2: Temperature Alert

```
[Event: State] sensor.bedroom_temperature
  ↓
[Switch] Check temperature
  > 25°C → Send alert
  < 18°C → Send alert
  else → Do nothing
  ↓
[Notify] Send mobile notification
```

### Example 3: Daily Energy Report

```
[Inject] Every day at 9:00 PM
  ↓
[Get Entities] sensor.energy_*
  ↓
[Function] Calculate daily total
  ↓
[Call Service] notify.mobile_app
  message: "Today's energy usage: X kWh"
```

## Node-RED Basics

### Key Node Types

**Home Assistant Nodes:**
- **Events: State** - Trigger on entity state changes
- **Call Service** - Execute Home Assistant services
- **Get Entities** - Retrieve entity states
- **Fire Event** - Trigger Home Assistant events
- **API** - Direct API calls to Home Assistant

**Core Nodes:**
- **Inject** - Manual trigger or scheduled timer
- **Debug** - Display messages in debug panel
- **Function** - Write JavaScript for data transformation
- **Switch** - Route messages based on conditions
- **Change** - Modify message properties
- **Delay** - Add time delays to flows

### Flow Structure

A Node-RED flow consists of:
1. **Input nodes** (triggers) - Start the flow
2. **Processing nodes** - Transform or route data
3. **Output nodes** (actions) - Execute actions

Connect nodes by dragging wires between them.

### Message Object

Data flows through nodes as `msg` objects:
- `msg.payload` - Main data
- `msg.topic` - Message identifier
- `msg.data` - Home Assistant specific data

**Example message from state change:**
```javascript
{
  payload: "on",
  data: {
    entity_id: "light.living_room",
    state: "on",
    attributes: {
      brightness: 255,
      color_temp: 370
    }
  }
}
```

## Troubleshooting

### Cannot Connect to Home Assistant

**Error:** "Connection refused" or "Timeout"

**Solutions:**

1. Verify Home Assistant is running:
   ```bash
   docker ps | grep homeassistant
   curl http://localhost:8123/api/
   ```

2. Check Node-RED can reach Home Assistant:
   ```bash
   docker exec orion_nodered wget -O- http://host.docker.internal:8123/api/
   ```

3. Verify access token is correct:
   - Go to Home Assistant → Profile → Long-Lived Access Tokens
   - Regenerate token if needed
   - Update token in Node-RED server configuration

### "Unauthorized" Error

**Cause:** Invalid or expired access token

**Solution:**
1. Generate new Long-Lived Access Token in Home Assistant
2. Update Node-RED server configuration:
   - Click any Home Assistant node
   - Click pencil icon next to Server
   - Update Access Token
   - Deploy

### Nodes Show "Disconnected"

**Cause:** WebSocket connection issue

**Solution:**
1. Check Node-RED logs:
   ```bash
   docker logs orion_nodered
   ```

2. Restart Node-RED:
   ```bash
   docker restart orion_nodered
   ```

3. Verify Home Assistant is accessible from Node-RED container

### Flow Not Triggering

**Debugging steps:**

1. Add **debug nodes** after each step
2. Check debug panel (bug icon) for messages
3. Verify entity IDs are correct
4. Check Home Assistant state changes are actually happening
5. Look for errors in Node-RED logs

### WebSocket Disconnects Frequently

**Cause:** Network issues or resource constraints

**Solutions:**
1. Check container resource usage
2. Verify network connectivity
3. Increase Node-RED memory if needed
4. Check Traefik logs for connection issues

## Best Practices

### 1. Use Meaningful Names

Name your nodes and flows descriptively:
- ❌ "Flow 1", "function 1"
- ✅ "Morning Routine", "Calculate Average Temperature"

### 2. Add Comments

Use **comment nodes** to document complex logic:
```
This flow checks if anyone is home before running
the automation. It uses the person.* entities.
```

### 3. Group Related Flows

Organize flows by function:
- Lighting Automation
- Climate Control
- Security & Alerts
- Energy Monitoring

### 4. Handle Errors

Add **catch nodes** to handle errors gracefully:
```
[Any node] → [catch] → [function: log error] → [notify]
```

### 5. Test Incrementally

Build flows step by step:
1. Start with a simple trigger
2. Add debug nodes to verify data
3. Add logic incrementally
4. Test each addition before proceeding

### 6. Backup Your Flows

Node-RED stores flows in `/data/flows.json`. Back it up regularly:

```bash
# Backup flows
docker exec orion_nodered cat /data/flows.json > nodered-flows-backup.json

# Restore flows
docker cp nodered-flows-backup.json orion_nodered:/data/flows.json
docker restart orion_nodered
```

### 7. Use Projects for Version Control

Enable Projects in Node-RED for Git-based flow management:

1. Settings → Projects → Enable
2. Create a new project
3. Commit changes regularly
4. Push to remote Git repository

## Security Considerations

### 1. Protect Access Tokens

- Never commit tokens to version control
- Regenerate tokens periodically (every 6-12 months)
- Use separate tokens for different integrations
- Revoke unused tokens in Home Assistant

### 2. Restrict Node-RED Access

Consider adding authentication to Node-RED:

Edit Node-RED settings:
```bash
docker exec -it orion_nodered vi /data/settings.js
```

Add admin user:
```javascript
adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2b$08$...",  // bcrypt hash
        permissions: "*"
    }]
}
```

Generate password hash:
```bash
docker exec -it orion_nodered node-red admin hash-pw
```

### 3. Limit Node-RED Capabilities

The Node-RED container runs without privileged access and with `no-new-privileges` security option. Avoid:
- Mounting sensitive host directories
- Running Node-RED as root
- Installing untrusted npm packages

## Advanced Topics

### Using Environment Variables

Access environment variables in Function nodes:

```javascript
const timezone = env.get("TZ");
msg.payload = `Current timezone: ${timezone}`;
return msg;
```

### Custom Nodes

Install additional node packages for extended functionality:

```bash
# From Node-RED UI: Manage Palette → Install
# Or via command line:
docker exec -it orion_nodered npm install node-red-contrib-<package-name>
docker restart orion_nodered
```

### Subflows

Create reusable subflows for common patterns:

1. Select multiple nodes
2. Menu → Subflows → Selection to Subflow
3. Configure inputs/outputs
4. Use subflow as a single node in other flows

### Persistent Context

Store data between flow executions:

```javascript
// Store
context.set("lastRun", new Date());

// Retrieve
const lastRun = context.get("lastRun");
```

## Resources

### Documentation
- **Node-RED Docs:** https://nodered.org/docs/
- **Home Assistant Nodes:** https://zachowj.github.io/node-red-contrib-home-assistant-websocket/
- **Node-RED Cookbook:** https://cookbook.nodered.org/

### Learning
- **Node-RED Tutorials:** https://nodered.org/docs/tutorials/
- **Home Assistant Automation:** https://www.home-assistant.io/docs/automation/
- **Node-RED Forum:** https://discourse.nodered.org/

### Communities
- **r/nodered:** https://reddit.com/r/nodered
- **r/homeassistant:** https://reddit.com/r/homeassistant
- **Home Assistant Forums:** https://community.home-assistant.io/

---

**Stack:** Home Automation  
**URL:** https://nodered.orion.lan  
**Data Location:** `/srv/orion/internal/appdata/nodered/`  
**Maintained by:** Orion Home Lab Team
