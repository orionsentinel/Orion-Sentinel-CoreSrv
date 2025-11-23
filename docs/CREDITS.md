# Credits and Acknowledgements

## Upstream Inspiration

This repository (`Orion-Sentinel-CoreSrv`) is a **derived work** that draws heavy inspiration from two excellent open-source projects. We are deeply grateful to the maintainers and contributors of these repositories.

---

## Primary Upstream Sources

### 1. AdrienPoupa/docker-compose-nas

**Repository:** https://github.com/AdrienPoupa/docker-compose-nas  
**Author:** Adrien Poupa ([@AdrienPoupa](https://github.com/AdrienPoupa))  
**License:** MIT License  

#### What We Borrowed

This project provided the foundational architecture for our home lab stack:

- **Directory Structure:**
  - Hardlink-friendly media layout (Trash-Guides compatible)
  - Config/data separation patterns
  - Environment variable organization (`.env` file structure)

- **Core Services:**
  - Traefik reverse proxy configuration
  - Authelia SSO integration patterns
  - VPN + qBittorrent isolation strategy

- **Media Stack:**
  - Jellyfin, Sonarr, Radarr, Bazarr, Prowlarr configurations
  - Volume mapping patterns for *arr services
  - Traefik label patterns for web UIs

- **Maintenance Tools:**
  - Homepage dashboard structure
  - Watchtower auto-update patterns
  - Autoheal container health monitoring

- **Documentation Approach:**
  - Clear, beginner-friendly setup guides
  - Environment variable documentation
  - Troubleshooting sections

#### License

```
MIT License

Copyright (c) 2023 Adrien Poupa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 2. navilg/media-stack

**Repository:** https://github.com/navilg/media-stack  
**Author:** Navil ([@navilg](https://github.com/navilg))  
**License:** GNU General Public License v3.0  

#### What We Borrowed

This project brought modern enhancements to our media stack:

- **AI-Powered Features:**
  - Recommendarr integration (AI-based media recommendations)
  - Jellyfin + Recommendarr connection patterns
  - Trakt.tv integration approach

- **VPN Profiles:**
  - Gluetun VPN container configuration
  - ProtonVPN setup patterns
  - VPN network isolation strategies

- **Modern Media Stack:**
  - Updated Jellyfin configuration
  - Jellyseerr request management patterns
  - Profile-based service organization

- **Configuration Management:**
  - Per-service config directory organization
  - API key management patterns

#### License

```
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2023 Navil

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

---

## Additional Acknowledgements

### Community Resources

- **[Trash-Guides](https://trash-guides.info/)** - Hardlink setup and media organization best practices
- **[TRaSH Discord](https://trash-guides.info/discord)** - Community support for *arr applications
- **[ServarrWiki](https://wiki.servarr.com/)** - Official wiki for Sonarr, Radarr, and related projects
- **[r/selfhosted](https://www.reddit.com/r/selfhosted/)** - Reddit community for self-hosting enthusiasts
- **[r/homelab](https://www.reddit.com/r/homelab/)** - Reddit community for home lab builders

### Docker Images

We use excellent open-source Docker images maintained by:

- **[LinuxServer.io](https://www.linuxserver.io/)** - Sonarr, Radarr, Bazarr, Prowlarr, qBittorrent images
- **[Jellyfin Team](https://jellyfin.org/)** - Jellyfin media server
- **[Traefik Labs](https://traefik.io/)** - Traefik reverse proxy
- **[Authelia](https://www.authelia.com/)** - Authelia SSO platform
- **[qdm12/gluetun](https://github.com/qdm12/gluetun)** - Gluetun VPN container
- **[Prometheus](https://prometheus.io/)** - Monitoring and alerting toolkit
- **[Grafana Labs](https://grafana.com/)** - Grafana dashboards
- **[Nextcloud](https://nextcloud.com/)** - Nextcloud cloud platform
- **[SearXNG](https://github.com/searxng/searxng)** - Privacy-respecting metasearch engine
- **[Home Assistant](https://www.home-assistant.io/)** - Home automation platform
- **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** - Uptime monitoring tool
- **[Homepage](https://gethomepage.dev/)** - Application dashboard

---

## Differences from Upstream

While heavily inspired by the upstream projects, `Orion-Sentinel-CoreSrv` differs in several key ways:

### Architectural Differences

1. **3-Node Architecture:**
   - Orion uses a dedicated Pi for DNS (Pi-hole + Unbound)
   - Upstream repos include DNS services (AdGuard Home)
   - We exclude DNS services to avoid conflicts

2. **Network Segmentation:**
   - Named networks with `orion_` prefix for clarity
   - Additional monitoring network for telemetry isolation
   - Explicit network architecture documentation

3. **Multi-Pi Integration:**
   - Designed to work alongside Pi DNS and Pi NetSec nodes
   - Monitoring stack scrapes metrics from multiple Pis
   - Architecture documentation includes all 3 nodes

### Service Differences

1. **Monitoring Stack:**
   - Full Prometheus + Grafana + Loki + Promtail stack
   - Uptime Kuma for cross-node monitoring
   - Dashboards for multi-node visibility

2. **Opinionated Defaults:**
   - ProtonVPN as default VPN provider
   - Europe/Amsterdam as default timezone
   - Explicit `/srv/orion-sentinel-core` directory structure

3. **Security Posture:**
   - All services behind Authelia by default
   - Explicit zero-trust security stance
   - 2FA recommended for all administrative access

### Documentation Differences

1. **Multi-Node Focus:**
   - `ARCHITECTURE.md` documents entire 3-node system
   - Setup guides reference Pi DNS for DNS resolution
   - Monitoring guides expect cross-node telemetry

2. **Upstream Sync Process:**
   - `UPSTREAM-SYNC.md` provides explicit sync workflow
   - Not a fork, so manual sync process documented
   - Sync log table for tracking changes over time

---

## Disclaimer

All mistakes, bugs, and questionable decisions in this repository are **ours alone**, not the fault of the upstream projects.

If you find issues with `Orion-Sentinel-CoreSrv`, please file them in this repository:
- **Issues:** https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv/issues

If you want to use the original upstream projects directly:
- **AdrienPoupa/docker-compose-nas:** https://github.com/AdrienPoupa/docker-compose-nas
- **navilg/media-stack:** https://github.com/navilg/media-stack

---

## License

This repository (`Orion-Sentinel-CoreSrv`) is released under the **MIT License** (same as AdrienPoupa/docker-compose-nas).

```
MIT License

Copyright (c) 2025 Yorgos Roussakis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Contributing

We welcome contributions! If you improve upon what we've built here:

1. Fork this repository
2. Make your changes
3. Submit a pull request

Please keep the spirit of openness and acknowledgement that made this project possible.

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team

**Special Thanks To:**
- Adrien Poupa for the excellent docker-compose-nas foundation
- Navil for the modern media-stack enhancements
- The entire self-hosting community for sharing knowledge freely
