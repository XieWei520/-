# Spec: Admin Route Isolation

## Objective
Keep the public Web client on the root domain while serving TangSengDaoDao admin only under `/admin/`.

Acceptance criteria:
- `https://infoequity.cn/#/home` continues to load the public Web client.
- `https://infoequity.cn/admin/` loads the admin login page.
- Admin login redirects to `/admin/home`, not `/home`.
- Root paths `/login` and `/home` no longer proxy to the admin frontend.

## Tech Stack
- Production nginx reverse proxy in `deploy/production/nginx/default.conf.template`.
- Admin frontend is the existing bundled Vue app served by `admin-nginx`.
- Public Web client is the existing Flutter Web app served from the root nginx document root.

## Commands
- Route check: `Invoke-WebRequest -Uri https://infoequity.cn/admin/ -UseBasicParsing`
- nginx validation: `docker compose exec -T nginx nginx -t`
- Deploy reload: `docker compose restart nginx`
- Browser check: `npx --yes agent-browser --session-name tsdd-admin-isolation open https://infoequity.cn/admin/`

## Project Structure
- `deploy/production/nginx/default.conf.template` -> production reverse proxy template.
- `.remote_launch_policy/` -> temporary diagnostic and deployment helper scripts.
- `docs/superpowers/specs/` -> implementation specs.

## Code Style
Keep nginx routing explicit and path-scoped:

```nginx
location = /admin {
    return 308 /admin/;
}

location ^~ /admin/ {
    proxy_pass http://admin_nginx;
}
```

## Testing Strategy
Use production route checks plus real browser login verification because this is proxy behavior, not pure application logic.

## Boundaries
- Always: back up the remote nginx template before replacing it.
- Ask first: changing the public root Web deployment or rebuilding the admin frontend.
- Never: route root `/login` or `/home` to admin after this change.

## Success Criteria
- nginx config test passes.
- `/admin/` can log in and lands on `/admin/home`.
- `/#/home`, `/login`, and `/home` return the public Web shell rather than admin HTML.

## Open Questions
None. User approved isolating admin to `/admin/`.
