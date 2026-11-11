## 0.0.8 - 2026-11-10

- Update Firefly III from 6.4.6 to 6.7.9 and run its full database upgrade sequence before serving requests.
- Fix Home/Dashboard links and root redirects through Home Assistant Ingress (#9).
- Use persistent Laravel storage for uploads, sessions and OAuth keys, including web requests and CLI commands.
- Preserve existing OAuth keys and stop startup when database migrations fail.
- Update actions/checkout to v6 and markdownlint-cli2-action to v22.
- Advertise only amd64 and aarch64, matching the upstream container image.
- Add regression coverage for Ingress, redirects and persistent storage.

## 0.0.7 - 2026-11-10

- fix: allow default mail sender and clean up Linux test data

## 0.0.6 - 2026-11-10

- fix: honor database, SMTP and application key options

## 0.0.5 - 2025-11-14

- feat: expose Firefly III on `http://<home-assistant-host>:8080` for direct API access

## 0.0.4 - 2025-11-14

- Dev (#15)

## 0.0.3 - 2025-09-18

- chore(deps): ensure target-branch is set for docker and github-actions updates

## 0.0.2 - 2025-09-18

- chore(deps): Bump ludeeus/action-shellcheck from 1.1.0 to 2.0.0 (#8)
- chore(deps): Bump DavidAnson/markdownlint-cli2-action from 15 to 20 (#7)
- chore(deps): Bump actions/checkout from 4 to 5 (#6)
- chore: update changelog for 0.0.1
- feat: Add Firefly III Home Assistant add-on
- Add initial files for Firefly III Home Assistant add-on

## 0.0.1 - 2025-09-18

- feat: Add Firefly III Home Assistant add-on
- Add initial files for Firefly III Home Assistant add-on
