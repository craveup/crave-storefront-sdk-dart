# Security policy

## Supported versions

Security fixes are provided for the latest published `0.1.x` preview.

| Version | Supported |
| --- | --- |
| Latest `0.1.x` | Yes |
| Older previews | No |

## Report a vulnerability privately

Do not open a public issue for a suspected vulnerability. Use the repository's
[private vulnerability report](https://github.com/craveup/crave-storefront-sdk-dart/security/advisories/new)
and include:

- the affected package version and platform;
- a minimal reproduction or clear sequence of events;
- the security impact you observed;
- any suggested mitigation, if known.

Remove customer data, tokens, capabilities, one-time codes, payment values, and production tenant
identifiers from the report. We will acknowledge the report, validate the impact, coordinate a fix,
and publish an advisory when affected users can upgrade. Please allow a reasonable remediation
window before public disclosure.

## Consumer responsibilities

Applications must use HTTPS in deployed environments, supply customer identity through the callback,
store cart sessions in encrypted platform storage, avoid sensitive request/response logging, and
keep checkout and receipt capabilities call-scoped. The SDK intentionally does not choose an
authentication provider or storage plugin for the application.

Treat an injected `http.Client` as trusted, privileged application code. It can observe resolved
URLs, authorization and capability headers, and request/response bodies, and the SDK cannot control
logging, proxying, or other behavior implemented inside it. Inject only a client your application
audits and owns.
