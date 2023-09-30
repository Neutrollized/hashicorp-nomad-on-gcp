# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2023-09-30
### Added
- Custom service account for Compute Engine
- L7 application load balancer in front of the Consul and Nomad servers 
- Cloud Router (NAT)
- [Custom input validation rules](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
### Changed
- Consul and Nomad servers no longer provisioned with external IPs
- `can_ip_forward` set to `true`
- `firewall.tf` renamed to `network.tf`

## [0.1.0] - 2023-09-28
### Added
- Initial commit
