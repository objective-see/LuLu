# Security Policy

## Supported Versions

Security updates are provided for the latest released version of LuLu.

| Version        | Supported |
| -------------- | --------- |
| Latest release | Yes       |
| Older releases | No        |

Users are encouraged to update to the latest release before reporting issues that may already have been fixed.

## Reporting a Vulnerability

Please do **not** report security vulnerabilities through public GitHub issues, discussions, or pull requests.

If you believe you have found a security vulnerability in LuLu, please report it privately using GitHub’s **Private Vulnerability Reporting** feature for this repository, if available.

When reporting, please include as much detail as possible:

* LuLu version
* macOS version
* Steps to reproduce
* Expected and actual behavior
* Crash logs, screenshots, or proof-of-concept details, if applicable
* Whether the issue requires local access, user interaction, administrator privileges, or a specific system configuration

## Scope

Security issues may include, but are not limited to:

* Bypass of LuLu’s outbound network filtering
* Incorrect allow/block rule enforcement
* Privilege escalation
* Unauthorized modification of LuLu rules, settings, profiles, or components
* Unsafe handling of helper tools, system extensions, or privileged operations
* Code execution, persistence, or tampering issues affecting LuLu
* Sensitive information disclosure

General bugs, feature requests, usability issues, and support questions should be reported through normal GitHub issues instead.

## Coordinated Disclosure

Please allow the maintainers reasonable time to investigate and address the issue before public disclosure.

We ask researchers to:

* Act in good faith
* Avoid accessing, modifying, or destroying data that does not belong to you
* Avoid disrupting other users or services
* Share enough information to reproduce and verify the issue
* Keep vulnerability details private until a fix or mitigation is available

## Response Expectations

The project will make a best effort to:

* Acknowledge valid vulnerability reports
* Investigate the reported issue
* Request additional information if needed
* Release a fix or mitigation when appropriate
* Credit the reporter, if desired

This project does not currently offer a paid bug bounty program.

## Security Updates

Security fixes will be released through the project’s normal GitHub release process. Users should install the latest available LuLu release from the official Objective-See website or GitHub releases page.
