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
3. `php artisan serve`

Flutter:

1. `cd flutter_app`
2. `flutter pub get`
3. `flutter run`

Backend server: `http://127.0.0.1:8000`

Admin web panel: `http://127.0.0.1:8000/admin/login`

Default seeded admin credentials:
- Email: `admin@chessbet.local`
- Password: `Admin@12345`

Flutter API base URL is currently:

- `http://10.0.2.2:8000/api` (Android emulator)

If running on physical device or iOS simulator, update:

- `flutter_app/lib/src/services/api_client.dart`

## API Endpoints

Auth:
- `POST /api/register`
- `POST /api/login`
- `GET /api/me`
- `POST /api/logout`

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
