# Security Policy

## Supported versions

Only the latest `v1.7.0-amphetamine.N` release receives security fixes. Installs update through Sparkle (**Check for Updates…**), so staying current is the fix.

## Reporting a vulnerability

Please **don't** open a public issue for a security problem.

Report it privately through GitHub instead: [**Report a vulnerability**](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine/security/advisories/new) (Security tab → *Report a vulnerability*). Include:

- the affected component and version: the app version from Settings → About, or for the `kya` CLI / `kya-mcp-server`, the installed package version (`pip show` / `uv tool list`) or the source revision
- what an attacker can do, and the steps or a proof of concept to reproduce it
- any suggested fix, if you have one

You should get an acknowledgement within a week. Once a fix is released, the advisory is published and credits you unless you'd rather stay anonymous.

## Scope

This fork ([`ryouka0731/KeepingYouAwake-Amphetamine`](https://github.com/ryouka0731/KeepingYouAwake-Amphetamine)) covers the app, its Sparkle update feed, the `kya` CLI and `kya-mcp-server`. A problem that also affects upstream [`newmarcel/KeepingYouAwake`](https://github.com/newmarcel/KeepingYouAwake) should be reported there as well.
