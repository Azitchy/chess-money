# Chess Betting Platform (V1)

This repo now contains:

- A working **Laravel 12 backend API**
- A connected **Flutter mobile app**

- User registration/login/logout with bearer token auth
- Wallet balance + transaction ledger
- Manual wallet funding requests (player)
- Funding approval (admin)
- Match creation/join/end flows
- Competitive bet escrow lock + winner settlement + draw/cancel refunds

## Project Structure

- `backend/` Laravel API
- `flutter_app/` Flutter client

## Quick Start

Backend:

Prerequisite: PHP 8.2 or newer.

1. `cd backend`
2. `php artisan migrate:fresh --seed --force`
3. `php artisan storage:link`
4. `php artisan serve --host=0.0.0.0 --port=8000`

Flutter:

1. `cd flutter_app`
2. `flutter pub get`
3. `flutter run`

Backend server from this computer: `http://127.0.0.1:8000`

Backend server from a physical phone on the same Wi-Fi: use the computer's
IPv4 address, for example `http://192.168.0.195:8000/api`. Laravel must be
started with `--host=0.0.0.0`; the default localhost binding is not reachable
from another device. If the computer's DHCP address changes, run `ipconfig`
and save the new IPv4 address in the app's Backend URL field.

Admin web panel: `http://127.0.0.1:8000/admin/login`

Default seeded admin credentials:
- Email: `admin@chessbet.local`
- Password: `Admin@12345`

Flutter API base URL can be changed at runtime from the login screen. For an
Android emulator use `http://10.0.2.2:8000/api`; for a physical device use the
computer's LAN IPv4 address.

## API Endpoints

Auth:
- `POST /api/register`
- `POST /api/login`
- `GET /api/me`
- `POST /api/logout`

Profile:
- `GET /api/profile`
- `POST /api/profile` (multipart form data; optional `avatar` image up to 5 MB)

Presence:
- `GET /api/presence`
- `POST /api/presence` with `{ "is_online": true|false }`

Wallet:
- `GET /api/wallet`
- `GET /api/wallet/transactions`
- `POST /api/wallet/request-funds`

Matches:
- `POST /api/matches`
- `POST /api/matches/{match}/join`
- `POST /api/matches/{match}/end`
- `GET /api/matches/history`

Admin:
- `GET /api/admin/funding-requests`
- `POST /api/admin/funding-requests/{fundingRequest}/approve`

## Auth

Use `Authorization: Bearer <token>` for protected routes.

## Notes

- The backend currently targets Laravel 12, which requires PHP 8.2+.
- Wallet updates and match settlements run inside DB transactions.
- Competitive matches lock both players' stake when opponent joins.
- Draw/cancel returns both stakes.
- Winner receives the total pool (`2 x bet_amount`).
- Admin panel supports user suspend/activate, wallet add/deduct, funding request approve/reject, matches view, and transaction monitoring.

## Next Build Steps

- Real-time gameplay via WebSockets
- Chess move validation and anti-cheat checks
- Flutter client screens and API integration
- Admin dashboard UI
- Production hardening (rate limiting, audit trails, monitoring)
