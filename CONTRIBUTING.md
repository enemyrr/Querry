# Contributing to Pluk

Thanks for helping improve Pluk.

## Development setup

1. Use macOS 15 or later and Xcode 26 or later.
2. Fork and clone this repository.
3. Open `Pluk.xcodeproj` and select the shared `Collection` scheme.
4. Let Xcode resolve the Swift package dependencies.
5. Run the app or the relevant tests.

Hosted Pluk services are intentionally unconfigured in community builds. The database client remains usable without PostHog, Sentry, WorkOS sign-in, or funded Bedrock AI access. Do not commit `pluk/Secrets.xcconfig`, credentials, signing certificates, provisioning profiles, or personal Xcode data.

## Pull requests

- Keep changes focused and explain the user-visible behavior.
- Add or update tests when the change is testable.
- Run the relevant unit tests and confirm the app launches before submitting.
- Do not include unrelated formatting or generated build output.
- Confirm that new dependencies and bundled assets can be redistributed under the project's license.

By contributing, you agree that your contribution is licensed under the repository's [AGPL-3.0 license](./LICENSE).

## Trademarks

The source license does not grant rights to Pluk branding. Forks and modified distributions must follow [TRADEMARKS.md](./TRADEMARKS.md).
